// topsis_service.dart
// ══════════════════════════════════════════════
//  BidPlus+ — TOPSIS Service
//  يستقبل بيانات المقاولين + أوزان AHP
//  ويُرجع قائمة مرتبة مع Ci scores
// ══════════════════════════════════════════════
import 'dart:math';

/// نتيجة TOPSIS لمقاول واحد
class TopsisResult {
  final String proposalId;
  final String contractorId; // submitterUserId (uuid)
  final String contractorName;
  final double ciScore; // Closeness Index (0→1)
  final double ciPercent; // ciScore × 100
  final bool isQualified; // Ci >= rfpThreshold
  final Map<String, double> criteriaScores; // { 'cost': 80, 'experience': 60 }

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
  // ─────────────────────────────────────────────
  //  Fallback فقط — لا يُستخدم لو في أوزان
  // ─────────────────────────────────────────────
  static const double qualificationThreshold = 0.60;

  // ─────────────────────────────────────────────
  //  حساب Threshold من أوزان AHP ← الجديد
  //
  //  المنطق: كلما المانجر ركّز الوزن على معيار واحد
  //  → هو متطلب أكثر → threshold أعلى
  //
  //  threshold = 0.5 + (maxWeight - 1/n) × 0.5
  //
  //  أمثلة:
  //  Cost:80%, Experience:20% → 0.5+(0.8-0.5)×0.5 = 0.65 = 65%
  //  Cost:60%, Experience:40% → 0.5+(0.6-0.5)×0.5 = 0.55 = 55%
  //  Cost:50%, Experience:50% → 0.5+(0.5-0.5)×0.5 = 0.50 = 50%
  //  Cost:33%, Exp:33%, Tech:33% → 0.5+(0.33-0.33)×0.5 = 0.50 = 50%
  // ─────────────────────────────────────────────
  static double calculateRFPThreshold(Map<String, double> weights) {
    if (weights.isEmpty) return qualificationThreshold;
    final n = weights.length;
    final maxWeight = weights.values.reduce((a, b) => a > b ? a : b);
    final equalWeight = 1.0 / n;
    final threshold = 0.5 + (maxWeight - equalWeight) * 0.5;
    // clamp بين 0.40 و 0.85
    return threshold.clamp(0.40, 0.85);
  }

  // ─────────────────────────────────────────────
  //  Parse Helpers
  // ─────────────────────────────────────────────

  /// Parse "Cost:40%, Experience:60%" → { 'cost': 0.4, 'experience': 0.6 }
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

  /// Parse "Cost: 80 | Experience: 60" → { 'cost': 80.0, 'experience': 60.0 }
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

  // ─────────────────────────────────────────────
  //  Core TOPSIS Steps
  // ─────────────────────────────────────────────

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

  // ─────────────────────────────────────────────
  //  Main Entry Point
  // ─────────────────────────────────────────────
  static List<TopsisResult> analyze({
    required List<Map<String, dynamic>> proposals,
    required Map<String, double> weights,
    Map<String, String>? criteriaTypes,
  }) {
    if (proposals.isEmpty || weights.isEmpty) return [];

    // ← الجديد: احسب threshold من أوزان الـ RFP
    final rfpThreshold = calculateRFPThreshold(weights);

    final criteriaOrder = weights.keys.toList();
    final weightList = criteriaOrder.map((c) => weights[c] ?? 0.0).toList();

    final types = criteriaOrder.map((c) {
      if (criteriaTypes != null && criteriaTypes.containsKey(c)) {
        return criteriaTypes[c]!;
      }
      return 'benefit'; // AI scores: أعلى دائماً = أفضل
    }).toList();

    final withScores = proposals.where((p) {
      final scores = parseComments(p['comments']?.toString());
      return scores.isNotEmpty;
    }).toList();

    if (withScores.isEmpty) return [];

    // ← الجديد: لو مقاول واحد فقط → يرجع مباشرة بدون TOPSIS
    if (withScores.length == 1) {
      final p = withScores.first;
      final scores = parseComments(p['comments']?.toString());
      return [
        TopsisResult(
          proposalId: p['ProposalID']?.toString() ?? '',
          contractorId: p['submitterUserId']?.toString() ?? '',
          contractorName: p['contractorname']?.toString() ?? 'Unknown',
          ciScore: 1.0,
          ciPercent: 100.0,
          isQualified: true,
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
          // ← الجديد: يستخدم rfpThreshold بدل القيمة الثابتة
          isQualified: ci >= rfpThreshold,
          criteriaScores: parseComments(withScores[i]['comments']?.toString()),
        ),
      );
    }

    results.sort((a, b) => b.ciScore.compareTo(a.ciScore));
    return results;
  }

  /// AI Insight
  static String generateInsight(
    TopsisResult result,
    Map<String, double> weights,
  ) {
    if (!result.isQualified) {
      // ← الجديد: يعرض الـ threshold الحقيقي للـ RFP
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
