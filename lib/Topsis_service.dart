// topsis_service.dart
// ignore_for_file: file_names

import 'dart:math';

class TopsisResult {
  final String proposalId;
  final String contractorId;
  final String contractorName;
  final double ciScore;
  final double ciPercent;
  final bool isQualified;
  final Map<String, double> criteriaScores;

  const TopsisResult({
    required this.proposalId,
    required this.contractorId,
    required this.contractorName,
    required this.ciScore,
    required this.ciPercent,
    required this.isQualified,
    required this.criteriaScores,
  });
}

class TopsisService {
  static const double qualificationThreshold = 0.60;

  static double calculateRFPThreshold(Map<String, double> weights) {
    if (weights.isEmpty) return qualificationThreshold;
    final n = weights.length;
    final maxWeight = weights.values.reduce((a, b) => a > b ? a : b);
    final equalWeight = 1.0 / n;
    final threshold = 0.5 + (maxWeight - equalWeight) * 0.5;
    return threshold.clamp(0.40, 0.85);
  }

  static Map<String, double> parseWeights(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    final weights = <String, double>{};
    for (final part in raw.split(',')) {
      final segs = part.trim().split(':');
      if (segs.length < 2) continue;
      final name = segs[0].trim().toLowerCase();
      final weight = double.tryParse(segs[1].trim().replaceAll('%', '')) ?? 0;
      if (weight > 0) weights[name] = weight / 100;
    }
    return weights;
  }

  static Map<String, double> parseComments(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    final scores = <String, double>{};
    for (final part in raw.split('|')) {
      final kv = part.trim().split(':');
      if (kv.length == 2) {
        scores[kv[0].trim().toLowerCase()] = double.tryParse(kv[1].trim()) ?? 0;
      }
    }
    return scores;
  }

  static List<List<double>> _normalize(List<List<double>> matrix) {
    final n = matrix.length;
    final m = matrix[0].length;
    final result = List.generate(n, (_) => List.filled(m, 0.0));
    for (int j = 0; j < m; j++) {
      final sumSq = matrix.fold(0.0, (s, row) => s + row[j] * row[j]);
      final norm = sqrt(sumSq);
      for (int i = 0; i < n; i++) {
        result[i][j] = norm > 0 ? matrix[i][j] / norm : 0;
      }
    }
    return result;
  }

  static List<List<double>> _weightNormalize(
    List<List<double>> matrix,
    List<double> weights,
  ) {
    final normalized = _normalize(matrix);
    return normalized
        .map(
          (row) =>
              row.asMap().entries.map((e) => e.value * weights[e.key]).toList(),
        )
        .toList();
  }

  static (List<double>, List<double>) _idealSolutions(
    List<List<double>> weighted,
    List<String> criteriaTypes,
  ) {
    final m = weighted[0].length;
    final best = List.filled(m, 0.0);
    final worst = List.filled(m, 0.0);
    for (int j = 0; j < m; j++) {
      final col = weighted.map((row) => row[j]).toList();
      if (criteriaTypes[j] == 'cost') {
        best[j] = col.reduce(min);
        worst[j] = col.reduce(max);
      } else {
        best[j] = col.reduce(max);
        worst[j] = col.reduce(min);
      }
    }
    return (best, worst);
  }

  static double _euclidean(List<double> row, List<double> ideal) {
    return sqrt(
      List.generate(
        row.length,
        (j) => pow(row[j] - ideal[j], 2),
      ).reduce((a, b) => a + b),
    );
  }

  static List<TopsisResult> analyze({
    required List<Map<String, dynamic>> proposals,
    required Map<String, double> weights,
    Map<String, String>? criteriaTypes,
  }) {
    if (proposals.isEmpty || weights.isEmpty) return [];

    final rfpThreshold = calculateRFPThreshold(weights);
    final criteriaOrder = weights.keys.toList();
    final weightList = criteriaOrder.map((c) => weights[c] ?? 0.0).toList();

    final types = criteriaOrder.map((c) {
      if (criteriaTypes != null && criteriaTypes.containsKey(c)) {
        return criteriaTypes[c]!;
      }
      return 'benefit';
    }).toList();

    final withScores = proposals.where((p) {
      final scores = parseComments(p['comments']?.toString());
      return scores.isNotEmpty;
    }).toList();

    if (withScores.isEmpty) return [];

    // ── مقاول واحد فقط ──
    // لا نشغّل TOPSIS، لكن نتحقق من الدرجات
    // لو مجموع الدرجات = 0 → غير مؤهل
    if (withScores.length == 1) {
      final p = withScores.first;
      final scores = parseComments(p['comments']?.toString());
      final totalScore = scores.values.fold(0.0, (a, b) => a + b);
      final qualified = totalScore > 0;
      final ci = qualified ? 1.0 : 0.0;
      return [
        TopsisResult(
          proposalId: p['ProposalID']?.toString() ?? '',
          contractorId: p['submitterUserId']?.toString() ?? '',
          contractorName: p['contractorname']?.toString() ?? 'Unknown',
          ciScore: ci,
          ciPercent: ci * 100,
          isQualified: qualified,
          criteriaScores: scores,
        ),
      ];
    }

    final matrix = withScores.map((p) {
      final scores = parseComments(p['comments']?.toString());
      return criteriaOrder.map((c) => scores[c] ?? 0.0).toList();
    }).toList();

    final weighted = _weightNormalize(matrix, weightList);
    final (best, worst) = _idealSolutions(weighted, types);

    final results = <TopsisResult>[];
    for (int i = 0; i < withScores.length; i++) {
      final dBest = _euclidean(weighted[i], best);
      final dWorst = _euclidean(weighted[i], worst);
      final denom = dBest + dWorst;
      final ci = denom > 0 ? dWorst / denom : 0.0;

      results.add(
        TopsisResult(
          proposalId: withScores[i]['ProposalID']?.toString() ?? '',
          contractorId: withScores[i]['submitterUserId']?.toString() ?? '',
          contractorName:
              withScores[i]['contractorname']?.toString() ?? 'Unknown',
          ciScore: ci,
          ciPercent: ci * 100,
          isQualified: ci >= rfpThreshold,
          criteriaScores: parseComments(withScores[i]['comments']?.toString()),
        ),
      );
    }

    results.sort((a, b) => b.ciScore.compareTo(a.ciScore));
    return results;
  }

  static String generateInsight(
    TopsisResult result,
    Map<String, double> weights,
  ) {
    if (!result.isQualified) {
      final t = weights.isNotEmpty
          ? calculateRFPThreshold(weights)
          : qualificationThreshold;
      return 'This contractor did not meet the RFP threshold of '
          '${(t * 100).toStringAsFixed(0)}%.';
    }

    final topCriterion = result.criteriaScores.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    final topWeight = weights.entries.isNotEmpty
        ? weights.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    if (topWeight != null && result.criteriaScores.containsKey(topWeight.key)) {
      final weightedScore = result.criteriaScores[topWeight.key]!;
      return 'Strong in ${_capitalize(topWeight.key)} '
          '(${weightedScore.toInt()}/100) '
          '— your highest-priority criterion. '
          'Overall balance score: ${result.ciPercent.toStringAsFixed(1)}%.';
    }

    return 'Excels in ${_capitalize(topCriterion.key)} '
        '(${topCriterion.value.toInt()}/100). '
        'TOPSIS score: ${result.ciPercent.toStringAsFixed(1)}%.';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
