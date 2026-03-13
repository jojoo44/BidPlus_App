import 'package:flutter/material.dart';

class FinalizeContractScreen extends StatelessWidget {
  final String contractTitle;
  final String contractId;
  final String managerName;
  final String contractorName;
  final String effectiveDate;

  const FinalizeContractScreen({
    super.key,
    required this.contractTitle,
    required this.contractId,
    required this.managerName,
    required this.contractorName,
    required this.effectiveDate,
  });

  void _finalize(BuildContext context) {
    // Frontend-only for now
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Finalize & Deploy ✅ (frontend-only)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B1220);
    const card = Color(0xFF111A2A);
    const stroke = Color(0xFF22314A);
    const hint = Color(0xFF7F8EA3);
    const primary = Color(0xFF6D7CFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Ready to Finalize',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: stroke),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1727),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: stroke),
                    ),
                    child: const Icon(Icons.verified_user, color: primary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ready to Finalize',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All terms have been approved by both\nparties. This contract is ready for\nfinalization.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: hint, height: 1.3),
                  ),
                  const SizedBox(height: 16),

                  _InfoTable(
                    contractTitle: contractTitle,
                    managerName: managerName,
                    contractorName: contractorName,
                    effectiveDate: effectiveDate,
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _finalize(context),
                      icon: const Icon(Icons.rocket_launch),
                      label: const Text('Finalize & Deploy Contract'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTable extends StatelessWidget {
  final String contractTitle;
  final String managerName;
  final String contractorName;
  final String effectiveDate;

  const _InfoTable({
    required this.contractTitle,
    required this.managerName,
    required this.contractorName,
    required this.effectiveDate,
  });

  @override
  Widget build(BuildContext context) {
    const stroke = Color(0xFF22314A);
    const hint = Color(0xFF7F8EA3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1727),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stroke),
      ),
      child: Column(
        children: [
          _row('Contract Title', contractTitle),
          const SizedBox(height: 10),
          _row('Manager', managerName),
          const SizedBox(height: 10),
          _row('Contractor', contractorName),
          const SizedBox(height: 10),
          _row('Effective Date', effectiveDate),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    const hint = Color(0xFF7F8EA3);
    return Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(
              color: hint,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
