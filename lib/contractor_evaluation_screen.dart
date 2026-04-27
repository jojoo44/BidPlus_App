// contractor_evaluation_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class ContractorEvaluationScreen extends StatefulWidget {
  final String contractorId;
  final String contractorName;
  final String rfpTitle;
  final String rfpId;

  const ContractorEvaluationScreen({
    super.key,
    required this.contractorId,
    required this.contractorName,
    required this.rfpTitle,
    required this.rfpId,
  });

  @override
  State<ContractorEvaluationScreen> createState() =>
      _ContractorEvaluationScreenState();
}

class _ContractorEvaluationScreenState
    extends State<ContractorEvaluationScreen> {
  static const Color background = Color(0xFF12141D);
  static const Color surface = Color(0xFF1E212A);
  static const Color accentBlue = Color(0xFF00D1FF);
  static const Color textGrey = Color(0xFF8B949E);

  final Map<String, int> _ratings = {
    'Work Quality': 0,
    'Communication': 0,
    'Punctuality': 0,
  };

  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  bool _alreadyRated = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyRated();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _checkIfAlreadyRated() async {
    try {
      final managerId = supabase.auth.currentUser?.id;
      if (managerId == null) return;

      final existing = await supabase
          .from('ContractorEvaluation')
          .select('evaluationId')
          .eq('contractorId', widget.contractorId)
          .eq('managerId', managerId)
          .maybeSingle();

      if (existing != null && mounted) {
        setState(() => _alreadyRated = true);
      }
    } catch (_) {}
  }

  Future<void> _submitReview() async {
    // تحقق إن كل التقييمات مكتملة
    if (_ratings.values.any((r) => r == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please rate all categories'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final managerId = supabase.auth.currentUser?.id;
      if (managerId == null) throw Exception('Not logged in');

      final qualityRating = _ratings['Work Quality']!.toDouble();
      final timelinessRating =
          ((_ratings['Communication']! + _ratings['Punctuality']!) / 2);
      final overallScore =
          double.parse(((_ratings.values.reduce((a, b) => a + b)) / _ratings.length)
              .toStringAsFixed(2));

      await supabase.from('ContractorEvaluation').insert({
        'contractorId': widget.contractorId,
        'managerId': managerId,
        'quality': qualityRating,
        'timeliness': timelinessRating,
        'overallScore': overallScore,
        'comment': _feedbackController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() => _alreadyRated = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Evaluate Contractor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هيدر معلومات الكونتراكتور والبروجكت
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentBlue.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: accentBlue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.contractorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.folder_outlined,
                                color: textGrey, size: 13),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.rfpTitle,
                                style: const TextStyle(
                                    color: textGrey, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_alreadyRated) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green),
                    SizedBox(width: 10),
                    Text(
                      'You have already reviewed this contractor.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              const Text(
                'How was your experience?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              _buildRatingSection('Work Quality', Icons.build_outlined),
              _buildRatingSection('Communication', Icons.chat_bubble_outline),
              _buildRatingSection('Punctuality', Icons.access_time_outlined),

              const SizedBox(height: 8),
              TextField(
                controller: _feedbackController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write your feedback here...',
                  hintStyle: const TextStyle(color: textGrey),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: accentBlue.withOpacity(0.4)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitReview,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Submit Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection(String title, IconData icon) {
    final current = _ratings[title] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textGrey, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _ratings[title] = starIndex),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    starIndex <= current ? Icons.star : Icons.star_border,
                    color: starIndex <= current ? accentBlue : textGrey,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}