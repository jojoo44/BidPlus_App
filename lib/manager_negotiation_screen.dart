// manager_negotiation_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';

class ManagerNegotiationScreen extends StatefulWidget {
  final String sessionId;
  final String rfpTitle;
  final String contractorName;
  final dynamic budget;

  const ManagerNegotiationScreen({
    super.key,
    required this.sessionId,
    required this.rfpTitle,
    required this.contractorName,
    this.budget,
  });

  @override
  State<ManagerNegotiationScreen> createState() => _ManagerNegotiationScreenState();
}

class _ManagerNegotiationScreenState extends State<ManagerNegotiationScreen> {
  static const Color bg = Color(0xFF0A1628);
  static const Color cardColor = Color(0xFF0F1F3A);
  static const Color surface = Color(0xFF1A2C47);
  static const Color accent = Color(0xFF2188FF);

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _rounds = [];
  bool _isLoading = true, _isSending = false, _isUploadingContract = false;
  String _sessionStatus = 'Active';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadRounds();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRounds() async {
    try {
      final sessionId = int.tryParse(widget.sessionId) ?? widget.sessionId;
      final session = await supabase.from('NegoSession')
          .select('status').eq('session_id', sessionId).single();
      final data = await supabase.from('NegoRounds').select()
          .eq('sessionID', sessionId).order('roundID', ascending: true);
      if (mounted) {
        setState(() {
          _sessionStatus = session['status'] ?? 'Active';
          _rounds = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = supabase.channel('nego_mgr_${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert, schema: 'public', table: 'NegoRounds',
          callback: (payload) {
            final newRow = payload.newRecord;
            if (newRow['sessionID']?.toString() == widget.sessionId && mounted) {
              setState(() => _rounds.add(newRow));
              _scrollToBottom();
            }
          },
        ).subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _msgCtrl.clear();
    setState(() => _isSending = true);
    try {
      await supabase.from('NegoRounds').insert({
        'sessionID': int.tryParse(widget.sessionId) ?? widget.sessionId,
        'Terms': text.trim(),
        'UpdateTerms': 'manager',
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _uploadContract() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _isUploadingContract = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final path = 'contracts/${widget.sessionId}_mgr_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await supabase.storage.from('proposal_attachments').uploadBinary(path, file.bytes!);
      final url = supabase.storage.from('proposal_attachments').getPublicUrl(path);
      final sessionId = int.tryParse(widget.sessionId) ?? widget.sessionId;
      final session = await supabase.from('NegoSession')
          .select('rfp_id').eq('session_id', sessionId).single();
      final rfpId = session['rfp_id'];
      final proposal = await supabase.from('proposals')
          .select('submitterUserId').eq('RFP', rfpId).eq('status', 'Accepted').maybeSingle();
      final docResult = await supabase.from('Document').insert({
        'fullName': file.name, 'fileURL': url,
        'uploadDate': DateTime.now().toIso8601String().split('T')[0],
        'uploader': userId, 'uploadType': 'Contract',
      }).select('documentID').single();
      await supabase.from('Contract').insert({
        'contractID': 'CNT-${DateTime.now().millisecondsSinceEpoch}',
        'startDate': DateTime.now().toIso8601String().split('T')[0],
        'status': 'Pending_Contractor_Signature',
        'description': widget.rfpTitle, 'paymentID': rfpId,
        'documentID': docResult['documentID'],
      });
      await supabase.from('NegoSession').update({
        'status': 'Completed', 'end_date': DateTime.now().toIso8601String(),
      }).eq('session_id', sessionId);
      final contractorId = proposal?['submitterUserId'];
      if (contractorId != null) {
        await supabase.from('Notification').insert({
          'userID': contractorId, 'type': 'Contract Ready',
          'message': 'Contract for "${widget.rfpTitle}" is ready. Please sign and upload.',
          'readStatus': false, 'timeStamp': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) {
        setState(() => _sessionStatus = 'Completed');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Contract uploaded & sent!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
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
    final isCompleted = _sessionStatus == 'Completed';
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardColor, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.rfpTitle,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
          Text('${widget.contractorName} • $_sessionStatus',
              style: TextStyle(color: isCompleted ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11)),
        ]),
        actions: [
          if (!isCompleted)
            TextButton.icon(
              onPressed: _isUploadingContract ? null : _uploadContract,
              icon: _isUploadingContract
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 2))
                  : const Icon(Icons.upload_file, color: Colors.greenAccent, size: 18),
              label: const Text('Upload Contract',
                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: surface,
          child: Row(children: [
            const Icon(Icons.work_outline, color: Colors.white54, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(widget.rfpTitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
            if (widget.budget != null)
              Text('${widget.budget} SAR', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        if (isCompleted)
          Container(
            margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: const Row(children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Contract uploaded — waiting for contractor signature',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: accent))
              : _rounds.isEmpty
              ? Center(child: Text('Start the negotiation',
                  style: TextStyle(color: Colors.white.withOpacity(0.4))))
              : ListView.builder(
                  controller: _scrollCtrl, padding: const EdgeInsets.all(16),
                  itemCount: _rounds.length,
                  itemBuilder: (_, i) {
                    final round = _rounds[i];
                    final isMe = round['UpdateTerms'] == 'manager';
                    return _ChatBubble(
                      text: round['Terms']?.toString() ?? '',
                      isMe: isMe, time: _fmtTime(round['created_at']),
                      label: isMe ? 'You' : widget.contractorName,
                    );
                  }),
        ),
        if (!isCompleted)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16), color: surface,
            child: Row(children: [
              Expanded(child: TextField(
                controller: _msgCtrl, style: const TextStyle(color: Colors.white),
                maxLines: null, textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Type a message...', hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true, fillColor: cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              )),
              const SizedBox(width: 8),
              CircleAvatar(backgroundColor: accent,
                child: _isSending
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: () => _sendMessage(_msgCtrl.text)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: Colors.white54, size: 14), const SizedBox(width: 5),
    Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
  ]);
}

class _ChatBubble extends StatelessWidget {
  final String text, time, label;
  final bool isMe;
  const _ChatBubble({required this.text, required this.isMe, required this.time, required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF2188FF) : const Color(0xFF1A2C47),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
            ),
            const SizedBox(height: 3),
            Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}