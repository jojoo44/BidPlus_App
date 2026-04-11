// ─────────────────────────────────────────────
//  AHP Calculator — خوارزمية التحليل الهرمي
//  Input : مصفوفة المقارنات n×n
//  Output: الأوزان + Consistency Ratio
// ─────────────────────────────────────────────

class AHPResult {
  final List<double> weights; // الأوزان النهائية (تجمع 1.0)
  final double consistencyRatio; // CR — يجب أن يكون < 0.10
  final bool isConsistent; // true لو CR < 0.10

  const AHPResult({
    required this.weights,
    required this.consistencyRatio,
    required this.isConsistent,
  });
}

class AHPCalculator {
  // Saaty Random Index — ثابت لكل حجم مصفوفة
  static const List<double> _ri = [
    0,
    0,
    0.58,
    0.90,
    1.12,
    1.24,
    1.32,
    1.41,
    1.45,
  ];

  /// يحسب الأوزان وConsistency Ratio من مصفوفة المقارنات
  /// [matrix] : مصفوفة n×n حيث matrix[i][j] = أهمية i مقارنة بـ j
  /// القيم المقبولة: 1/9, 1/8, ..., 1/2, 1, 2, ..., 9
  static AHPResult calculate(List<List<double>> matrix) {
    final n = matrix.length;
    assert(n >= 2 && n <= 8, 'AHP يدعم 2-8 معايير فقط');

    // ── الخطوة 1: حساب مجموع كل عمود ──
    final colSums = List<double>.filled(n, 0);
    for (int j = 0; j < n; j++) {
      for (int i = 0; i < n; i++) {
        colSums[j] += matrix[i][j];
      }
    }

    // ── الخطوة 2: تطبيع المصفوفة (normalize) ──
    final normalized = List.generate(
      n,
      (i) => List.generate(n, (j) => matrix[i][j] / colSums[j]),
    );

    // ── الخطوة 3: حساب متوسط كل صف = الوزن ──
    final weights = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        weights[i] += normalized[i][j];
      }
      weights[i] /= n;
    }

    // ── الخطوة 4: حساب λmax ──
    // الصح: Aw = matrix × weights، ثم λmax = mean(Aw[i] / weights[i])
    double lambdaMax = 0;
    for (int i = 0; i < n; i++) {
      double rowSum = 0;
      for (int j = 0; j < n; j++) {
        rowSum += matrix[i][j] * weights[j];
      }
      lambdaMax += rowSum / weights[i];
    }
    lambdaMax /= n;

    // ── الخطوة 5: Consistency Index ──
    final ci = (lambdaMax - n) / (n - 1);

    // ── الخطوة 6: Consistency Ratio ──
    final ri = _ri[n];
    final cr = ri == 0 ? 0.0 : ci / ri;

    return AHPResult(
      weights: weights,
      consistencyRatio: cr,
      isConsistent: cr < 0.10,
    );
  }

  /// يبني مصفوفة متماثلة تلقائياً من القيم الفوق-قطرية فقط
  /// [n] : عدد المعايير
  /// [upperValues] : قيم المثلث العلوي بالترتيب (row by row)
  static List<List<double>> buildMatrix(int n, List<double> upperValues) {
    final matrix = List.generate(n, (_) => List<double>.filled(n, 1.0));
    int idx = 0;
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final val = upperValues[idx++];
        matrix[i][j] = val;
        matrix[j][i] = 1.0 / val;
      }
    }
    return matrix;
  }

  /// عدد المقارنات المطلوبة لـ n معايير = n*(n-1)/2
  static int comparisonsCount(int n) => n * (n - 1) ~/ 2;

  /// تحويل الأوزان إلى نسب مئوية مقربة (تجمع 100)
  static List<int> weightsToPercent(List<double> weights) {
    final percents = weights.map((w) => (w * 100).round()).toList();
    // تصحيح التقريب عشان المجموع يكون 100
    final diff = 100 - percents.reduce((a, b) => a + b);
    if (diff != 0) {
      // أضف الفرق للأكبر قيمة
      final maxIdx = percents.indexOf(percents.reduce((a, b) => a > b ? a : b));
      percents[maxIdx] += diff;
    }
    return percents;
  }
}
