// contractor_negotiation_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import 'negotiation_screen.dart';

class ContractorNegotiationScreen extends StatefulWidget {
  final String? sessionId;
  const ContractorNegotiationScreen({super.key, this.sessionId});

  @override
  State<ContractorNegotiationScreen> createState() =>
      _ContractorNegotiationScreenState();
}

class _ContractorNegotiationScreenState
    extends State<ContractorNegotiationScreen> {
  static const Color bg = Color(0xFF0A1628);
  static const Color cardColor = Color(0xFF0F1F3A);
  static const Color accent = Color(0xFF41C0FF);

  bool _isLoading = true;
  String? _contractorId;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _contractorId = supabase.auth.currentUser?.id;
    if (widget.sessionId != null) {
      _openSessionById(widget.sessionId!);
    } else {
      _loadSessions();
    }
  }

  Future<void> _openSessionById(String sessionId) async {
    setState(() => _isLoading = true);
    try {
      final sessionIdInt = int.tryParse(sessionId) ?? sessionId;
      final sessionData = await supabase
          .from('NegoSession').select().eq('session_id', sessionIdInt).single();
      final rfpId = sessionData['rfp_id']?.toString() ?? '';
      String rfpTitle = '—', managerName = '—', proposalId = '';
      List<String> criteria = [];
      try {
        final rfp = await supabase.from('RFP')
            .select('title, creatorUser, evaluationCriteria')
            .eq('rfpID', rfpId).single();
        rfpTitle = rfp['title'] ?? '—';
        final manager = await supabase.from('User')
            .select('username').eq('id', rfp['creatorUser']).single();
        managerName = manager['username'] ?? '—';
        final raw = rfp['evaluationCriteria'] as String?;
        if (raw != null && raw.isNotEmpty) {
          criteria = raw.split(',').map((p) {
            final idx = p.indexOf(':');
            return idx == -1 ? p.trim() : p.substring(0, idx).trim();
          }).toList();
        }
      } catch (_) {}
      try {
        final proposal = await supabase.from('proposals')
            .select('ProposalID').eq('RFP', rfpId)
            .eq('submitterUserId', _contractorId!).single();
        proposalId = proposal['ProposalID']?.toString() ?? '';
      } catch (_) {}
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => AINegotiationScreen(
            sessionId: sessionId, rfpId: rfpId, rfpTitle: rfpTitle,
            contractorName: managerName, selectedCriteria: criteria,
            proposalId: proposalId, isManager: false,
          ),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      if (_contractorId == null) return;
      final proposals = await supabase.from('proposals')
          .select('RFP, ProposalID').eq('submitterUserId', _contractorId!)
          .eq('status', 'Accepted');
      final rfpIds = (proposals as List).map((p) => p['RFP'])
          .where((id) => id != null).toList();
      if (rfpIds.isEmpty) { if (mounted) setState(() => _isLoading = false); return; }
      final sessionsData = await supabase.from('NegoSession').select()
          .inFilter('rfp_id', rfpIds).order('start_date', ascending: false);
      final enriched = <Map<String, dynamic>>[];
      for (final session in sessionsData) {
        final rfpId = session['rfp_id'];
        final proposalRow = (proposals as List).firstWhere(
            (p) => p['RFP'] == rfpId, orElse: () => {});
        try {
          final rfp = await supabase.from('RFP')
              .select('title, creatorUser, evaluationCriteria')
              .eq('rfpID', rfpId).single();
          final manager = await supabase.from('User')
              .select('username').eq('id', rfp['creatorUser']).single();
          final lastMsg = await supabase.from('NegoRounds').select('Terms, created_at')
              .eq('sessionID', session['session_id'])
              .order('roundID', ascending: false).limit(1).maybeSingle();
          final raw = rfp['evaluationCriteria'] as String?;
          List<String> criteria = [];
          if (raw != null && raw.isNotEmpty) {
            criteria = raw.split(',').map((p) {
              final idx = p.indexOf(':');
              return idx == -1 ? p.trim() : p.substring(0, idx).trim();
            }).toList();
          }
          enriched.add({
            ...session, 'rfpTitle': rfp['title'] ?? '—',
            'managerName': manager['username'] ?? '—', 'criteria': criteria,
            'proposalId': proposalRow['ProposalID']?.toString() ?? '',
            'lastMessage': lastMsg?['Terms'] ?? 'No messages yet',
            'lastTime': lastMsg?['created_at'],
          });
        } catch (_) {
          enriched.add({...session, 'rfpTitle': '—', 'managerName': '—',
              'criteria': <String>[], 'proposalId': '', 'lastMessage': 'No messages yet'});
        }
      }
      if (mounted) setState(() { _sessions = enriched; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessionId != null) {
      return Scaffold(backgroundColor: bg,
          body: const Center(child: CircularProgressIndicator(color: Color(0xFF41C0FF))));
    }
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1F3A), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Negotiations',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF41C0FF)))
          : RefreshIndicator(
              onRefresh: _loadSessions, color: accent,
              child: _sessions.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.handshake_outlined, color: Colors.white24, size: 56),
                      const SizedBox(height: 16),
                      const Text('No negotiations yet',
                          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Once the manager accepts your proposal,\nnegotiation will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                    ]))
                  : ListView.separated(
                      itemCount: _sessions.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                      itemBuilder: (_, i) {
                        final s = _sessions[i];
                        final isActive = s['status'] == 'Active';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isActive ? accent.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            radius: 26,
                            child: Icon(Icons.handshake_outlined,
                                color: isActive ? accent : Colors.grey, size: 22),
                          ),
                          title: Row(children: [
                            Expanded(child: Text(s['rfpTitle'] ?? '—',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                overflow: TextOverflow.ellipsis)),
                            Text(_fmtTime(s['lastTime']),
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                          ]),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SizedBox(height: 3),
                            Text(s['lastMessage'] ?? '',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text('Manager: ${s['managerName']}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10)),
                                child: Text(s['status'] ?? '',
                                    style: TextStyle(
                                        color: isActive ? Colors.orangeAccent : Colors.greenAccent,
                                        fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ]),
                          ]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => AINegotiationScreen(
                              sessionId: s['session_id'].toString(),
                              rfpId: s['rfp_id']?.toString() ?? '',
                              rfpTitle: s['rfpTitle'] ?? '—',
                              contractorName: s['managerName'] ?? '—',
                              selectedCriteria: List<String>.from(s['criteria'] ?? []),
                              proposalId: s['proposalId'] ?? '',
                              isManager: false,
                            ),
                          )).then((_) => _loadSessions()),
                        );
                      },
                    ),
            ),
    );
  }
}