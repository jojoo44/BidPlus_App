import 'package:flutter/material.dart';
import 'ahp_calculator.dart';

/// Bottom sheet يشرح AHP للمدير بطريقة تفاعلية
/// يُفتح بضغطة زر "?" في AHPDialog
class AHPGuideSheet extends StatefulWidget {
  const AHPGuideSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AHPGuideSheet(),
    );
  }

  @override
  State<AHPGuideSheet> createState() => _AHPGuideSheetState();
}

class _AHPGuideSheetState extends State<AHPGuideSheet> {
  final Color bgColor = const Color(0xFF0D1219);
  final Color cardColor = const Color(0xFF1C242F);
  final Color blueColor = const Color(0xFF3395FF);
  final Color greenColor = const Color(0xFF34D399);
  final Color redColor = const Color(0xFFFF6B6B);

  int _tab = 0; // 0=Consistency Rule, 1=Priority Impact, 2=Try It

  // ── Try It — سلايدرات ──
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

  int _slAB = 4; // Cost vs Experience
  int _slAC = 4; // Cost vs Technical
  int _slBC = 4; // Experience vs Technical

  // ── Priority Impact ──
  int _priorityChoice = 1; // 0=Cost, 1=Experience, 2=Technical, 3=Equal

  // ── AHP حساب ──
  Map<String, dynamic> _calcAHP(double ab, double ac, double bc) {
    final matrix = [
      [1.0, ab, ac],
      [1 / ab, 1.0, bc],
      [1 / ac, 1 / bc, 1.0],
    ];
    final result = AHPCalculator.calculate(matrix);
    final pcts = AHPCalculator.weightsToPercent(result.weights);
    return {
      'weights': pcts,
      'cr': result.consistencyRatio,
      'ok': result.isConsistent,
    };
  }

  double _toVal(int idx) => idx == 4 ? 1.0 : 1.0 / _scaleValues[idx];

  String _toLabel(int idx) {
    if (idx == 4) return 'Equal';
    final li = idx < 4 ? (8 - idx) : idx;
    return '${_scaleLabels[li]}×';
  }

  Map<String, dynamic> _priorityToAHP() {
    switch (_priorityChoice) {
      case 0:
        return _calcAHP(5, 7, 3); // Cost first
      case 1:
        return _calcAHP(1 / 5, 1 / 3, 1 / 5); // Experience first
      case 2:
        return _calcAHP(1 / 7, 1 / 9, 1 / 3); // Technical first
      default:
        return _calcAHP(1, 1, 1); // Equal
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Handle ──
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: blueColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      color: blueColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AHP Guide',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'How to set weights correctly',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Tabs ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTab('Consistency', 0),
                  const SizedBox(width: 8),
                  _buildTab('Priority', 1),
                  const SizedBox(width: 8),
                  _buildTab('Try it', 2),
                ],
              ),
            ),

            const SizedBox(height: 4),
            Divider(color: Colors.white12, height: 1),

            // ── Content ──
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                child: _tab == 0
                    ? _buildConsistencyTab()
                    : _tab == 1
                    ? _buildPriorityTab()
                    : _buildTryItTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int idx) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? blueColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? blueColor.withOpacity(0.5) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? blueColor : Colors.grey,
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Tab 0: Consistency Rule
  // ──────────────────────────────────────────
  Widget _buildConsistencyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Core rule ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(left: BorderSide(color: blueColor, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The golden rule',
                style: TextStyle(
                  color: blueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.7,
                  ),
                  children: [
                    const TextSpan(text: 'If '),
                    TextSpan(
                      text: 'A > B',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' by x×, and '),
                    TextSpan(
                      text: 'B > C',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' by y×\nthen '),
                    TextSpan(
                      text: 'A > C',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' must be approximately '),
                    TextSpan(
                      text: 'x × y',
                      style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Walkthrough ──
        Text(
          'Step-by-step example',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        _buildStep(
          '1',
          'You set Criterion A as 5× more important than Criterion B.',
          blueColor,
          null,
        ),
        _buildStep(
          '2',
          'You set Criterion A as 3× more important than Criterion C.',
          blueColor,
          null,
        ),
        _buildStep(
          '3',
          'The system calculates: B vs C must be ≈ 5÷3 = 1.7×  (B slightly more important than C).',
          greenColor,
          Icons.check_circle_outline,
        ),
        _buildStep(
          '4',
          'If you then say C is 5× more important than B — that contradicts step 3. AHP flags this as inconsistent.',
          redColor,
          Icons.warning_amber_outlined,
        ),

        const SizedBox(height: 16),

        // ── Why it matters ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, color: blueColor, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Think of it like a tournament: if Team A beats Team B, and Team B beats Team C, '
                  'Team A should also beat Team C. Saying otherwise is a contradiction.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String num, String text, Color color, IconData? icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: icon != null
                  ? Icon(icon, color: color, size: 14)
                  : Center(
                      child: Text(
                        num,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildExampleCard({
    required String title,
    required Color titleColor,
    required Color borderColor,
    required List<Widget> rows,
    required String conclusion,
    required Color conclusionColor,
    required IconData conclusionIcon,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...rows,
        Divider(color: Colors.white12, height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(conclusionIcon, color: conclusionColor, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                conclusion,
                style: TextStyle(
                  color: conclusionColor,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _exampleRow(
    String subject,
    String verb,
    String value,
    Color subjectColor,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: subjectColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            subject,
            style: TextStyle(
              color: subjectColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$verb $value',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  // ──────────────────────────────────────────
  // Tab 1: Priority Impact
  // ──────────────────────────────────────────
  Widget _buildPriorityTab() {
    final result = _priorityToAHP();
    final weights = result['weights'] as List<int>;
    final cr = result['cr'] as double;
    final ok = result['ok'] as bool;
    final names = ['Cost', 'Experience', 'Technical'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your priority order directly shapes the weights — see how everything shifts.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 16),

        // Choices
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What matters most to you?',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildChoice('Price is everything', 0),
              _buildChoice('Experience matters most', 1),
              _buildChoice('Technical quality first', 2),
              _buildChoice('All equally important', 3),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Result
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ok
                  ? greenColor.withOpacity(0.3)
                  : redColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    ok
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    color: ok ? greenColor : redColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ok
                        ? 'Consistent ✓'
                        : 'CR = ${cr.toStringAsFixed(2)} — Inconsistent',
                    style: TextStyle(
                      color: ok ? greenColor : redColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(3, (i) => _buildWeightBar(names[i], weights[i])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoice(String label, int value) => GestureDetector(
    onTap: () => setState(() => _priorityChoice = value),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _priorityChoice == value ? blueColor : Colors.white30,
                width: 2,
              ),
            ),
            child: _priorityChoice == value
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: blueColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: _priorityChoice == value ? Colors.white : Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );

  // ──────────────────────────────────────────
  // Tab 2: Try It
  // ──────────────────────────────────────────
  Widget _buildTryItTab() {
    final ab = _toVal(_slAB);
    final ac = _toVal(_slAC);
    final bc = _toVal(_slBC);
    final res = _calcAHP(ab, ac, bc);
    final weights = res['weights'] as List<int>;
    final cr = res['cr'] as double;
    final ok = res['ok'] as bool;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Move the sliders and watch the weights update in real time.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSliderRow(
                'Cost vs Experience',
                _slAB,
                (v) => setState(() => _slAB = v),
                'Cost',
                'Experience',
              ),
              const SizedBox(height: 16),
              _buildSliderRow(
                'Cost vs Technical',
                _slAC,
                (v) => setState(() => _slAC = v),
                'Cost',
                'Technical',
              ),
              const SizedBox(height: 16),
              _buildSliderRow(
                'Experience vs Technical',
                _slBC,
                (v) => setState(() => _slBC = v),
                'Experience',
                'Technical',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ok
                  ? greenColor.withOpacity(0.3)
                  : redColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    ok
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    color: ok ? greenColor : redColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ok
                        ? 'Consistent ✓'
                        : 'Inconsistent — CR = ${cr.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: ok ? greenColor : redColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildWeightBar('Cost', weights[0]),
              _buildWeightBar('Experience', weights[1]),
              _buildWeightBar('Technical', weights[2]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow(
    String title,
    int value,
    ValueChanged<int> onChanged,
    String leftLabel,
    String rightLabel,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: value == 4
                  ? Colors.white12
                  : (value < 4
                        ? blueColor.withOpacity(0.2)
                        : greenColor.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _toLabel(value),
              style: TextStyle(
                color: value == 4
                    ? Colors.grey
                    : (value < 4 ? blueColor : greenColor),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: value < 4
              ? blueColor
              : (value > 4 ? greenColor : Colors.white30),
          inactiveTrackColor: Colors.white12,
          thumbColor: Colors.white,
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        ),
        child: Slider(
          value: value.toDouble(),
          min: 0,
          max: 8,
          divisions: 8,
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '← $leftLabel',
            style: TextStyle(color: blueColor.withOpacity(0.7), fontSize: 10),
          ),
          Text('equal', style: TextStyle(color: Colors.white38, fontSize: 10)),
          Text(
            '$rightLabel →',
            style: TextStyle(color: greenColor.withOpacity(0.7), fontSize: 10),
          ),
        ],
      ),
    ],
  );

  Widget _buildWeightBar(String name, int pct) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                color: blueColor,
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
            value: pct / 100,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(blueColor),
            minHeight: 6,
          ),
        ),
      ],
    ),
  );
}
