// ahp_dialog.dart
import 'package:flutter/material.dart';
import 'ahp_calculator.dart';
import 'ahp_guide_sheet.dart';

/// نافذة AHP — تظهر للمدير عشان يقارن المعايير ببعض
/// الناتج: Map<String, double> اسم المعيار → وزنه (0.0 - 1.0)
class AHPDialog extends StatefulWidget {
  final List<String> criteria; // أسماء المعايير

  const AHPDialog({super.key, required this.criteria});

  @override
  State<AHPDialog> createState() => _AHPDialogState();
}

class _AHPDialogState extends State<AHPDialog> {
  // Saaty scale labels
  static const List<String> _scaleLabels = [
    '1/9',
    '1/7',
    '1/5',
    '1/3',
    '1',
    '3',
    '5',
    '7',
    '9',
  ];
  static const List<double> _scaleValues = [
    1 / 9,
    1 / 7,
    1 / 5,
    1 / 3,
    1,
    3,
    5,
    7,
    9,
  ];

  final Color bgColor = const Color(0xFF0D1219);
  final Color cardColor = const Color(0xFF1C242F);
  final Color primaryBlue = const Color(0xFF3395FF);
  final Color greenColor = const Color(0xFF34D399);
  final Color redColor = const Color(0xFFFF6B6B);

  late int n;
  late int pairCount;
  late List<int> _sliderIndices; // index في _scaleValues لكل مقارنة
  AHPResult? _result;

  @override
  void initState() {
    super.initState();
    n = widget.criteria.length;
    pairCount = AHPCalculator.comparisonsCount(n);
    // ابدأ كل مقارنة بـ 1 (Equal)
    _sliderIndices = List.filled(pairCount, 4); // index 4 = القيمة 1
    _recalculate();
  }

  void _recalculate() {
    // السلايدر: index 0 (أقصى يسار) = المعيار الأيسر More important by 9×
    //           index 4 (وسط)        = Equal (1)
    //           index 8 (أقصى يمين) = المعيار الأيمن More important by 9×
    // matrix[i][j] = كم i أهم من j
    // لو السلايدر يسار → i أهم → قيمة > 1
    // لو السلايدر يمين → j أهم → قيمة < 1
    final upperValues = _sliderIndices.map((idx) {
      if (idx == 4) return 1.0; // Equal
      final raw = _scaleValues[idx];
      // _scaleValues = [1/9, 1/7, 1/5, 1/3, 1, 3, 5, 7, 9]
      // يسار (0-3): raw صغير (1/9..1/3) → نعكس → قيمة كبيرة = i أهم ✓
      // يمين (5-8): raw كبير (3..9)     → نعكس → قيمة صغيرة = j أهم ✓
      return 1.0 / raw;
    }).toList();
    final matrix = AHPCalculator.buildMatrix(n, upperValues);
    setState(() => _result = AHPCalculator.calculate(matrix));
  }

  /// يحلل التناقضات ويرجع رسائل توضيحية
  List<String> _getInconsistencyHints() {
    if (_result == null || _result!.isConsistent) return [];
    final hints = <String>[];
    final pairsList = _pairs;

    final upperValues = _sliderIndices.map((idx) {
      if (idx == 4) return 1.0;
      return 1.0 / _scaleValues[idx];
    }).toList();

    for (int a = 0; a < n; a++) {
      for (int b = a + 1; b < n; b++) {
        for (int c = b + 1; c < n; c++) {
          final abIdx = pairsList.indexWhere((p) => p.$1 == a && p.$2 == b);
          final acIdx = pairsList.indexWhere((p) => p.$1 == a && p.$2 == c);
          final bcIdx = pairsList.indexWhere((p) => p.$1 == b && p.$2 == c);
          if (abIdx == -1 || acIdx == -1 || bcIdx == -1) continue;

          final ab = upperValues[abIdx];
          final ac = upperValues[acIdx];
          final bc = upperValues[bcIdx];
          final expected = ab * bc;
          final ratio = expected / ac;

          if (ratio < 0.5 || ratio > 2.0) {
            final nameA = widget.criteria[a];
            final nameB = widget.criteria[b];
            final nameC = widget.criteria[c];

            final abWinner = ab >= 1 ? nameA : nameB;
            final abLoser = ab >= 1 ? nameB : nameA;
            final abVal = (ab >= 1 ? ab : 1 / ab).clamp(1.0, 9.0);
            final bcWinner = bc >= 1 ? nameB : nameC;
            final bcLoser = bc >= 1 ? nameC : nameB;
            final bcVal = (bc >= 1 ? bc : 1 / bc).clamp(1.0, 9.0);
            final expWinner = expected >= 1 ? nameA : nameC;
            final expLoser = expected >= 1 ? nameC : nameA;
            final expVal = (expected >= 1 ? expected : 1 / expected).clamp(
              1.0,
              9.0,
            );

            // لو expected قريب من 1 → Equalان
            final expMsg = (expVal < 1.5)
                ? '  → therefore $nameA and $nameC should be approximately equal\n'
                      '  ← move the "$nameA vs $nameC" slider to the center'
                : '  → therefore $expWinner should be more important than $expLoser by \${expVal.toStringAsFixed(0)}×\n'
                      '  ← adjust the "$nameA vs $nameC" comparison';

            hints.add(
              '• You said $abWinner is more important than $abLoser by \${abVal.toStringAsFixed(0)}×\n'
                      '  and $bcWinner is more important than $bcLoser by \${bcVal.toStringAsFixed(0)}×\n' +
                  expMsg,
            );
          }
        }
      }
    }
    return hints;
  }

  /// يرجع اسم الزوج (i, j) بالترتيب
  List<(int, int)> get _pairs {
    final pairs = <(int, int)>[];
    for (int i = 0; i < n; i++)
      for (int j = i + 1; j < n; j++) pairs.add((i, j));
    return pairs;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.balance, color: primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AHP — Set criteria weights',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Move the slider toward the more important criterion',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.help_outline,
                      color: primaryBlue,
                      size: 20,
                    ),
                    tooltip: 'How does AHP work?',
                    onPressed: () => AHPGuideSheet.show(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── المقارنات ──
              ..._pairs.asMap().entries.map((entry) {
                final idx = entry.key;
                final (i, j) = entry.value;
                final sliderVal = _sliderIndices[idx].toDouble();
                final sliderIdx = _sliderIndices[idx];
                final leftWins = sliderIdx < 4;
                final rightWins = sliderIdx > 4;
                final equal = sliderIdx == 4;
                final displayLabel = equal
                    ? 'Equal'
                    : _scaleLabels[leftWins ? (8 - sliderIdx) : sliderIdx];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      // أسماء المعيارين
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.criteria[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: leftWins ? primaryBlue : Colors.white70,
                                fontWeight: leftWins
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: equal
                                  ? Colors.white12
                                  : (leftWins
                                        ? primaryBlue.withOpacity(0.2)
                                        : greenColor.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              equal
                                  ? 'Equal'
                                  : 'More important by $displayLabel×',
                              style: TextStyle(
                                color: equal
                                    ? Colors.grey
                                    : (leftWins ? primaryBlue : greenColor),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.criteria[j],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: rightWins ? greenColor : Colors.white70,
                                fontWeight: rightWins
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // السلايدر
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: leftWins
                              ? primaryBlue
                              : (rightWins ? greenColor : Colors.white30),
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.white,
                          overlayColor: primaryBlue.withOpacity(0.2),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                        ),
                        child: Slider(
                          value: sliderVal,
                          min: 0,
                          max: (_scaleValues.length - 1).toDouble(),
                          divisions: _scaleValues.length - 1,
                          onChanged: (val) {
                            setState(() => _sliderIndices[idx] = val.round());
                            _recalculate();
                          },
                        ),
                      ),

                      // تسمية السكيل
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '← Much more important',
                            style: TextStyle(
                              color: primaryBlue.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            'Equal',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            'Much more important →',
                            style: TextStyle(
                              color: greenColor.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),

              // ── النتيجة (الأوزان) ──
              if (_result != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _result!.isConsistent
                          ? greenColor.withOpacity(0.4)
                          : redColor.withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _result!.isConsistent
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            color: _result!.isConsistent
                                ? greenColor
                                : redColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _result!.isConsistent
                                ? 'Weights are consistent ✓'
                                : 'Inconsistency detected — CR=\${_result!.consistencyRatio.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: _result!.isConsistent
                                  ? greenColor
                                  : redColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (!_result!.isConsistent) ...[
                        const SizedBox(height: 10),
                        // ── رسائل التناقض الذكية ──
                        ...() {
                          final hints = _getInconsistencyHints();
                          if (hints.isEmpty) {
                            return [
                              Text(
                                'Review your comparisons (CR must be < 0.10)',
                                style: TextStyle(
                                  color: redColor.withOpacity(0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ];
                          }
                          return hints
                              .map(
                                (hint) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A2E),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: redColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    hint,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      height: 1.7,
                                    ),
                                  ),
                                ),
                              )
                              .toList();
                        }(),
                      ],
                      const SizedBox(height: 14),
                      ...widget.criteria.asMap().entries.map((e) {
                        final w = _result!.weights[e.key];
                        final pct = AHPCalculator.weightsToPercent(
                          _result!.weights,
                        )[e.key];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e.value,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '$pct%',
                                    style: TextStyle(
                                      color: primaryBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: w,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    primaryBlue,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── زر التأكيد ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_result?.isConsistent ?? false)
                        ? primaryBlue
                        : Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _result == null
                      ? null
                      : () {
                          // ارجع Map: اسم المعيار → وزنه
                          final resultMap = <String, double>{};
                          for (int i = 0; i < n; i++) {
                            resultMap[widget.criteria[i]] = _result!.weights[i];
                          }
                          Navigator.pop(context, resultMap);
                        },
                  child: Text(
                    _result?.isConsistent ?? false
                        ? 'Confirm weights'
                        : 'Confirm despite inconsistency',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
