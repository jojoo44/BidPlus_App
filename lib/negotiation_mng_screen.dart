// negotiation_mng_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'negotiation_screen.dart';
import 'contractor_evaluation_screen.dart';

class NegotiationArchiveScreen extends StatefulWidget {
  const NegotiationArchiveScreen({super.key});

  @override
  State<NegotiationArchiveScreen> createState() =>
      _NegotiationArchiveScreenState();
}

class _NegotiationArchiveScreenState extends State<NegotiationArchiveScreen> {
  static const Color background = Color(0xFF0B1015);
  static const Color surface = Color(0xFF161B22);
  static const Color primaryPurple = Color(0xFF6342E8);
  static const Color accentBlue = Color(0xFF2188FF);
  static const Color textGrey = Color(0xFF8B949E);

  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final rfpData = await supabase
          .from('RFP')
          .select('rfpID')
          .eq('creatorUser', userId);

      final rfpIds = (rfpData as List).map((r) => r['rfpID'] as int).toList();

      if (rfpIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final sessionsData = await supabase
          .from('NegoSession')
          .select()
          .inFilter('rfp_id', rfpIds)
          .order('start_date', ascending: false);

      final enriched = <Map<String, dynamic>>[];
      for (final session in sessionsData) {
        final rfpId = session['rfp_id'] as int?;

        Map<String, dynamic> rfpInfo = {};
        if (rfpId != null) {
          try {
            final rfp = await supabase
                .from('RFP')
                .select('title, budget')
                .eq('rfpID', rfpId)
                .single();
            rfpInfo = rfp;
          } catch (_) {}
        }

        String contractorName = 'Unknown';
        String contractorId = '';
        String proposalId = '';
        if (rfpId != null) {
          try {
            final proposals = await supabase
                .from('proposals')
                .select('submitterUserId, status, ProposalID')
                .eq('RFP', rfpId)
                .order('ProposalID', ascending: false);

            String? foundContractorId;
            for (final p in proposals) {
              if (p['status'] == 'Accepted') {
                foundContractorId = p['submitterUserId']?.toString();
                proposalId = p['ProposalID']?.toString() ?? '';
                break;
              }
            }
            foundContractorId ??= (proposals as List).isNotEmpty
                ? proposals.first['submitterUserId']?.toString()
                : null;

            if (foundContractorId != null) {
              contractorId = foundContractorId;
              final user = await supabase
                  .from('User')
                  .select('username')
                  .eq('id', foundContractorId)
                  .maybeSingle();
              contractorName = user?['username'] ?? 'Unknown';
            }
          } catch (_) {}
        }

        enriched.add({
          ...session,
          'rfpTitle': rfpInfo['title'] ?? '—',
          'rfpBudget': rfpInfo['budget'],
          'contractorName': contractorName,
          'contractorId': contractorId,
          'proposalId': proposalId,
        });
      }

      if (mounted) {
        setState(() {
          _sessions = enriched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _activeCount =>
      _sessions.where((s) => s['status'] == 'Active').length;
  int get _completedCount =>
      _sessions.where((s) => s['status'] == 'Completed').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Negotiation Sessions',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: accentBlue))
          : RefreshIndicator(
              onRefresh: _loadSessions,
              color: accentBlue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    _buildMiniStat(
                        'Active', _activeCount.toString(), Colors.orangeAccent),
                    const SizedBox(width: 12),
                    _buildMiniStat('Completed', _completedCount.toString(),
                        Colors.greenAccent),
                  ]),
                  const SizedBox(height: 20),
                  const Text(
                    'Negotiation Sessions',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_sessions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(children: [
                          const Icon(Icons.handshake_outlined,
                              color: textGrey, size: 48),
                          const SizedBox(height: 12),
                          const Text('No negotiation sessions yet',
                              style: TextStyle(color: textGrey)),
                          const SizedBox(height: 6),
                          const Text('Accept a proposal to start negotiation',
                              style:
                                  TextStyle(color: textGrey, fontSize: 12)),
                        ]),
                      ),
                    )
                  else
                    ..._sessions.map((session) => _buildSessionCard(session)),
                ],
              ),
            ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: textGrey, fontSize: 13)),
          const SizedBox(height: 8),
          Text(count,
              style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final status = session['status'] ?? 'Active';
    final isCompleted = status == 'Completed';
    final statusColor =
        isCompleted ? Colors.greenAccent : Colors.orangeAccent;
    final startDate = session['start_date'] != null
        ? _fmtDate(session['start_date'])
        : '—';
    final rfpId = session['rfp_id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AINegotiationScreen(
            sessionId: session['session_id'].toString(),
            rfpId: rfpId,
            rfpTitle: session['rfpTitle'] ?? '—',
            contractorName: session['contractorName'] ?? '—',
            budget: session['rfpBudget'],
            proposalId: session['proposalId'] ?? '',
            selectedCriteria: const [],
            isManager: true,
          ),
        ),
      ).then((_) => _loadSessions()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.handshake_outlined,
                    color: primaryPurple),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session['rfpTitle'] ?? '—',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(session['contractorName'] ?? '—',
                          style: const TextStyle(
                              color: textGrey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Started: $startDate',
                          style: const TextStyle(
                              color: textGrey, fontSize: 11)),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: textGrey, size: 20),
              ]),
            ]),

            // زر Rate Contractor يظهر فقط للسيشن المكتملة
            if (isCompleted && session['contractorId'] != '') ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.star_rate_rounded,
                      color: Colors.amber, size: 18),
                  label: const Text(
                    'Rate Contractor',
                    style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContractorEvaluationScreen(
                        contractorId: session['contractorId'] ?? '',
                        contractorName: session['contractorName'] ?? '—',
                        rfpTitle: session['rfpTitle'] ?? '—',
                        rfpId: rfpId,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(String d) {
    try {
      final dt = DateTime.parse(d);
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return d;
    }
  }
}