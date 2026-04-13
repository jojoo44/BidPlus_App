// contractor_offers_screen.dart
import 'package:flutter/material.dart';
import 'contractor_proposal_details_screen.dart';
import '../main.dart';

class ContractorOffersScreen extends StatefulWidget {
  const ContractorOffersScreen({super.key});

  @override
  State<ContractorOffersScreen> createState() => _ContractorOffersScreenState();
}

class _ContractorOffersScreenState extends State<ContractorOffersScreen> {
  List<Map<String, dynamic>> _proposals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProposals();
  }

  Future<void> _loadProposals() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('proposals')
          .select('*, RFP(*)')
          .eq('submitterUserId', userId)
          .order('submissionDate', ascending: false);

      if (mounted) {
        setState(() {
          _proposals = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B1220);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Proposals',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0E8BFF)),
            )
          : _proposals.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, color: Colors.grey, size: 48),
                  SizedBox(height: 12),
                  Text(
                    "You haven't submitted any proposals yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProposals,
              color: const Color(0xFF0E8BFF),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _proposals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final proposal = _proposals[i];
                  final rfp = proposal['RFP'] as Map<String, dynamic>? ?? {};

                  return _ProposalCard(
                    rfpTitle: rfp['title'] ?? 'Untitled',
                    deadline: rfp['deadline'] ?? '—',
                    proposedPrice: proposal['proposedPrice']?.toString() ?? '—',
                    status: proposal['status'] ?? 'Submitted',
                    submissionDate: proposal['submissionDate'] ?? '—',
                    onViewDetails: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ContractorProposalDetailsScreen(proposal: proposal),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final String rfpTitle;
  final String deadline;
  final String proposedPrice;
  final String status;
  final String submissionDate;
  final VoidCallback onViewDetails;

  const _ProposalCard({
    required this.rfpTitle,
    required this.deadline,
    required this.proposedPrice,
    required this.status,
    required this.submissionDate,
    required this.onViewDetails,
  });

  Color _statusColor() {
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
    const card   = Color(0xFF111A2A);
    const stroke = Color(0xFF22314A);
    const hint   = Color(0xFF7F8EA3);
    const primary = Color(0xFF0E8BFF);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stroke),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rfpTitle,
                  style: const TextStyle(
                    color     : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize  : 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color     : _statusColor(),
                    fontSize  : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          _meta(Icons.attach_money, 'Your Price: $proposedPrice SAR', hint),
          const SizedBox(height: 6),
          _meta(Icons.calendar_today_outlined, 'RFP Deadline: $deadline', hint),
          const SizedBox(height: 6),
          _meta(Icons.send_outlined, 'Submitted: $submissionDate', hint),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewDetails,
              style: OutlinedButton.styleFrom(
                side          : const BorderSide(color: primary),
                foregroundColor: primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: const Text('View Proposal Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text, Color hint) => Row(
    children: [
      Icon(icon, color: Colors.white54, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color     : hint,
            fontWeight: FontWeight.w600,
            fontSize  : 13,
          ),
        ),
      ),
    ],
  );
}