// contractor_proposal_details_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class ContractorProposalDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> proposal;

  const ContractorProposalDetailsScreen({super.key, required this.proposal});

  @override
  State<ContractorProposalDetailsScreen> createState() =>
      _ContractorProposalDetailsScreenState();
}

class _ContractorProposalDetailsScreenState
    extends State<ContractorProposalDetailsScreen> {
  List<Map<String, dynamic>> _attachments = [];
  bool _loadingDocs = true;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    try {
      final proposalId = widget.proposal['ProposalID'] ?? widget.proposal['id'];
      if (proposalId == null) {
        setState(() => _loadingDocs = false);
        return;
      }
      final data = await supabase
          .from('Document')
          .select()
          .eq('proposalID', proposalId)
          .eq('uploadType', 'Proposal_Attachment');
      if (mounted) {
        setState(() {
          _attachments = List<Map<String, dynamic>>.from(data);
          _loadingDocs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'negotiation':
        return Colors.purple;
      case 'shortlisted':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'negotiation':
        return Icons.handshake_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }

  // parse criteria من comments "Cost: ... | Experience: ..."
  List<Map<String, String>> get _criteriaResponses {
    final comments = widget.proposal['comments'] as String?;
    if (comments == null || comments.isEmpty) return [];
    return comments.split('|').map((part) {
      final trimmed = part.trim();
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx == -1) return {'name': trimmed, 'value': ''};
      return {
        'name': trimmed.substring(0, colonIdx).trim(),
        'value': trimmed.substring(colonIdx + 1).trim(),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B1220);
    const card = Color(0xFF111A2A);
    const stroke = Color(0xFF22314A);
    const hint = Color(0xFF7F8EA3);
    const primary = Color(0xFF0E8BFF);

    final rfp = widget.proposal['RFP'] as Map<String, dynamic>? ?? {};
    final status = widget.proposal['status'] ?? 'Submitted';
    final criteria = _criteriaResponses;

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

            // ── Status Banner
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
                  Icon(_statusIcon(status), color: _statusColor(status)),
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

            // ── RFP Info
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
              if (rfp['requiredTag'] != null)
                _buildRow(
                  Icons.label_outline,
                  'Category',
                  rfp['requiredTag'],
                  hint,
                ),
            ]),

            const SizedBox(height: 16),

            // ── Proposal Info
            _buildSection('Your Proposal', card, stroke, [
              _buildRow(
                Icons.monetization_on,
                'Proposed Price',
                '${widget.proposal['proposedPrice'] ?? '—'} SAR',
                hint,
              ),
              _buildRow(
                Icons.send,
                'Submitted On',
                widget.proposal['submitDate'] ??
                    widget.proposal['submissionDate'] ??
                    '—',
                hint,
              ),
            ]),

            const SizedBox(height: 16),

            // ── Cover Letter
            if ((widget.proposal['description'] ?? '').toString().isNotEmpty) ...[
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
                  widget.proposal['description'],
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Criteria Responses
            if (criteria.isNotEmpty) ...[
              _sectionTitle('Evaluation Criteria — Your Responses'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: stroke),
                ),
                child: Column(
                  children: criteria.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primary.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              c['name'] ?? '',
                              style: const TextStyle(
                                color: primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c['value'] ?? '—',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Attachments
            _sectionTitle('Attachments'),
            _loadingDocs
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: primary),
                    ),
                  )
                : _attachments.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: stroke),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.attachment, color: Colors.white24, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'No attachments uploaded',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _attachments.map((doc) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: stroke),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                doc['fullName'] ?? 'File',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.download_outlined,
                              color: Colors.white38,
                              size: 18,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

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
  ) =>
      Column(
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
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );
}