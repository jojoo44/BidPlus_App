// negotiation_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'finalize_contract_screen.dart';

class AINegotiationScreen extends StatefulWidget {
  final String sessionId;
  final String rfpId;
  final String contractorName;
  final List<String> selectedCriteria;
  final String proposalId;
  final String rfpTitle;
  final dynamic budget;
  final bool isManager;

  const AINegotiationScreen({
    super.key,
    required this.sessionId,
    required this.rfpId,
    required this.contractorName,
    required this.selectedCriteria,
    required this.proposalId,
    required this.rfpTitle,
    required this.isManager,
    this.budget,
  });

  @override
  State<AINegotiationScreen> createState() => _AINegotiationScreenState();
}

class _AINegotiationScreenState extends State<AINegotiationScreen> {
  static const Color bg          = Color(0xFF0D1219);
  static const Color cardColor   = Color(0xFF1C242F);
  static const Color primaryBlue = Color(0xFF3395FF);
  static const Color surface     = Color(0xFF0F1B2A);

  final TextEditingController _msgCtrl    = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _rounds = [];
  bool   _isLoading             = true;
  bool   _isSending             = false;
  bool   _isUploadingContract   = false;
  bool   _isGeneratingSuggestion = false;
  bool   _showAISuggestion      = true;
  String _aiSuggestionText      = '';
  String _sessionStatus         = 'Active';

  // ── Contract state ──────────────────────────────
  String? _contractId;
  String? _firstContractUrl;
  String? _firstContractName;
  String? _firstContractUploader; // 'manager' | 'contractor'
  String? _signedContractUrl;
  String? _signedContractName;
  String  _contractStatus      = '';
  bool    _managerFinalized    = false;
  bool    _contractorFinalized = false;

  RealtimeChannel? _channel;

  // ── Helpers ─────────────────────────────────────
  bool get _iHaveUploaded =>
      _firstContractUploader != null &&
      (widget.isManager
          ? _firstContractUploader == 'manager'
          : _firstContractUploader == 'contractor');
  bool get _otherUploaded  => _firstContractUrl != null && !_iHaveUploaded;
  bool get _signedUploaded => _signedContractUrl != null;
  bool get _myFinalized    => widget.isManager ? _managerFinalized : _contractorFinalized;
  bool get _contractActive => _contractStatus == 'Active';

  // ════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Load ────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessionId = int.tryParse(widget.sessionId) ?? widget.sessionId;

      final session = await supabase
          .from('NegoSession').select('status').eq('session_id', sessionId).single();

      final rounds = await supabase
          .from('NegoRounds')
          .select('roundID,sessionID,rfp_id,proposal_id,manager_id,contractor_id,Terms,UpdateTerms,created_at,fileURL')
          .eq('sessionID', sessionId)
          .order('roundID', ascending: true);

      try {
        final c = await supabase
            .from('Contract')
            .select('id,status,manager_finalized,contractor_finalized')
            .eq('paymentID', widget.rfpId)
            .maybeSingle();
        if (c != null) {
          _contractId          = c['id']?.toString();
          _contractStatus      = c['status'] ?? '';
          _managerFinalized    = c['manager_finalized'] == true;
          _contractorFinalized = c['contractor_finalized'] == true;
        }
      } catch (_) {}

      try {
        final d = await supabase
            .from('Document')
            .select('fileURL,fullName,uploadedBy')
            .eq('uploadType', 'Contract')
            .eq('sessionID', widget.sessionId)
            .order('documentID', ascending: true)
            .limit(1)
            .maybeSingle();
        if (d != null) {
          _firstContractUrl      = d['fileURL']?.toString();
          _firstContractName     = d['fullName']?.toString();
          _firstContractUploader = d['uploadedBy']?.toString();
        }
      } catch (_) {}

      try {
        final s = await supabase
            .from('Document')
            .select('fileURL,fullName')
            .eq('uploadType', 'Contract_Signed')
            .eq('sessionID', widget.sessionId)
            .order('documentID', ascending: false)
            .limit(1)
            .maybeSingle();
        if (s != null) {
          _signedContractUrl  = s['fileURL']?.toString();
          _signedContractName = s['fullName']?.toString();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _sessionStatus = session['status'] ?? 'Active';
          _rounds        = List<Map<String, dynamic>>.from(rounds);
          _isLoading     = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Realtime ────────────────────────────────────
  void _subscribeRealtime() {
    _channel = supabase
        .channel('nego_${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public', table: 'NegoRounds',
          callback: (p) {
            final row = p.newRecord;
            if (row['sessionID']?.toString() == widget.sessionId && mounted) {
              setState(() => _rounds.add(row));
              _scrollToBottom();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public', table: 'Contract',
          callback: (p) {
            final row = p.newRecord;
            if (mounted) setState(() {
              _contractStatus      = row['status'] ?? _contractStatus;
              _managerFinalized    = row['manager_finalized'] == true;
              _contractorFinalized = row['contractor_finalized'] == true;
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public', table: 'Document',
          callback: (p) {
            final row = p.newRecord;
            if (row['sessionID']?.toString() != widget.sessionId || !mounted) return;
            final type = row['uploadType']?.toString() ?? '';
            if (type == 'Contract') {
              setState(() {
                _firstContractUrl      = row['fileURL']?.toString();
                _firstContractName     = row['fullName']?.toString();
                _firstContractUploader = row['uploadedBy']?.toString();
              });
            } else if (type == 'Contract_Signed') {
              setState(() {
                _signedContractUrl  = row['fileURL']?.toString();
                _signedContractName = row['fullName']?.toString();
              });
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<String> _resolveSessionId() async {
    String id = widget.sessionId;
    if ((int.tryParse(id) ?? 0) == 0 && widget.rfpId.isNotEmpty) {
      try {
        final s = await supabase.from('NegoSession').select('session_id')
            .eq('rfp_id', int.tryParse(widget.rfpId) ?? 0)
            .order('start_date', ascending: false).limit(1).maybeSingle();
        if (s != null) id = s['session_id'].toString();
      } catch (_) {}
    }
    return id;
  }

  // ── AI Suggestion ────────────────────────────────
  Future<void> _generateAISuggestion() async {
    setState(() { _isGeneratingSuggestion = true; _showAISuggestion = true; _aiSuggestionText = ''; });
    try {
      final history = _rounds.map((r) => '${r['UpdateTerms']}: ${r['Terms']}').join('\n');
      final res = await supabase.functions.invoke('negotiate_suggest', body: {
        'title': widget.rfpTitle, 'budget': widget.budget?.toString() ?? '',
        'history': history, 'criteria': widget.selectedCriteria.join(', '),
        'isManager': widget.isManager,
      });
      if (mounted) setState(() => _aiSuggestionText = res.data['suggestion']?.toString() ?? '');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingSuggestion = false);
    }
  }

  // ── Complete negotiation → extract terms ─────────
  Future<void> _completeNegotiation() async {
    setState(() => _isGeneratingSuggestion = true);
    try {
      final history = _rounds.map((r) => '${r['UpdateTerms']}: ${r['Terms']}').join('\n');
      final res  = await supabase.functions.invoke('negotiate-extract', body: {'history': history});
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => AIContractReviewScreen(
          contractorName: widget.contractorName, proposalId: widget.proposalId,
          finalPrice: data['finalPrice']?.toString() ?? '',
          duration  : data['duration']?.toString()   ?? '',
          terms     : (data['terms'] as List?)?.join('. ') ?? '',
        )));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingSuggestion = false);
    }
  }

  // ── Send message ─────────────────────────────────
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _msgCtrl.clear();
    setState(() => _isSending = true);
    try {
      final sessionId    = await _resolveSessionId();
      final sessionIdInt = int.tryParse(sessionId) ?? 0;
      final userId       = supabase.auth.currentUser?.id;

      final Map<String, dynamic> data = {
        'sessionID'  : sessionIdInt,
        'Terms'      : text.trim(),
        'UpdateTerms': widget.isManager ? 'manager' : 'contractor',
      };
      final rfpIdInt      = widget.rfpId.isNotEmpty      ? int.tryParse(widget.rfpId)      : null;
      final proposalIdInt = widget.proposalId.isNotEmpty ? int.tryParse(widget.proposalId) : null;
      if (rfpIdInt      != null) data['rfp_id']      = rfpIdInt;
      if (proposalIdInt != null) data['proposal_id'] = proposalIdInt;
      if (widget.isManager)  data['manager_id']    = userId;
      if (!widget.isManager) data['contractor_id'] = userId;

      await supabase.from('NegoRounds').insert(data);
      await _notifyOtherParty('New Message',
          '${widget.isManager ? "Manager" : widget.contractorName} sent a message in "${widget.rfpTitle}".');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Send file (chat) ─────────────────────────────
  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf','doc','docx','jpg','jpeg','png'], withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final file = result.files.first;
    setState(() => _isSending = true);
    try {
      final userId    = supabase.auth.currentUser?.id;
      final path      = 'contracts/${widget.sessionId}_${widget.isManager ? "mgr" : "ctr"}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await supabase.storage.from('proposal_attachments').uploadBinary(path, file.bytes!);
      final url       = supabase.storage.from('proposal_attachments').getPublicUrl(path);
      final sessionId = await _resolveSessionId();
      final Map<String, dynamic> data = {
        'sessionID': int.tryParse(sessionId) ?? 0, 'Terms': '📎 ${file.name}',
        'UpdateTerms': widget.isManager ? 'manager' : 'contractor', 'fileURL': url,
      };
      if (widget.isManager)  data['manager_id']    = userId;
      if (!widget.isManager) data['contractor_id'] = userId;
      await supabase.from('NegoRounds').insert(data);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ File sent!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Upload FIRST contract ────────────────────────
  Future<void> _uploadFirstContract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf','doc','docx'], withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final file = result.files.first;
    setState(() => _isUploadingContract = true);
    try {
      final userId       = supabase.auth.currentUser!.id;
      final uploaderRole = widget.isManager ? 'manager' : 'contractor';
      final path         = 'contracts/${widget.sessionId}_${uploaderRole}_original_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await supabase.storage.from('proposal_attachments').uploadBinary(path, file.bytes!);
      final url = supabase.storage.from('proposal_attachments').getPublicUrl(path);

      await supabase.from('Document').insert({
        'fullName': file.name, 'fileURL': url,
        'uploadDate': DateTime.now().toIso8601String().split('T')[0],
        'uploader': userId, 'uploadedBy': uploaderRole,
        'uploadType': 'Contract', 'sessionID': widget.sessionId,
      });

      if (_contractId == null) {
        final row = await supabase.from('Contract').insert({
          'startDate': DateTime.now().toIso8601String().split('T')[0],
          'status': 'Pending_Signature', 'description': widget.rfpTitle,
          'paymentID': int.tryParse(widget.rfpId),
          'manager_finalized': false, 'contractor_finalized': false,
        }).select('id').single();
        _contractId = row['id']?.toString();
      } else {
        await supabase.from('Contract').update({'status': 'Pending_Signature'}).eq('id', _contractId!);
      }

      await _notifyOtherParty('Contract Ready',
          '${widget.isManager ? "Manager" : widget.contractorName} attached a contract for "${widget.rfpTitle}". Please download, sign, and re-upload.');

      if (mounted) setState(() {
        _firstContractUrl = url; _firstContractName = file.name;
        _firstContractUploader = uploaderRole; _contractStatus = 'Pending_Signature';
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Contract sent to the other party!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }

  Future<void> _downloadContract() async {
    if (_firstContractUrl == null) return;
    try {
      final uri = Uri.parse(_firstContractUrl!);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ── Upload SIGNED contract ───────────────────────
  Future<void> _uploadSignedContract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf','doc','docx'], withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final file = result.files.first;
    setState(() => _isUploadingContract = true);
    try {
      final userId       = supabase.auth.currentUser!.id;
      final uploaderRole = widget.isManager ? 'manager' : 'contractor';
      final path         = 'contracts/${widget.sessionId}_${uploaderRole}_signed_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await supabase.storage.from('proposal_attachments').uploadBinary(path, file.bytes!);
      final url = supabase.storage.from('proposal_attachments').getPublicUrl(path);

      await supabase.from('Document').insert({
        'fullName': file.name, 'fileURL': url,
        'uploadDate': DateTime.now().toIso8601String().split('T')[0],
        'uploader': userId, 'uploadedBy': uploaderRole,
        'uploadType': 'Contract_Signed', 'sessionID': widget.sessionId,
      });

      await _notifyOtherParty('Contract Signed',
          '${widget.isManager ? "Manager" : widget.contractorName} uploaded the signed contract. Please finalize.');

      if (mounted) setState(() { _signedContractUrl = url; _signedContractName = file.name; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Signed contract uploaded!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }

  // ── Finalize (both parties) ──────────────────────
  Future<void> _finalizeContract() async {
    if (_contractId == null) return;
    setState(() => _isUploadingContract = true);
    try {
      final field = widget.isManager ? 'manager_finalized' : 'contractor_finalized';
      await supabase.from('Contract').update({field: true}).eq('id', _contractId!);
      if (mounted) setState(() {
        if (widget.isManager)  _managerFinalized    = true;
        if (!widget.isManager) _contractorFinalized = true;
      });

      final c = await supabase.from('Contract')
          .select('manager_finalized,contractor_finalized').eq('id', _contractId!).single();
      final both = c['manager_finalized'] == true && c['contractor_finalized'] == true;

      if (both) {
        await supabase.from('Contract').update({'status': 'Active'}).eq('id', _contractId!);
        final sid = int.tryParse(widget.sessionId) ?? widget.sessionId;
        await supabase.from('NegoSession').update({
          'status': 'Completed', 'end_date': DateTime.now().toIso8601String(),
        }).eq('session_id', sid);
        await _notifyOtherParty('Contract Active',
            'The contract for "${widget.rfpTitle}" is finalized by both parties. Project is now active!');
        if (mounted) setState(() {
          _contractStatus = 'Active'; _sessionStatus = 'Completed';
          _managerFinalized = true; _contractorFinalized = true;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Contract finalized! Project is now active.'), backgroundColor: Colors.green));
      } else {
        await _notifyOtherParty('Finalize Contract',
            '${widget.isManager ? "Manager" : widget.contractorName} confirmed their part. Please finalize the contract.');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Waiting for the other party to confirm.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }

  Future<void> _notifyOtherParty(String type, String message) async {
    try {
      final sid     = int.tryParse(widget.sessionId) ?? 0;
      final session = await supabase.from('NegoSession').select('rfp_id,contractor_id').eq('session_id', sid).single();
      final rfpId   = session['rfp_id'];
      String? recipientId;
      if (widget.isManager) {
        recipientId = session['contractor_id']?.toString();
        if (recipientId == null && rfpId != null) {
          final p = await supabase.from('proposals').select('submitterUserId')
              .eq('RFP', rfpId).eq('status', 'Accepted').maybeSingle();
          recipientId = p?['submitterUserId']?.toString();
        }
      } else {
        if (rfpId != null) {
          final rfp = await supabase.from('RFP').select('creatorUser').eq('rfpID', rfpId).single();
          recipientId = rfp['creatorUser']?.toString();
        }
      }
      if (recipientId != null) {
        await supabase.from('Notification').insert({
          'userID': recipientId, 'type': type, 'message': message,
          'readStatus': false, 'timeStamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  // ════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isCompleted = _sessionStatus == 'Completed';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.rfpTitle,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
          Text('${widget.contractorName} • $_sessionStatus',
              style: TextStyle(color: isCompleted ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11)),
        ]),
      ),
      body: Column(children: [

        // ── Criteria chips ─────────────────────────
        if (widget.selectedCriteria.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: surface,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Negotiable Criteria', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6,
                children: widget.selectedCriteria.map((c) => Chip(
                  label: Text(c, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: cardColor,
                  side: const BorderSide(color: primaryBlue, width: 0.5),
                  padding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
                )).toList()),
            ]),
          ),

        // ── AI Suggestion ──────────────────────────
        if (_showAISuggestion && !isCompleted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GestureDetector(
              onTap: () {
                if (_aiSuggestionText.isNotEmpty) {
                  _msgCtrl.text = _aiSuggestionText;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ Suggestion added to message field'),
                    backgroundColor: Colors.green, duration: Duration(seconds: 1)));
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryBlue.withOpacity(0.3))),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('AI SUGGESTION', style: TextStyle(color: primaryBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      if (_aiSuggestionText.isNotEmpty)
                        const Text('• tap to use', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ]),
                    const SizedBox(height: 6),
                    _isGeneratingSuggestion
                        ? const Row(children: [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Generating...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          ])
                        : Text(
                            _aiSuggestionText.isNotEmpty ? _aiSuggestionText
                                : (widget.budget != null
                                    ? 'Suggest offering ${((widget.budget as num) * 0.95).toStringAsFixed(0)} SAR with 50% upfront.'
                                    : 'Press "Generate Suggestions" to get an AI recommendation.'),
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ])),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                      onPressed: () => setState(() => _showAISuggestion = false)),
                ]),
              ),
            ),
          ),

        // ── Generate Suggestions ───────────────────
        if (!isCompleted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SizedBox(width: double.infinity, height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _isGeneratingSuggestion ? null : _generateAISuggestion,
                icon: _isGeneratingSuggestion
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                label: const Text('Generate Suggestions',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),

        // ── Contract section ───────────────────────
        _buildContractSection(),

        // ── Active banner ──────────────────────────
        if (_contractActive)
          _buildBanner(Icons.check_circle, Colors.greenAccent, '🎉 Contract active! Project is now running.'),

        // ── Messages ──────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: primaryBlue))
              : _rounds.isEmpty
                  ? Center(child: Text(
                      widget.isManager ? 'Start the negotiation' : 'Waiting for the manager to start...',
                      style: TextStyle(color: Colors.white.withOpacity(0.4))))
                  : ListView.builder(
                      controller: _scrollCtrl, padding: const EdgeInsets.all(16),
                      itemCount: _rounds.length,
                      itemBuilder: (_, i) {
                        final r    = _rounds[i];
                        final isMe = widget.isManager ? r['UpdateTerms'] == 'manager' : r['UpdateTerms'] == 'contractor';
                        return _ChatBubble(
                          text: r['Terms']?.toString() ?? '', isMe: isMe,
                          time: _fmtTime(r['created_at']),
                          label: isMe ? 'You' : widget.contractorName,
                          fileURL: r['fileURL']?.toString(),
                        );
                      }),
        ),

        // ── Input bar ─────────────────────────────
        if (!isCompleted && !_contractActive)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16), color: surface,
            child: Row(children: [
              CircleAvatar(backgroundColor: cardColor,
                child: IconButton(icon: const Icon(Icons.attach_file, color: Colors.white54, size: 18),
                    onPressed: _isSending ? null : _sendFile)),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _msgCtrl, style: const TextStyle(color: Colors.white),
                maxLines: null, textInputAction: TextInputAction.send, onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Enter your offer...', hintStyle: const TextStyle(color: Colors.grey),
                  filled: true, fillColor: cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              )),
              const SizedBox(width: 8),
              CircleAvatar(backgroundColor: primaryBlue,
                child: _isSending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: () => _sendMessage(_msgCtrl.text))),
            ]),
          ),


      ]),
    );
  }

  // ════════════════════════════════════════════════
  // CONTRACT SECTION
  // ════════════════════════════════════════════════
  Widget _buildContractSection() {
    // State 1 — no contract yet
    if (_firstContractUrl == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.upload_file, color: Colors.white54, size: 18), SizedBox(width: 8),
              Text('Attach Contract Document', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            const Text('Either party can attach the initial contract file.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.withOpacity(0.15), foregroundColor: Colors.greenAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.greenAccent, width: 0.5))),
                onPressed: _isUploadingContract ? null : _uploadFirstContract,
                icon: _isUploadingContract
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 2))
                    : const Icon(Icons.attach_file, size: 18),
                label: const Text('Attach Contract File', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      );
    }

    // State 2 — I uploaded, waiting for other party
    if (_iHaveUploaded && !_signedUploaded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _fileBox(_firstContractName ?? 'Contract', Colors.amber),
            const SizedBox(height: 10),
            const Row(children: [
              Icon(Icons.hourglass_top, color: Colors.amber, size: 15), SizedBox(width: 6),
              Expanded(child: Text('Waiting for the other party to sign and re-upload.',
                  style: TextStyle(color: Colors.amber, fontSize: 12))),
            ]),
          ]),
        ),
      );
    }

    // State 3 — other uploaded, I need to download + sign + re-upload
    if (_otherUploaded && !_signedUploaded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.description_outlined, color: Colors.lightBlueAccent, size: 18), SizedBox(width: 8),
              Text('Contract attached — review & sign',
                  style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            // Saved file box with download button
            GestureDetector(
              onTap: _downloadContract,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.lightBlueAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.25))),
                child: Row(children: [
                  const Icon(Icons.insert_drive_file, color: Colors.lightBlueAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_firstContractName ?? 'Contract',
                      style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.download, color: Colors.lightBlueAccent, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Sign the document then upload the signed copy:',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF41C0FF), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _isUploadingContract ? null : _uploadSignedContract,
                icon: _isUploadingContract
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload Signed Copy', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      );
    }

    // State 4 — signed uploaded, both finalize
    if (_signedUploaded && !_contractActive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Original
            if (_firstContractUrl != null) ...[
              const Text('Original Contract', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              GestureDetector(onTap: _downloadContract, child: _fileBox(_firstContractName ?? 'Contract', Colors.white54, showDownload: true)),
              const SizedBox(height: 10),
            ],
            // Signed
            const Text('Signed Copy', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                if (_signedContractUrl == null) return;
                final uri = Uri.parse(_signedContractUrl!);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: _fileBox(_signedContractName ?? 'Signed Contract', Colors.greenAccent, showDownload: true),
            ),
            const Divider(color: Colors.white12, height: 20),
            // Who finalized
            Row(children: [
              _finalizeChip('Manager',    _managerFinalized),
              const SizedBox(width: 8),
              _finalizeChip('Contractor', _contractorFinalized),
            ]),
            const SizedBox(height: 10),
            if (!_myFinalized)
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _isUploadingContract ? null : _finalizeContract,
                  icon: _isUploadingContract
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock, size: 18, color: Colors.white),
                  label: const Text('Confirm & Finalize Contract',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ))
            else
              const Center(child: Text('Waiting for the other party to confirm...',
                  style: TextStyle(color: Colors.white54, fontSize: 13))),
          ]),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _fileBox(String name, Color color, {bool showDownload = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Row(children: [
      Icon(Icons.insert_drive_file, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(name, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
      if (showDownload) Icon(Icons.download, color: color, size: 16),
    ]),
  );

  Widget _statusChip(String label, bool done) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: done ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: done ? Colors.greenAccent.withOpacity(0.5) : Colors.white24)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(done ? Icons.check : Icons.hourglass_empty, size: 12,
          color: done ? Colors.greenAccent : Colors.white38),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: done ? Colors.greenAccent : Colors.white38, fontSize: 11)),
    ]),
  );

  Widget _finalizeChip(String label, bool done) => _statusChip(label, done);

  Widget _buildBanner(IconData icon, Color color, String text) => Container(
    margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Row(children: [
      Icon(icon, color: color, size: 18), const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}

// ════════════════════════════════════════════════════
// Chat Bubble
// ════════════════════════════════════════════════════
class _ChatBubble extends StatelessWidget {
  final String text, time, label;
  final bool isMe;
  final String? fileURL;
  const _ChatBubble({required this.text, required this.isMe, required this.time, required this.label, this.fileURL});

  @override
  Widget build(BuildContext context) {
    final isFile = fileURL != null && fileURL!.isNotEmpty;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF3395FF) : const Color(0xFF1C242F),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16))),
            child: isFile
                ? GestureDetector(
                    onTap: () async {
                      try {
                        final uri = Uri.parse(fileURL!);
                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.description, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13,
                          decoration: TextDecoration.underline))),
                    ]))
                : Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          ),
          const SizedBox(height: 3),
          Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// AIContractReviewScreen
// ════════════════════════════════════════════════════
class AIContractReviewScreen extends StatefulWidget {
  final String contractorName, proposalId, finalPrice, duration, terms;
  const AIContractReviewScreen({super.key, required this.contractorName, required this.proposalId,
      this.finalPrice = '', this.duration = '', this.terms = ''});
  @override
  State<AIContractReviewScreen> createState() => _AIContractReviewScreenState();
}

class _AIContractReviewScreenState extends State<AIContractReviewScreen> {
  late final TextEditingController _priceCtrl, _durationCtrl, _termsCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl    = TextEditingController(text: widget.finalPrice);
    _durationCtrl = TextEditingController(text: widget.duration);
    _termsCtrl    = TextEditingController(text: widget.terms);
  }

  @override
  void dispose() { _priceCtrl.dispose(); _durationCtrl.dispose(); _termsCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
          title: const Text('Review Contract Terms', style: TextStyle(color: Colors.white))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Review and confirm the terms extracted by AI from the negotiation history.',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 30),
          _field('Final Agreed Price (SAR)', _priceCtrl, Icons.monetization_on),
          const SizedBox(height: 20),
          _field('Project Duration', _durationCtrl, Icons.timer),
          const SizedBox(height: 20),
          _field('Contract Clauses', _termsCtrl, Icons.article, maxLines: 5),
          const SizedBox(height: 40),
          SizedBox(width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3395FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => FinalizeContractScreen(
                  contractTitle: 'Final Project Contract', contractId: widget.proposalId,
                  managerName: 'Project Manager', contractorName: widget.contractorName,
                  effectiveDate: DateTime.now().toString().split(' ')[0]))),
              child: const Text('Finalize Contract', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF3395FF), fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(controller: ctrl, maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey, size: 20),
              filled: true, fillColor: const Color(0xFF1C242F),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3395FF))))),
      ]);
}