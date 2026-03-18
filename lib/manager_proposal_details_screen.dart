import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class ManagerProposalDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> proposal;
  final VoidCallback onStatusChanged;

  const ManagerProposalDetailsScreen({
    super.key,
    required this.proposal,
    required this.onStatusChanged,
  });

  @override
  State<ManagerProposalDetailsScreen> createState() =>
      _ManagerProposalDetailsScreenState();
}

class _ManagerProposalDetailsScreenState
    extends State<ManagerProposalDetailsScreen> {
  late String _status;
  bool _isLoading = false;

  static const bg = Color(0xFF0D1219);
  static const card = Color(0xFF1C242F);
  static const stroke = Color(0xFF22314A);

  @override
  void initState() {
    super.initState();
    _status = widget.proposal['status'] ?? 'Submitted';
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      final proposalId = widget.proposal['ProposalID'];
      await supabase
          .from('proposals')
          .update({'status': newStatus})
          .eq('ProposalID', proposalId);

      // تحقق إن الكونتراكتور مفعّل الإشعارات ثم أرسل
      final contractorId = widget.proposal['submitterUserId'];
      if (contractorId != null) {
        final contractorData = await supabase
            .from('User')
            .select('notificationsEnabled')
            .eq('id', contractorId)
            .maybeSingle();

        if (contractorData != null &&
            contractorData['notificationsEnabled'] != false) {
          final rfpTitle = widget.proposal['RFP']?['title'] ?? 'a project';
          await supabase.from('Notification').insert({
            'userID': contractorId,
            'type': newStatus,
            'message': newStatus == 'Accepted'
                ? 'Your proposal for "$rfpTitle" has been accepted!'
                : newStatus == 'Rejected'
                ? 'Your proposal for "$rfpTitle" was not selected this time.'
                : 'Your proposal for "$rfpTitle" is now under review.',
            'readStatus': false,
            'timeStamp': DateTime.now().toIso8601String(),
          });
        }
      }

      setState(() => _status = newStatus);
      widget.onStatusChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proposal updated to $newStatus'),
            backgroundColor: newStatus == 'Accepted'
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under review':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rfp = widget.proposal['RFP'] as Map<String, dynamic>? ?? {};
    final name = widget.proposal['contractorname'] ?? 'Unknown';
    final price = widget.proposal['proposedPrice']?.toString() ?? '—';
    final date = widget.proposal['submitDate'] ?? '—';
    final desc = widget.proposal['description'] ?? '';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Proposal Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor(_status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _statusColor(_status).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon(_status), color: _statusColor(_status)),
                  const SizedBox(width: 10),
                  Text(
                    'Status: $_status',
                    style: TextStyle(
                      color: _statusColor(_status),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _sectionTitle('Contractor Info'),
            _infoCard([
              _row(Icons.person, 'Name', name),
              _row(Icons.attach_money, 'Proposed Price', '$price SAR'),
              _row(Icons.send, 'Submitted On', date),
            ]),

            const SizedBox(height: 16),
            _sectionTitle('Project Info'),
            _infoCard([
              _row(Icons.title, 'Project', rfp['title'] ?? '—'),
              _row(Icons.calendar_today, 'Deadline', rfp['deadline'] ?? '—'),
              _row(
                Icons.attach_money,
                'Budget',
                rfp['budget'] != null ? '${rfp['budget']} SAR' : '—',
              ),
            ]),

            const SizedBox(height: 16),
            if (desc.isNotEmpty) ...[
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
                  desc,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            if (_status.toLowerCase() != 'accepted' &&
                _status.toLowerCase() != 'rejected') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _updateStatus('Accepted'),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _updateStatus('Rejected'),
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text(
                        'Reject',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () => _updateStatus('Under Review'),
                  icon: const Icon(Icons.hourglass_top),
                  label: const Text(
                    'Under Review',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade600),
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () => _updateStatus('Submitted'),
                  child: const Text('Reset to Submitted'),
                ),
              ),
            ],

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'under review':
        return Icons.hourglass_top;
      default:
        return Icons.hourglass_empty;
    }
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _infoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: stroke),
    ),
    child: Column(children: rows),
  );

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
