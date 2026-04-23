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
  final bool isQualified; // Ci >= threshold (0.60 افتراضي)
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
  //  الحد الأدنى للتأهيل (يمكن تغييره)
  // ─────────────────────────────────────────────
  static const double qualificationThreshold = 0.60; // 60%

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

  /// الخطوة 1: Normalize column-wise
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

  /// الخطوة 2: Weighted Normalized
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

  /// الخطوة 3+4: Ideal Best (PIS) و Ideal Worst (NIS)
  /// criteriaTypes: 'benefit' = أعلى أفضل | 'cost' = أقل أفضل
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
        // Cost: أقل = أفضل
        best[j] = col.reduce(min);
        worst[j] = col.reduce(max);
      } else {
        // Benefit: أعلى = أفضل
        best[j] = col.reduce(max);
        worst[j] = col.reduce(min);
      }
    }
    return (best, worst);
  }

  /// الخطوة 5: Euclidean Distance
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

  /// تطبيق TOPSIS على قائمة proposals
  ///
  /// [proposals]     : بيانات المقاولين من Supabase
  /// [weights]       : { 'cost': 0.4, 'experience': 0.6 } من AHP
  /// [criteriaTypes] : { 'cost': 'cost', 'experience': 'benefit' }
  ///                   cost     = أقل قيمة أفضل (السعر)
  ///                   benefit  = أعلى قيمة أفضل (الخبرة، الجودة)
  static List<TopsisResult> analyze({
    required List<Map<String, dynamic>> proposals,
    required Map<String, double> weights,
    Map<String, String>? criteriaTypes, // اختياري، افتراضي = benefit
  }) {
    if (proposals.isEmpty || weights.isEmpty) return [];

    final criteriaOrder = weights.keys.toList();
    final weightList = criteriaOrder.map((c) => weights[c] ?? 0.0).toList();

    // تحديد نوع كل معيار
    final types = criteriaOrder.map((c) {
      if (criteriaTypes != null && criteriaTypes.containsKey(c)) {
        return criteriaTypes[c]!;
      }
      // تخمين تلقائي: cost = سعر، benefit = باقي المعايير
      return c == 'cost' ? 'cost' : 'benefit';
    }).toList();

    // فلتر proposals عندها AI scores
    final withScores = proposals.where((p) {
      final scores = parseComments(p['comments']?.toString());
      return scores.isNotEmpty;
    }).toList();

    if (withScores.isEmpty) return [];

    // بناء Decision Matrix
    final matrix = withScores.map((p) {
      final scores = parseComments(p['comments']?.toString());
      return criteriaOrder.map((c) => scores[c] ?? 0.0).toList();
    }).toList();

    // تطبيق TOPSIS
    final weighted = _weightNormalize(matrix, weightList);
    final (best, worst) = _idealSolutions(weighted, types);

    // Closeness Index
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
          isQualified: ci >= qualificationThreshold,
          criteriaScores: parseComments(withScores[i]['comments']?.toString()),
        ),
      );
    }

    // ترتيب تنازلي
    results.sort((a, b) => b.ciScore.compareTo(a.ciScore));
    return results;
  }

  /// AI Insight — تفسير بسيط للنتيجة
  static String generateInsight(
    TopsisResult result,
    Map<String, double> weights,
  ) {
    if (!result.isQualified) {
      return 'This contractor did not meet the minimum threshold of ${(qualificationThreshold * 100).toInt()}%.';
    }

    // أعلى معيار حصل عليه
    final topCriterion = result.criteriaScores.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    // أهم معيار حسب الأوزان
    final topWeight = weights.entries.isNotEmpty
        ? weights.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    if (topWeight != null && result.criteriaScores.containsKey(topWeight.key)) {
      final weightedScore = result.criteriaScores[topWeight.key]!;
      return 'Strong in ${_capitalize(topWeight.key)} (${weightedScore.toInt()}/100) '
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
