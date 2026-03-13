import 'package:flutter/material.dart';
import 'contractor_rfp_details_screen.dart';

class ProjectDetailsScreen extends StatelessWidget {
  final String projectTitle;
  final String deadline;
  final String rfpId;

  const ProjectDetailsScreen({
    super.key,
    required this.projectTitle,
    required this.deadline,
    required this.rfpId,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B1220);
    const card = Color(0xFF111A2A);
    const stroke = Color(0xFF22314A);
    const hint = Color(0xFF7F8EA3);
    const primary = Color(0xFF0E8BFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Project Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projectTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Deadline: $deadline',
                      style: const TextStyle(
                        color: hint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose to submit your proposal for this project.',
                      style: TextStyle(color: hint, height: 1.3),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContractorRFPDetailsScreen(rfpId: rfpId),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  child: const Text('View & Submit Proposal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
