// ahp_dialog.dart
import 'package:flutter/material.dart';
import 'ahp_calculator.dart';
import 'ahp_guide_sheet.dart';

class AHPDialog extends StatefulWidget {
  final List<String> criteria;
  const AHPDialog({super.key, required this.criteria});

  @override
  State<AHPDialog> createState() => _AHPDialogState();
}

class _AHPDialogState extends State<AHPDialog> {
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
  late List<int> _sliderIndices;
  AHPResult? _result;

  @override
  void initState() {
    super.initState();
    n = widget.criteria.length;
    pairCount = AHPCalculator.comparisonsCount(n);
    _sliderIndices = List.filled(pairCount, 4);
    _recalculate();
  }

  void _recalculate() {
    final upperValues = _sliderIndices.map((idx) {
      if (idx == 4) return 1.0;
      final raw = _scaleValues[idx];
      return 1.0 / raw;
    }).toList();
    final matrix = AHPCalculator.buildMatrix(n, upperValues);
    setState(() => _result = AHPCalculator.calculate(matrix));
  }

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
            final expMsg = (expVal < 1.5)
                ? '  → $nameA and $nameC should be approximately equal\n  ← move "$nameA vs $nameC" slider to center'
                : '  → $expWinner should be more important than $expLoser by ${expVal.toStringAsFixed(0)}×\n  ← adjust "$nameA vs $nameC"';
            hints.add(
              '• $abWinner is more important than $abLoser by ${abVal.toStringAsFixed(0)}×\n'
              '  and $bcWinner is more important than $bcLoser by ${bcVal.toStringAsFixed(0)}×\n'
              '$expMsg',
            );
          }
        }
      }
    }
    return hints;
  }

  List<(int, int)> get _pairs {
    final pairs = <(int, int)>[];
    for (int i = 0; i < n; i++)
      for (int j = i + 1; j < n; j++) pairs.add((i, j));
    return pairs;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: bgColor,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenW < 400 ? 10 : 16,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                    child: Icon(Icons.balance, color: primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'criteria weights',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenW < 400 ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Move the slider toward the more important criterion',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.help_outline,
                      color: primaryBlue,
                      size: 18,
                    ),
                    onPressed: () => AHPGuideSheet.show(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

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
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      // أسماء المعيارين + البادج
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
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
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
                              equal ? 'Equal' : '×$displayLabel',
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
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

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

                      // ── تسمية السكيل — مُصلحة ✓ ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '← More',
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
                              'More →',
                              style: TextStyle(
                                color: greenColor.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),

              // ── النتيجة ──
              if (_result != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
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
                          Expanded(
                            child: Text(
                              _result!.isConsistent
                                  ? 'Weights are consistent ✓'
                                  : 'Inconsistency — CR=${_result!.consistencyRatio.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: _result!.isConsistent
                                    ? greenColor
                                    : redColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!_result!.isConsistent) ...[
                        const SizedBox(height: 10),
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
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A2E),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: redColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    hint,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              )
                              .toList();
                        }(),
                      ],
                      const SizedBox(height: 12),
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

              const SizedBox(height: 20),

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
