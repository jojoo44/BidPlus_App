// negotiation_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
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
  final bool isManager; // true = مدير، false = كونتراكتر

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
  static const Color bg = Color(0xFF0D1219);
  static const Color cardColor = Color(0xFF1C242F);
  static const Color primaryBlue = Color(0xFF3395FF);
  static const Color surface = Color(0xFF0F1B2A);

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _rounds = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingContract = false;
  bool _showAISuggestion = true;
  String _sessionStatus = 'Active';
  String? _contractId;
  String _contractStatus = '';
  RealtimeChannel? _channel;

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessionId = int.tryParse(widget.sessionId) ?? widget.sessionId;

      final session = await supabase
          .from('NegoSession')
          .select('status')
          .eq('session_id', sessionId)
          .single();

      final data = await supabase
          .from('NegoRounds')
          .select('roundID, sessionID, rfp_id, proposal_id, manager_id, contractor_id, Terms, UpdateTerms, created_at')
          .eq('sessionID', sessionId)
          .order('roundID', ascending: true);

      // جيب العقد
      try {
        final contract = await supabase
            .from('Contract')
            .select('contractID, status')
            .eq('paymentID', widget.rfpId)
            .maybeSingle();
        if (contract != null) {
          _contractId = contract['contractID']?.toString();
          _contractStatus = contract['status'] ?? '';
        }
      } catch (_) {}

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
    _channel = supabase
        .channel('ai_nego_${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'NegoRounds',
          callback: (payload) {
            final newRow = payload.newRecord;
            final rowSession = newRow['sessionID']?.toString();
            if (rowSession == widget.sessionId && mounted) {
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
    if (text.trim().isEmpty) return;
    _msgCtrl.clear();
    setState(() => _isSending = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      final sessionIdInt = int.tryParse(widget.sessionId) ?? 0;
      final rfpIdInt = widget.rfpId.isNotEmpty ? int.tryParse(widget.rfpId) : null;
      final proposalIdInt = widget.proposalId.isNotEmpty ? int.tryParse(widget.proposalId) : null;

      final Map<String, dynamic> data = {
        'sessionID': sessionIdInt,
        'Terms': text.trim(),
        'UpdateTerms': widget.isManager ? 'manager' : 'contractor',
      };
      if (rfpIdInt != null) data['rfp_id'] = rfpIdInt;
      if (proposalIdInt != null) data['proposal_id'] = proposalIdInt;
      if (widget.isManager) data['manager_id'] = userId;
      if (!widget.isManager) data['contractor_id'] = userId;

      await supabase.from('NegoRounds').insert(data);

      // أرسل إشعار للطرف الآخر
      try {
        final sessionId = int.tryParse(widget.sessionId) ?? 0;
        final session = await supabase
            .from('NegoSession')
            .select('rfp_id, contractor_id')
            .eq('session_id', sessionId)
            .single();

        final rfpId = session['rfp_id'];
        String? recipientId;

        if (widget.isManager) {
          // أرسل للكونتراكتر
          recipientId = session['contractor_id']?.toString();
          if (recipientId == null && rfpId != null) {
            final proposal = await supabase
                .from('proposals')
                .select('submitterUserId')
                .eq('RFP', rfpId)
                .eq('status', 'Accepted')
                .maybeSingle();
            recipientId = proposal?['submitterUserId']?.toString();
          }
        } else {
          // أرسل للمدير
          if (rfpId != null) {
            final rfp = await supabase
                .from('RFP')
                .select('creatorUser')
                .eq('rfpID', rfpId)
                .single();
            recipientId = rfp['creatorUser']?.toString();
          }
        }

        if (recipientId != null) {
          await supabase.from('Notification').insert({
            'userID':     recipientId,
            'type':       'New Message',
            'message':    '${widget.isManager ? "Manager" : widget.contractorName} sent a message in "${widget.rfpTitle}" negotiation.',
            'readStatus': false,
            'timeStamp':  DateTime.now().toIso8601String(),
          });
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── رفع العقد (للمدير فقط)
  Future<void> _uploadContract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isUploadingContract = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final path =
          'contracts/${widget.sessionId}_mgr_${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      await supabase.storage
          .from('proposal_attachments')
          .uploadBinary(path, file.bytes!);

      final url = supabase.storage
          .from('proposal_attachments')
          .getPublicUrl(path);

      final docResult = await supabase
          .from('Document')
          .insert({
            'fullName': file.name,
            'fileURL': url,
            'uploadDate': DateTime.now().toIso8601String().split('T')[0],
            'uploader': userId,
            'uploadType': 'Contract',
          })
          .select('documentID')
          .single();

      await supabase.from('Contract').insert({
        'contractID': 'CNT-${DateTime.now().millisecondsSinceEpoch}',
        'startDate': DateTime.now().toIso8601String().split('T')[0],
        'status': 'Pending_Contractor_Signature',
        'description': widget.rfpTitle,
        'paymentID': int.tryParse(widget.rfpId),
        'documentID': docResult['documentID'],
      });

      final sessionId = int.tryParse(widget.sessionId) ?? widget.sessionId;
      await supabase.from('NegoSession').update({
        'status': 'Completed',
        'end_date': DateTime.now().toIso8601String(),
      }).eq('session_id', sessionId);

      // إشعار للكونتراكتر
      final proposal = await supabase
          .from('proposals')
          .select('submitterUserId')
          .eq('RFP', widget.rfpId)
          .eq('status', 'Accepted')
          .maybeSingle();

      final contractorId = proposal?['submitterUserId'];
      if (contractorId != null) {
        await supabase.from('Notification').insert({
          'userID': contractorId,
          'type': 'Contract Ready',
          'message':
              'Contract for "${widget.rfpTitle}" is ready. Please sign and upload.',
          'readStatus': false,
          'timeStamp': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        setState(() {
          _sessionStatus = 'Completed';
          _contractStatus = 'Pending_Contractor_Signature';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Contract uploaded & sent to contractor!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }

  // ── رفع العقد الموقع (للكونتراكتر فقط)
  Future<void> _uploadSignedContract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isUploadingContract = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final path =
          'contracts/${widget.sessionId}_ctr_${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      await supabase.storage
          .from('proposal_attachments')
          .uploadBinary(path, file.bytes!);

      final url = supabase.storage
          .from('proposal_attachments')
          .getPublicUrl(path);

      await supabase.from('Document').insert({
        'fullName': file.name,
        'fileURL': url,
        'uploadDate': DateTime.now().toIso8601String().split('T')[0],
        'uploader': userId,
        'uploadType': 'Contract_Signed',
      });

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
            content: Text('✅ Signed! Project is now active.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _sessionStatus == 'Completed';
    final contractReady = _contractStatus == 'Pending_Contractor_Signature';
    final contractActive = _contractStatus == 'Active';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.rfpTitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.contractorName} • $_sessionStatus',
              style: TextStyle(
                color: isCompleted ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          // زر رفع العقد للمدير فقط
          if (widget.isManager && !isCompleted)
            TextButton.icon(
              onPressed: _isUploadingContract ? null : _uploadContract,
              icon: _isUploadingContract
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.greenAccent, strokeWidth: 2))
                  : const Icon(Icons.upload_file,
                      color: Colors.greenAccent, size: 18),
              label: const Text('Upload Contract',
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Criteria chips
          if (widget.selectedCriteria.isNotEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Negotiable Criteria',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.selectedCriteria
                        .map((c) => Chip(
                              label: Text(c,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11)),
                              backgroundColor: cardColor,
                              side: const BorderSide(
                                  color: primaryBlue, width: 0.5),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

          // AI Suggestion card
          if (_showAISuggestion && !isCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: primaryBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AI SUGGESTION',
                              style: TextStyle(
                                  color: primaryBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            widget.budget != null
                                ? 'Suggest offering ${((widget.budget as num) * 0.95).toStringAsFixed(0)} SAR with 50% upfront.'
                                : 'Start with your best offer and justify with your experience.',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white38, size: 18),
                      onPressed: () =>
                          setState(() => _showAISuggestion = false),
                    ),
                  ],
                ),
              ),
            ),

          // Generate Suggestions button
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () =>
                      setState(() => _showAISuggestion = true),
                  icon: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 16),
                  label: const Text('Generate Suggestions',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
            ),

          // Contract banners
          if (isCompleted && widget.isManager)
            _buildBanner(
              Icons.check_circle,
              Colors.greenAccent,
              'Contract uploaded — waiting for contractor signature',
            ),

          if (contractReady && !widget.isManager)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.description_outlined,
                          color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text('Contract ready for your signature',
                          style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF41C0FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isUploadingContract
                            ? null
                            : _uploadSignedContract,
                        icon: _isUploadingContract
                            ? const SizedBox(
                                width: 16, height: 16,
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
            ),

          if (contractActive && !widget.isManager)
            _buildBanner(
              Icons.check_circle,
              Colors.greenAccent,
              '✅ Contract signed! Project is active in your dashboard.',
            ),

          // Messages
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryBlue))
                : _rounds.isEmpty
                ? Center(
                    child: Text(
                      widget.isManager
                          ? 'Start the negotiation'
                          : 'Waiting for the manager to start...',
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
                      final isMe = widget.isManager
                          ? round['UpdateTerms'] == 'manager'
                          : round['UpdateTerms'] == 'contractor';
                      final text = round['Terms'] ?? '';
                      return _ChatBubble(
                        text: text.toString(),
                        isMe: isMe,
                        time: _fmtTime(round['created_at']),
                        label: isMe ? 'You' : widget.contractorName,
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
                        hintText: 'Enter your offer...',
                        hintStyle: const TextStyle(color: Colors.grey),
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
                    backgroundColor: primaryBlue,
                    child: _isSending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.send,
                                color: Colors.white, size: 18),
                            onPressed: () => _sendMessage(_msgCtrl.text),
                          ),
                  ),
                ],
              ),
            ),

          // زر Negotiation Completed للمدير فقط
          if (widget.isManager && !isCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AIContractReviewScreen(
                        contractorName: widget.contractorName,
                        proposalId: widget.proposalId,
                      ),
                    ),
                  ),
                  child: const Text('Negotiation Completed',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBanner(IconData icon, Color color, String text) =>
      Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

// ── Chat Bubble
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
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
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
                    ? const Color(0xFF3395FF)
                    : const Color(0xFF1C242F),
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

// ── AI Contract Review Screen (بدون تغيير)
class AIContractReviewScreen extends StatefulWidget {
  final String contractorName;
  final String proposalId;

  const AIContractReviewScreen({
    super.key,
    required this.contractorName,
    required this.proposalId,
  });

  @override
  State<AIContractReviewScreen> createState() =>
      _AIContractReviewScreenState();
}

class _AIContractReviewScreenState extends State<AIContractReviewScreen> {
  final TextEditingController _priceController =
      TextEditingController(text: '48,500');
  final TextEditingController _durationController =
      TextEditingController(text: '60 Days');
  final TextEditingController _termsController = TextEditingController(
      text:
          '3% discount applied. 50% upfront payment. Maintenance for 12 months included.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Review Contract Terms',
            style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review and confirm the terms extracted by AI from the negotiation history.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),
            _buildEditableField('Final Agreed Price (SAR)',
                _priceController, Icons.monetization_on),
            const SizedBox(height: 20),
            _buildEditableField(
                'Project Duration', _durationController, Icons.timer),
            const SizedBox(height: 20),
            _buildEditableField('Contract Clauses', _termsController,
                Icons.article,
                maxLines: 5),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3395FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FinalizeContractScreen(
                      contractTitle: 'Final Project Contract',
                      contractId: widget.proposalId,
                      managerName: 'Project Manager',
                      contractorName: widget.contractorName,
                      effectiveDate:
                          DateTime.now().toString().split(' ')[0],
                    ),
                  ),
                ),
                child: const Text('Finalize Contract',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
      String label, TextEditingController ctrl, IconData icon,
      {int maxLines = 1}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF3395FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey, size: 20),
              filled: true,
              fillColor: const Color(0xFF1C242F),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF3395FF))),
            ),
          ),
        ],
      );
}