import 'package:flutter/material.dart';

class ContractorProposalDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> proposal;

  const ContractorProposalDetailsScreen({super.key, required this.proposal});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B1220);
    const card = Color(0xFF111A2A);
    const stroke = Color(0xFF22314A);
    const hint = Color(0xFF7F8EA3);

    final rfp = proposal['RFP'] as Map<String, dynamic>? ?? {};
    final status = proposal['status'] ?? 'Submitted';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Proposal Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _statusColor(status).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    status.toLowerCase() == 'accepted'
                        ? Icons.check_circle
                        : status.toLowerCase() == 'rejected'
                        ? Icons.cancel
                        : Icons.hourglass_empty,
                    color: _statusColor(status),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Status: $status',
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // RFP Info
            _buildSection('RFP Information', card, stroke, [
              _buildRow(Icons.title, 'Project', rfp['title'] ?? '—', hint),
              _buildRow(
                Icons.calendar_today,
                'Deadline',
                rfp['deadline'] ?? '—',
                hint,
              ),
              _buildRow(
                Icons.attach_money,
                'RFP Budget',
                rfp['budget'] != null ? '${rfp['budget']} SAR' : '—',
                hint,
              ),
            ]),

            const SizedBox(height: 16),

            // Proposal Info
            _buildSection('Your Proposal', card, stroke, [
              _buildRow(
                Icons.monetization_on,
                'Proposed Price',
                '${proposal['proposedPrice'] ?? '—'} SAR',
                hint,
              ),
              _buildRow(
                Icons.send,
                'Submitted On',
                proposal['submitDate'] ?? proposal['submissionDate'] ?? '—',
                hint,
              ),
            ]),

            const SizedBox(height: 16),

            // Cover Letter
            if ((proposal['description'] ?? '').toString().isNotEmpty) ...[
              _sectionTitle('Cover Letter'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: stroke),
                ),
                child: Text(
                  proposal['description'],
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.6,
                    fontSize: 14,
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

  Widget _buildSection(
    String title,
    Color card,
    Color stroke,
    List<Widget> rows,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle(title),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: stroke),
        ),
        child: Column(children: rows),
      ),
    ],
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _buildRow(IconData icon, String label, String value, Color hint) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 16),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: hint, fontSize: 13)),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
}
