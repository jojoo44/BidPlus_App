// contractor_negotiation_archive_screen.dart
import 'package:flutter/material.dart';
import '../main.dart';
import 'contractor_negotiation_screen.dart';

class ContractorNegotiationArchiveScreen extends StatefulWidget {
  const ContractorNegotiationArchiveScreen({super.key});

  @override
  State<ContractorNegotiationArchiveScreen> createState() =>
      _ContractorNegotiationArchiveScreenState();
}

class _ContractorNegotiationArchiveScreenState
    extends State<ContractorNegotiationArchiveScreen> {
  static const Color background = Color(0xFF0B1015);
  static const Color surface = Color(0xFF161B22);
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

      // ← الجديد: جيب sessions بـ contractor_id مباشرة
      final sessionsData = await supabase
          .from('NegoSession')
          .select()
          .eq('contractor_id', userId)
          .order('start_date', ascending: false);

      if ((sessionsData as List).isEmpty) {
        if (mounted)
          setState(() {
            _sessions = [];
            _isLoading = false;
          });
        return;
      }

      final enriched = <Map<String, dynamic>>[];
      for (final session in sessionsData) {
        final rfpId = session['rfp_id']?.toString();
        String rfpTitle = '—';
        String managerName = '—';
        List<String> criteria = [];
        String proposalId = '';

        if (rfpId != null) {
          try {
            final rfp = await supabase
                .from('RFP')
                .select('title, creatorUser, evaluationCriteria')
                .eq('rfpID', rfpId)
                .single();
            rfpTitle = rfp['title'] ?? '—';

            final manager = await supabase
                .from('User')
                .select('username')
                .eq('id', rfp['creatorUser'])
                .maybeSingle();
            managerName = manager?['username'] ?? '—';

            final raw = rfp['evaluationCriteria'] as String?;
            if (raw != null && raw.isNotEmpty) {
              criteria = raw
                  .split(',')
                  .map((p) {
                    final idx = p.indexOf(':');
                    return idx == -1 ? p.trim() : p.substring(0, idx).trim();
                  })
                  .where((c) => c.isNotEmpty)
                  .toList();
            }
          } catch (_) {}

          try {
            final proposal = await supabase
                .from('proposals')
                .select('ProposalID')
                .eq('RFP', rfpId)
                .eq('submitterUserId', userId)
                .maybeSingle();
            proposalId = proposal?['ProposalID']?.toString() ?? '';
          } catch (_) {}
        }

        enriched.add({
          ...session,
          'rfpTitle': rfpTitle,
          'managerName': managerName,
          'criteria': criteria,
          'proposalId': proposalId,
        });
      }

      if (mounted)
        setState(() {
          _sessions = enriched;
          _isLoading = false;
        });
    } catch (e) {
      debugPrint('ContractorNegotiationArchive error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _activeCount => _sessions
      .where((s) => s['status'] == 'Active' || s['status'] == 'Invited')
      .length;
  int get _completedCount =>
      _sessions.where((s) => s['status'] == 'Completed').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Negotiations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentBlue))
          : RefreshIndicator(
              onRefresh: _loadSessions,
              color: accentBlue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _buildMiniStat(
                        'Active',
                        _activeCount.toString(),
                        Colors.orangeAccent,
                      ),
                      const SizedBox(width: 12),
                      _buildMiniStat(
                        'Completed',
                        _completedCount.toString(),
                        Colors.greenAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (_activeCount > 0) ...[
                    _sectionTitle('Active Sessions'),
                    ..._sessions
                        .where(
                          (s) =>
                              s['status'] == 'Active' ||
                              s['status'] == 'Invited',
                        )
                        .map((s) => _buildSessionCard(s, isActive: true)),
                    const SizedBox(height: 16),
                  ],

                  if (_completedCount > 0) ...[
                    _sectionTitle('Completed Sessions'),
                    ..._sessions
                        .where((s) => s['status'] == 'Completed')
                        .map((s) => _buildSessionCard(s, isActive: false)),
                  ],

                  if (_sessions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.handshake_outlined,
                              color: textGrey,
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No negotiation sessions yet',
                              style: TextStyle(
                                color: textGrey,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Once the manager invites you,\nsessions will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildMiniStat(String label, String count, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: textGrey, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSessionCard(
    Map<String, dynamic> session, {
    required bool isActive,
  }) {
    final statusColor = isActive ? Colors.orangeAccent : Colors.greenAccent;
    final startDate = session['start_date'] != null
        ? _fmtDate(session['start_date'])
        : '—';
    final criteria = List<String>.from(session['criteria'] ?? []);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContractorNegotiationScreen(
            sessionId: session['session_id'].toString(),
          ),
        ),
      ).then((_) => _loadSessions()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withOpacity(isActive ? 0.25 : 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isActive ? Colors.orange : Colors.green).withOpacity(
                  0.1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isActive
                    ? Icons.handshake_outlined
                    : Icons.check_circle_outline,
                color: isActive ? Colors.orangeAccent : Colors.greenAccent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session['rfpTitle'] ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manager: ${session['managerName'] ?? '—'}',
                    style: const TextStyle(color: textGrey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Started: $startDate',
                    style: const TextStyle(color: textGrey, fontSize: 11),
                  ),
                  if (criteria.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: criteria
                          .map(
                            (c) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: accentBlue.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                c,
                                style: const TextStyle(
                                  color: accentBlue,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    session['status'] ?? '—',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: textGrey,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String d) {
    try {
      final dt = DateTime.parse(d);
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return d;
    }
  }
}
