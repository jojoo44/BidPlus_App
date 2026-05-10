// evaluate_tab_screen.dart
import 'package:flutter/material.dart';
import '../main.dart';
import 'contractor_evaluation_screen.dart';

class EvaluateTabScreen extends StatefulWidget {
  const EvaluateTabScreen({super.key});

  @override
  State<EvaluateTabScreen> createState() => _EvaluateTabScreenState();
}

class _EvaluateTabScreenState extends State<EvaluateTabScreen> {
  static const Color background = Color(0xFF0B1015);
  static const Color surface = Color(0xFF161B22);
  static const Color accentBlue = Color(0xFF2188FF);
  static const Color accentAmber = Color(0xFFEF9F27);
  static const Color accentGreen = Color(0xFF1D9E75);
  static const Color textGrey = Color(0xFF8B949E);

  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
        if (mounted) {
          setState(() {
            _sessions = [];
            _isLoading = false;
          });
        }
        return;
      }

      final sessionsData = await supabase
          .from('NegoSession')
          .select()
          .inFilter('rfp_id', rfpIds)
          .eq('status', 'Completed')
          .order('start_date', ascending: false);

      if ((sessionsData as List).isEmpty) {
        if (mounted) {
          setState(() {
            _sessions = [];
            _isLoading = false;
          });
        }
        return;
      }

      // ← rfpId موجود الحين في الجدول
      final evalsData = await supabase
          .from('ContractorEvaluation')
          .select('contractorId, rfpId')
          .eq('managerId', userId);

      final reviewedSet = <String>{};
      for (final e in evalsData as List) {
        reviewedSet.add('${e['rfpId']}_${e['contractorId']}');
      }

      final enriched = <Map<String, dynamic>>[];
      for (final session in sessionsData) {
        final rfpId = session['rfp_id']?.toString() ?? '';
        String contractorId = session['contractor_id']?.toString() ?? '';

        if (contractorId.isEmpty) {
          try {
            final round = await supabase
                .from('NegoRounds')
                .select('contractor_id')
                .eq('sessionID', session['session_id'])
                .not('contractor_id', 'is', null)
                .limit(1)
                .maybeSingle();
            contractorId = round?['contractor_id']?.toString() ?? '';
          } catch (_) {}
        }

        String rfpTitle = '—';
        String contractorName = '—';

        try {
          final rfp = await supabase
              .from('RFP')
              .select('title')
              .eq('rfpID', session['rfp_id'])
              .single();
          rfpTitle = rfp['title'] ?? '—';
        } catch (_) {}

        if (contractorId.isNotEmpty) {
          try {
            final user = await supabase
                .from('User')
                .select('username')
                .eq('id', contractorId)
                .maybeSingle();
            contractorName = user?['username'] ?? '—';
          } catch (_) {}
        }

        if (contractorId.isEmpty) continue;

        final key = '${rfpId}_$contractorId';
        enriched.add({
          ...session,
          'rfpTitle': rfpTitle,
          'contractorName': contractorName,
          'contractorId': contractorId,
          'rfpId': rfpId,
          'reviewed': reviewedSet.contains(key),
        });
      }

      if (mounted) {
        setState(() {
          _sessions = enriched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('EvaluateTab error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'pending') {
      return _sessions.where((s) => !(s['reviewed'] as bool)).toList();
    }
    if (_filter == 'done') {
      return _sessions.where((s) => s['reviewed'] as bool).toList();
    }
    return _sessions;
  }

  int get _pendingCount =>
      _sessions.where((s) => !(s['reviewed'] as bool)).length;
  int get _doneCount => _sessions.where((s) => s['reviewed'] as bool).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Evaluations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentBlue))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: accentBlue,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        _statCard('Pending', _pendingCount, accentAmber),
                        const SizedBox(width: 8),
                        _statCard('Done', _doneCount, accentGreen),
                        const SizedBox(width: 8),
                        _statCard('Total', _sessions.length, accentBlue),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _filterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _filterChip('Pending', 'pending'),
                        const SizedBox(width: 8),
                        _filterChip('Completed', 'done'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _filter == 'pending'
                                      ? Icons.check_circle_outline
                                      : Icons.star_outline,
                                  color: _filter == 'pending'
                                      ? accentGreen
                                      : textGrey,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _filter == 'pending'
                                      ? 'All evaluations done!'
                                      : 'No completed sessions yet',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _sessionCard(_filtered[i]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, int value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _filterChip(String label, String value) {
    final isActive = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? accentAmber.withValues(alpha: 0.15) : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? accentAmber.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? accentAmber : textGrey,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> session) {
    final reviewed = session['reviewed'] as bool;
    final startDate = session['start_date'] != null
        ? _fmtDate(session['start_date'])
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reviewed
              ? accentGreen.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (reviewed ? accentGreen : accentAmber).withValues(alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  reviewed
                      ? Icons.check_circle_outline
                      : Icons.handshake_outlined,
                  color: reviewed ? accentGreen : accentAmber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['rfpTitle'] ?? '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session['contractorName'] ?? '—',
                      style: const TextStyle(color: textGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Completed: $startDate',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: reviewed
                      ? accentGreen.withValues(alpha: 0.12)
                      : accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  reviewed ? 'Done' : 'Pending',
                  style: TextStyle(
                    color: reviewed ? accentGreen : accentAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: reviewed ? accentGreen : Colors.amber,
                side: BorderSide(
                  color: reviewed ? accentGreen.withValues(alpha:0.4) : Colors.amber,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: Icon(
                reviewed ? Icons.check_circle_outline : Icons.star_rate_rounded,
                color: reviewed ? accentGreen : Colors.amber,
                size: 18,
              ),
              label: Text(
                reviewed ? 'Already Reviewed' : 'Rate Contractor',
                style: TextStyle(
                  color: reviewed ? accentGreen : Colors.amber,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onPressed: () => _openEvaluation(session),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEvaluation(Map<String, dynamic> session) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContractorEvaluationScreen(
          contractorId: session['contractorId'] ?? '',
          contractorName: session['contractorName'] ?? '—',
          rfpTitle: session['rfpTitle'] ?? '—',
          rfpId: session['rfpId'] ?? '',
        ),
      ),
    );
    if (result == true) _loadData();
  }

  String _fmtDate(String d) {
    try {
      final dt = DateTime.parse(d);
      const months = [
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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return d;
    }
  }
}
