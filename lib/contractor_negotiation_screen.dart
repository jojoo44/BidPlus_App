// contractor_negotiation_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';

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
  static const Color surface = Color(0xFF1A2C47);
  static const Color accent = Color(0xFF41C0FF);

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _rounds = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingSignature = false;
  String _sessionStatus = 'Active';
  String? _contractorId;
  String? _activeSessionId;
  String? _contractId;
  String _contractStatus = '';
  String _rfpTitle = '—';
  String _managerName = '—';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _contractorId = supabase.auth.currentUser?.id;
    _activeSessionId = widget.sessionId;
    _loadSession();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    try {
      if (_activeSessionId == null && _contractorId != null) {
        final proposals = await supabase
            .from('proposals')
            .select('RFP')
            .eq('submitterUserId', _contractorId!)
            .inFilter('status', ['Accepted', 'Submitted']);

        final rfpIds = (proposals as List)
            .map((p) => p['RFP'])
            .where((id) => id != null)
            .toList();

        if (rfpIds.isNotEmpty) {
          final session = await supabase
              .from('NegoSession')
              .select()
              .inFilter('rfp_id', rfpIds)
              .order('start_date', ascending: false)
              .limit(1)
              .maybeSingle();

          if (session != null) {
            _activeSessionId = session['session_id'].toString();
            _sessionStatus = session['status'] ?? 'Active';
          }
        }
      }

      if (_activeSessionId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final sessionId =
          int.tryParse(_activeSessionId!) ?? _activeSessionId!;

      final sessionData = await supabase
          .from('NegoSession')
          .select()
          .eq('session_id', sessionId)
          .single();

      _sessionStatus = sessionData['status'] ?? 'Active';
      final rfpId = sessionData['rfp_id'];

      if (rfpId != null) {
        try {
          final rfp = await supabase
              .from('RFP')
              .select('title, creatorUser')
              .eq('rfpID', rfpId)
              .single();
          _rfpTitle = rfp['title'] ?? '—';

          final manager = await supabase
              .from('User')
              .select('username')
              .eq('id', rfp['creatorUser'])
              .single();
          _managerName = manager['username'] ?? '—';
        } catch (_) {}
      }

      // جيب العقد إذا موجود
      if (rfpId != null) {
        try {
          final contract = await supabase
              .from('Contract')
              .select('contractID, status')
              .eq('paymentID', rfpId)
              .maybeSingle();

          if (contract != null) {
            _contractId = contract['contractID']?.toString();
            _contractStatus = contract['status'] ?? '';
          }
        } catch (_) {}
      }

      final data = await supabase
          .from('NegoRounds')
          .select()
          .eq('sessionID', sessionId)
          .order('roundID', ascending: true);

      if (mounted) {
        setState(() {
          _rounds = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _scrollToBottom();
        _subscribeRealtime();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime() {
    if (_activeSessionId == null) return;
    _channel = supabase
        .channel('nego_ctr_$_activeSessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'NegoRounds',
          callback: (payload) {
            final newRow = payload.newRecord;
            final rowSession = newRow['sessionID']?.toString();
            if (rowSession == _activeSessionId && mounted) {
              setState(() => _rounds.add(newRow));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _activeSessionId == null) return;
    _msgCtrl.clear();
    setState(() => _isSending = true);
    try {
      await supabase.from('NegoRounds').insert({
        'sessionID': int.tryParse(_activeSessionId!) ?? _activeSessionId,
        'Terms': text.trim(),
        'UpdateTerms': 'contractor',
        'RoundTerms': text.trim(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── رفع النسخة الموقعة من الكونتراكتر
  Future<void> _uploadSignedContract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isUploadingSignature = true);
    try {
      final userId = _contractorId!;
      final path =
          'contracts/${_activeSessionId}_contractor_${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      await supabase.storage
          .from('proposal_attachments')
          .uploadBinary(path, file.bytes!);

      final url = supabase.storage
          .from('proposal_attachments')
          .getPublicUrl(path);

      // احفظ الـ Document
      await supabase.from('Document').insert({
        'fullName': file.name,
        'fileURL': url,
        'uploadDate': DateTime.now().toIso8601String().split('T')[0],
        'uploader': userId,
        'uploadType': 'Contract_Signed',
      });

      // حدّث Contract status → Active (مقفول)
      if (_contractId != null) {
        await supabase
            .from('Contract')
            .update({'status': 'Active'})
            .eq('contractID', _contractId!);
      }

      if (mounted) {
        setState(() => _contractStatus = 'Active');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Signed contract uploaded! Project is now active.'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload لتحديث Current Projects
        await _loadSession();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingSignature = false);
    }
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _sessionStatus == 'Completed';
    final contractReady =
        _contractStatus == 'Pending_Contractor_Signature';
    final contractActive = _contractStatus == 'Active';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _rfpTitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$_managerName • $_sessionStatus',
              style: TextStyle(
                color:
                    isCompleted ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accent))
          : _activeSessionId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.handshake_outlined,
                      color: Colors.white24, size: 56),
                  const SizedBox(height: 16),
                  const Text('No active negotiation',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'Once the manager accepts your proposal,\nnegotiation will start here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  color: surface,
                  child: Row(
                    children: [
                      const Icon(Icons.work_outline,
                          color: Colors.white54, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_rfpTitle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _sessionStatus,
                          style: TextStyle(
                            color: isCompleted
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contract upload banner
                if (contractReady)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.description_outlined,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Contract ready for your signature',
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isUploadingSignature
                                ? null
                                : _uploadSignedContract,
                            icon: _isUploadingSignature
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.upload_file, size: 18),
                            label: const Text('Upload Signed Contract',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (contractActive)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '✅ Contract signed! Project is now active in your dashboard.',
                            style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Messages
                Expanded(
                  child: _rounds.isEmpty
                      ? Center(
                          child: Text(
                            'Waiting for the manager to start...',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4)),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: _rounds.length,
                          itemBuilder: (_, i) {
                            final round = _rounds[i];
                            final isMe =
                                round['UpdateTerms'] == 'contractor';
                            final text = round['Terms'] ??
                                round['RoundTerms'] ?? '';
                            final time = _fmtTime(round['created_at']);
                            return _ChatBubble(
                              text: text,
                              isMe: isMe,
                              time: time,
                              label: isMe ? 'You' : _managerName,
                            );
                          },
                        ),
                ),

                // Input
                if (!isCompleted)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    color: surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgCtrl,
                            style: const TextStyle(color: Colors.white),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _sendMessage,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.4)),
                              filled: true,
                              fillColor: cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: accent,
                          child: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.send,
                                      color: Colors.white, size: 18),
                                  onPressed: () =>
                                      _sendMessage(_msgCtrl.text),
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final String label;

  const _ChatBubble({
    required this.text,
    required this.isMe,
    required this.time,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF41C0FF)
                    : const Color(0xFF1A2C47),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.4)),
            ),
            const SizedBox(height: 3),
            Text(time,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}