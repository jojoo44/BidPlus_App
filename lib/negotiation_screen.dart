// negotiation_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final String? rfpDescription;
  final String? rfpScope;

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
    this.rfpDescription,
    this.rfpScope,
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
  bool _isGeneratingSuggestion = false;
  bool _showAISuggestion = true;
  String _aiSuggestionText = '';
  String _sessionStatus = 'Active';

  // ✅ جديد: تفاصيل المشروع تُجلب مباشرة من قاعدة البيانات
  String _rfpDescription = '';
  String _rfpScope = '';
  String _rfpBudget = '';

  String? _contractId;
  String? _firstContractUrl;
  String? _firstContractName;
  String? _firstContractUploader;
  String? _signedContractUrl;
  String? _signedContractName;
  String _contractStatus = '';
  bool _managerFinalized = false;
  bool _contractorFinalized = false;

  RealtimeChannel? _channel;

  bool get _iHaveUploaded =>
      _firstContractUploader != null &&
      (widget.isManager
          ? _firstContractUploader == 'manager'
          : _firstContractUploader == 'contractor');
  bool get _otherUploaded => _firstContractUrl != null && !_iHaveUploaded;
  bool get _signedUploaded => _signedContractUrl != null;
  bool get _myFinalized =>
      widget.isManager ? _managerFinalized : _contractorFinalized;
  bool get _contractActive => _contractStatus == 'Active';

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

  Future<Map<String, dynamic>?> _fetchDocument(
    String uploadType, {
    bool ascending = true,
  }) async {
    final sid = int.tryParse(widget.sessionId) ?? 0;
    try {
      final d = await supabase
          .from('Document')
          .select('fileURL,fullName,uploadedBy')
          .eq('uploadType', uploadType)
          .eq('sessionID', sid)
          .order('documentID', ascending: ascending)
          .limit(1)
          .maybeSingle();
      if (d != null) return d;
    } catch (_) {}
    return null;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessionId = int.tryParse(widget.sessionId) ?? widget.sessionId;
      final session = await supabase
          .from('NegoSession')
          .select('status')
          .eq('session_id', sessionId)
          .maybeSingle();
      final rounds = await supabase
          .from('NegoRounds')
          .select(
            'roundID,sessionID,rfp_id,proposal_id,manager_id,contractor_id,Terms,UpdateTerms,created_at,fileURL',
          )
          .eq('sessionID', sessionId)
          .order('roundID', ascending: true);

      // ✅ جلب تفاصيل المشروع من جدول RFP مباشرة
      try {
        final rfp = await supabase
            .from('RFP')
            .select('title, description, budget, requiredSpecialization')
            .eq('rfpID', int.tryParse(widget.rfpId) ?? 0)
            .maybeSingle();
        if (rfp != null) {
          _rfpDescription = rfp['description']?.toString() ?? '';
          _rfpScope = rfp['requiredSpecialization']?.toString() ?? '';
          _rfpBudget = rfp['budget']?.toString() ?? widget.budget?.toString() ?? '';
        }
      } catch (_) {
        _rfpBudget = widget.budget?.toString() ?? '';
      }

      try {
        final c = await supabase
            .from('Contract')
            .select('id,status,manager_finalized,contractor_finalized')
            .eq('paymentID', widget.rfpId)
            .maybeSingle();
        if (c != null) {
          _contractId = c['id']?.toString();
          _contractStatus = c['status'] ?? '';
          _managerFinalized = c['manager_finalized'] == true;
          _contractorFinalized = c['contractor_finalized'] == true;
        }
      } catch (_) {}
      final d = await _fetchDocument('Contract', ascending: true);
      if (d != null) {
        _firstContractUrl = d['fileURL']?.toString();
        _firstContractName = d['fullName']?.toString();
        _firstContractUploader = d['uploadedBy']?.toString();
      }
      final s = await _fetchDocument('Contract_Signed', ascending: false);
      if (s != null) {
        _signedContractUrl = s['fileURL']?.toString();
        _signedContractName = s['fullName']?.toString();
      }
      if (mounted) {
        setState(() {
          _sessionStatus = session?['status'] ?? 'Active';
          _rounds = List<Map<String, dynamic>>.from(rounds);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime() {
    final sidInt = int.tryParse(widget.sessionId) ?? 0;
    _channel = supabase
        .channel(
          'nego_${widget.sessionId}_${DateTime.now().millisecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'NegoRounds',
          callback: (p) {
            final row = p.newRecord;
            if (!mounted) return;
            final rowSid = row['sessionID']?.toString();
            if (rowSid != widget.sessionId && rowSid != sidInt.toString()) return;
            final roundId = row['roundID']?.toString();
            if (_rounds.any((r) => r['roundID']?.toString() == roundId)) return;
            setState(() => _rounds.add(row));
            _scrollToBottom();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'Contract',
          callback: (p) {
            final row = p.newRecord;
            if (mounted) {
              setState(() {
                _contractStatus = row['status'] ?? _contractStatus;
                _managerFinalized = row['manager_finalized'] == true;
                _contractorFinalized = row['contractor_finalized'] == true;
              });
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Document',
          callback: (p) {
            final row = p.newRecord;
            final rowSession = row['sessionID']?.toString();
            final widgetSid = widget.sessionId;
            if ((rowSession != widgetSid &&
                    rowSession != int.tryParse(widgetSid)?.toString()) ||
                !mounted)
              return;
            final type = row['uploadType']?.toString() ?? '';
            if (type == 'Contract') {
              setState(() {
                _firstContractUrl = row['fileURL']?.toString();
                _firstContractName = row['fullName']?.toString();
                _firstContractUploader = row['uploadedBy']?.toString();
              });
            } else if (type == 'Contract_Signed') {
              setState(() {
                _signedContractUrl = row['fileURL']?.toString();
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
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> _resolveSessionId() async {
    String id = widget.sessionId;
    if ((int.tryParse(id) ?? 0) == 0 && widget.rfpId.isNotEmpty) {
      try {
        final s = await supabase
            .from('NegoSession')
            .select('session_id')
            .eq('rfp_id', int.tryParse(widget.rfpId) ?? 0)
            .order('start_date', ascending: false)
            .limit(1)
            .maybeSingle();
        if (s != null) id = s['session_id'].toString();
      } catch (_) {}
    }
    return id;
  }

  Future<void> _generateAISuggestion() async {
    setState(() {
      _isGeneratingSuggestion = true;
      _showAISuggestion = true;
      _aiSuggestionText = '';
    });
    try {
      final history = _rounds
          .map((r) => '${r['UpdateTerms']}: ${r['Terms']}')
          .join('\n');
      final res = await supabase.functions.invoke(
        'negotiate_suggest',
        body: {
          'title': widget.rfpTitle,
          'budget': _rfpBudget.isNotEmpty ? _rfpBudget : widget.budget?.toString() ?? '',
          'history': history,
          'criteria': widget.selectedCriteria.join(', '),
          'isManager': widget.isManager,
          'description': _rfpDescription, // ✅ من قاعدة البيانات مباشرة
          'scope': _rfpScope,             // ✅ من قاعدة البيانات مباشرة
        },
      );
      if (mounted) {
        setState(
          () => _aiSuggestionText = res.data['suggestion']?.toString() ?? '',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSuggestion = false);
    }
  }

  Future<void> _completeNegotiation() async {
    setState(() => _isGeneratingSuggestion = true);
    try {
      final history = _rounds
          .map((r) => '${r['UpdateTerms']}: ${r['Terms']}')
          .join('\n');
      final res = await supabase.functions.invoke(
        'negotiate-extract',
        body: {'history': history},
      );
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AIContractReviewScreen(
              contractorName: widget.contractorName,
              proposalId: widget.proposalId,
              finalPrice: data['finalPrice']?.toString() ?? '',
              duration: data['duration']?.toString() ?? '',
              terms: (data['terms'] as List?)?.join('. ') ?? '',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSuggestion = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _msgCtrl.clear();
    setState(() => _isSending = true);
    try {
      final sessionId = await _resolveSessionId();
      final sessionIdInt = int.tryParse(sessionId) ?? 0;
      final userId = supabase.auth.currentUser?.id;
      final Map<String, dynamic> data = {
        'sessionID': sessionIdInt,
        'Terms': text.trim(),
        'UpdateTerms': widget.isManager ? 'manager' : 'contractor',
      };
      final rfpIdInt = widget.rfpId.isNotEmpty ? int.tryParse(widget.rfpId) : null;
      final proposalIdInt = widget.proposalId.isNotEmpty ? int.tryParse(widget.proposalId) : null;
      if (rfpIdInt != null) data['rfp_id'] = rfpIdInt;
      if (proposalIdInt != null) data['proposal_id'] = proposalIdInt;
      if (widget.isManager) data['manager_id'] = userId;
      if (!widget.isManager) data['contractor_id'] = userId;
      await supabase.from('NegoRounds').insert(data);
      await _notifyOtherParty(
        'New Message',
        '${widget.isManager ? "Manager" : widget.contractorName} sent a message in "${widget.rfpTitle}".',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (kIsWeb && file.bytes == null) return;
    if (!kIsWeb && file.path == null) return;
    setState(() => _isSending = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      final path = 'contracts/${widget.sessionId}_${widget.isManager ? "mgr" : "ctr"}_${_sanitizeFileName(file.name)}';
      final url = await _uploadToStorage(path, file);
      final sessionId = await _resolveSessionId();
      final Map<String, dynamic> data = {
        'sessionID': int.tryParse(sessionId) ?? 0,
        'Terms': '📎 ${file.name}',
        'UpdateTerms': widget.isManager ? 'manager' : 'contractor',
        'fileURL': url,
      };
      if (widget.isManager) data['manager_id'] = userId;
      if (!widget.isManager) data['contractor_id'] = userId;
      await supabase.from('NegoRounds').insert(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ File sent!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _uploadFirstContract() async {
    if (_firstContractUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A contract is already uploaded. Delete it first to upload a new one.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (kIsWeb && file.bytes == null) return;
    if (!kIsWeb && file.path == null) return;
    setState(() => _isUploadingContract = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final uploaderRole = widget.isManager ? 'manager' : 'contractor';
      final path = 'contracts/${widget.sessionId}_${uploaderRole}_original_${_sanitizeFileName(file.name)}';
      final url = await _uploadToStorage(path, file);
      final sidInt = int.tryParse(widget.sessionId) ?? 0;
      await supabase.from('Document').insert({
        'fullName': file.name,
        'fileURL': url,
        'uploadDate': DateTime.now().toIso8601String().split('T')[0],
        'uploader': userId,
        'uploadedBy': uploaderRole,
        'uploadType': 'Contract',
        'sessionID': sidInt,
      });
      if (_contractId == null) {
        final row = await supabase
            .from('Contract')
            .insert({
              'startDate': DateTime.now().toIso8601String().split('T')[0],
              'status': 'Pending_Signature',
              'description': widget.rfpTitle,
              'paymentID': int.tryParse(widget.rfpId),
              'manager_finalized': false,
              'contractor_finalized': false,
            })
            .select('id')
            .single();
        _contractId = row['id']?.toString();
      } else {
        await supabase.from('Contract').update({'status': 'Pending_Signature'}).eq('id', _contractId!);
      }
      await _notifyOtherParty(
        'Contract Ready',
        '${widget.isManager ? "Manager" : widget.contractorName} attached a contract for "${widget.rfpTitle}". Please download, sign, and re-upload.',
      );
      if (mounted) {
        setState(() {
          _firstContractUrl = url;
          _firstContractName = file.name;
          _firstContractUploader = uploaderRole;
          _contractStatus = 'Pending_Signature';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Contract sent to the other party!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }

  Future<void> _deleteContract() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Contract?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will remove the uploaded contract. You can upload a new one after.',
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isUploadingContract = true);
    try {
      final sidInt = int.tryParse(widget.sessionId) ?? 0;
      await supabase.from('Document').delete().eq('uploadType', 'Contract').eq('sessionID', sidInt);
      if (mounted) {
        setState(() {
          _firstContractUrl = null;
          _firstContractName = null;
          _firstContractUploader = null;
          _contractStatus = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract deleted. You can upload a new one.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  Future<void> _downloadContract() async {
    if (_firstContractUrl != null) await _openUrl(_firstContractUrl!);
  }

  Future<void> _uploadSignedContract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (kIsWeb && file.bytes == null) return;
    if (!kIsWeb && file.path == null) return;
    setState(() => _isUploadingContract = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final uploaderRole = widget.isManager ? 'manager' : 'contractor';
      final path = 'contracts/${widget.sessionId}_${uploaderRole}_signed_${_sanitizeFileName(file.name)}';
      final url = await _uploadToStorage(path, file);
      final sidInt = int.tryParse(widget.sessionId) ?? 0;
      await supabase.from('Document').insert({
        'fullName': file.name,
        'fileURL': url,
        'uploadDate': DateTime.now().toIso8601String().split('T')[0],
        'uploader': userId,
        'uploadedBy': uploaderRole,
        'uploadType': 'Contract_Signed',
        'sessionID': sidInt,
      });
      await _notifyOtherParty(
        'Contract Signed',
        '${widget.isManager ? "Manager" : widget.contractorName} uploaded the signed contract. Please finalize.',
      );
      if (mounted) {
        setState(() {
          _signedContractUrl = url;
          _signedContractName = file.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Signed contract uploaded!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }

  Future<void> _finalizeContract() async {
    if (_contractId == null) return;
    setState(() => _isUploadingContract = true);
    try {
      final field = widget.isManager ? 'manager_finalized' : 'contractor_finalized';
      await supabase.from('Contract').update({field: true}).eq('id', _contractId!);
      if (mounted) {
        setState(() {
          if (widget.isManager) _managerFinalized = true;
          if (!widget.isManager) _contractorFinalized = true;
        });
      }
      final c = await supabase.from('Contract').select('manager_finalized,contractor_finalized').eq('id', _contractId!).single();
      final both = c['manager_finalized'] == true && c['contractor_finalized'] == true;
      if (both) {
        await supabase.from('Contract').update({'status': 'Active'}).eq('id', _contractId!);
        final sid = int.tryParse(widget.sessionId) ?? widget.sessionId;
        await supabase.from('NegoSession').update({'status': 'Completed', 'end_date': DateTime.now().toIso8601String()}).eq('session_id', sid);
        await _notifyOtherParty('Contract Active', 'The contract for "${widget.rfpTitle}" is finalized by both parties. Project is now active!');
        if (mounted) {
          setState(() {
            _contractStatus = 'Active';
            _sessionStatus = 'Completed';
            _managerFinalized = true;
            _contractorFinalized = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Contract finalized! Project is now active.'), backgroundColor: Colors.green),
          );
        }
      } else {
        await _notifyOtherParty('Finalize Contract', '${widget.isManager ? "Manager" : widget.contractorName} confirmed their part. Please finalize the contract.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Waiting for the other party to confirm.'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingContract = false);
    }
  }

  Future<void> _notifyOtherParty(String type, String message) async {
    try {
      final sid = int.tryParse(widget.sessionId) ?? 0;
      final session = await supabase.from('NegoSession').select('rfp_id,contractor_id').eq('session_id', sid).maybeSingle();
      if (session == null) return;
      final rfpId = session['rfp_id'];
      String? recipientId;
      if (widget.isManager) {
        recipientId = session['contractor_id']?.toString();
        if (recipientId == null && rfpId != null) {
          final p = await supabase.from('proposals').select('submitterUserId').eq('RFP', rfpId).eq('status', 'Accepted').maybeSingle();
          recipientId = p?['submitterUserId']?.toString();
        }
      } else {
        if (rfpId != null) {
          final rfp = await supabase.from('RFP').select('creatorUser').eq('rfpID', rfpId).maybeSingle();
          recipientId = rfp?['creatorUser']?.toString();
        }
      }
      if (recipientId != null) {
        await supabase.from('Notification').insert({
          'userID': recipientId,
          'type': type,
          'message': message,
          'readStatus': false,
          'timeStamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
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

  String _sanitizeFileName(String originalName) {
    final parts = originalName.split('.');
    final ext = parts.length > 1 ? parts.last.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '') : 'pdf';
    return '${DateTime.now().millisecondsSinceEpoch}.$ext';
  }

  Future<String> _uploadToStorage(String storagePath, PlatformFile file) async {
    if (kIsWeb) {
      await supabase.storage.from('proposal_attachments').uploadBinary(storagePath, file.bytes!);
    } else {
      final f = File(file.path!);
      await supabase.storage.from('proposal_attachments').upload(storagePath, f, fileOptions: const FileOptions(upsert: true));
    }
    return supabase.storage.from('proposal_attachments').getPublicUrl(storagePath);
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _sessionStatus == 'Completed';
    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
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
            Text(widget.rfpTitle, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            Text('${widget.contractorName} • $_sessionStatus', style: TextStyle(color: isCompleted ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (widget.selectedCriteria.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: surface,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: widget.selectedCriteria.map((c) => Chip(
                          label: Text(c, style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: cardColor,
                          side: const BorderSide(color: primaryBlue, width: 0.5),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ),
                  if (_showAISuggestion && !isCompleted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: GestureDetector(
                        onTap: () {
                          if (_aiSuggestionText.isNotEmpty) {
                            _msgCtrl.text = _aiSuggestionText;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Suggestion added to message field'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryBlue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('AI SUGGESTION', style: TextStyle(color: primaryBlue, fontSize: 9, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    _isGeneratingSuggestion
                                        ? const Row(children: [
                                            SizedBox(width: 10, height: 10, child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2)),
                                            SizedBox(width: 6),
                                            Text('Generating...', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                          ])
                                        : Text(
                                            _aiSuggestionText.isNotEmpty
                                                ? _aiSuggestionText
                                                : (widget.budget != null
                                                    ? 'Suggest offering ${((widget.budget as num) * 0.95).toStringAsFixed(0)} SAR with 50% upfront.'
                                                    : 'Press "Generate Suggestions" to get an AI recommendation.'),
                                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _showAISuggestion = false),
                                child: const Icon(Icons.close, color: Colors.white38, size: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!isCompleted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isGeneratingSuggestion ? null : _generateAISuggestion,
                          icon: _isGeneratingSuggestion
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                          label: const Text('Generate Suggestions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                  _buildContractSection(),
                  if (_contractActive)
                    _buildBanner(Icons.check_circle, Colors.greenAccent, '🎉 Contract active! Project is now running.'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : _rounds.isEmpty
                    ? Center(child: Text(widget.isManager ? 'Start the negotiation' : 'Waiting for the manager to start...', style: TextStyle(color: Colors.white.withOpacity(0.4))))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _rounds.length,
                        itemBuilder: (_, i) {
                          final r = _rounds[i];
                          final isMe = widget.isManager ? r['UpdateTerms'] == 'manager' : r['UpdateTerms'] == 'contractor';
                          return _ChatBubble(
                            text: r['Terms']?.toString() ?? '',
                            isMe: isMe,
                            time: _fmtTime(r['created_at']),
                            label: isMe ? 'You' : widget.contractorName,
                            fileURL: r['fileURL']?.toString(),
                          );
                        },
                      ),
          ),
          if (!isCompleted && !_contractActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: surface,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cardColor,
                    child: IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.white54, size: 18),
                      onPressed: _isSending ? null : _sendFile,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: primaryBlue,
                    child: _isSending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 18),
                            onPressed: () => _sendMessage(_msgCtrl.text),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContractSection() {
    if (_firstContractUrl == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.upload_file, color: Colors.white54, size: 18),
                SizedBox(width: 8),
                Text('Attach Contract Document', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              const Text('Either party can attach the initial contract file.', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withOpacity(0.15),
                    foregroundColor: Colors.greenAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.greenAccent, width: 0.5)),
                  ),
                  onPressed: _isUploadingContract ? null : _uploadFirstContract,
                  icon: _isUploadingContract
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.greenAccent, strokeWidth: 2))
                      : const Icon(Icons.attach_file, size: 18),
                  label: const Text('Attach Contract File', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_iHaveUploaded && !_signedUploaded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async { if (_firstContractUrl != null) await _openUrl(_firstContractUrl!); },
                    child: _fileBox(_firstContractName ?? 'Contract', Colors.amber, showDownload: true),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isUploadingContract ? null : _deleteContract,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.4))),
                    child: _isUploadingContract
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                        : const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              const Row(children: [
                Icon(Icons.hourglass_top, color: Colors.amber, size: 15),
                SizedBox(width: 6),
                Expanded(child: Text('Waiting for the other party to sign and re-upload.', style: TextStyle(color: Colors.amber, fontSize: 12))),
              ]),
            ],
          ),
        ),
      );
    }
    if (_otherUploaded && !_signedUploaded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.description_outlined, color: Colors.lightBlueAccent, size: 18),
                SizedBox(width: 8),
                Text('Contract attached — review & sign', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _downloadContract,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.lightBlueAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.25))),
                  child: Row(children: [
                    const Icon(Icons.insert_drive_file, color: Colors.lightBlueAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_firstContractName ?? 'Contract', style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      const Text('Tap to open & download', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontStyle: FontStyle.italic)),
                    ])),
                    const Icon(Icons.download, color: Colors.lightBlueAccent, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Sign the document then upload the signed copy:', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF41C0FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _isUploadingContract ? null : _uploadSignedContract,
                  icon: _isUploadingContract
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload Signed Copy', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_signedUploaded && !_contractActive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_firstContractUrl != null) ...[
                const Text('Original Contract', style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                GestureDetector(onTap: _downloadContract, child: _fileBox(_firstContractName ?? 'Contract', Colors.white54, showDownload: true)),
                const SizedBox(height: 10),
              ],
              const Text('Signed Copy', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () async { if (_signedContractUrl != null) await _openUrl(_signedContractUrl!); },
                child: _fileBox(_signedContractName ?? 'Signed Contract', Colors.greenAccent, showDownload: true),
              ),
              const Divider(color: Colors.white12, height: 20),
              Row(children: [_finalizeChip('Manager', _managerFinalized), const SizedBox(width: 8), _finalizeChip('Contractor', _contractorFinalized)]),
              const SizedBox(height: 10),
              if (!_myFinalized)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _isUploadingContract ? null : _finalizeContract,
                    icon: _isUploadingContract
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.lock, size: 18, color: Colors.white),
                    label: const Text('Confirm & Finalize Contract', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                const Center(child: Text('Waiting for the other party to confirm...', style: TextStyle(color: Colors.white54, fontSize: 13))),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _fileBox(String name, Color color, {bool showDownload = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25))),
    child: Row(children: [
      Icon(Icons.insert_drive_file, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(name, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      if (showDownload) Icon(Icons.download, color: color, size: 16),
    ]),
  );

  Widget _statusChip(String label, bool done) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: done ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: done ? Colors.greenAccent.withOpacity(0.5) : Colors.white24),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(done ? Icons.check : Icons.hourglass_empty, size: 12, color: done ? Colors.greenAccent : Colors.white38),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: done ? Colors.greenAccent : Colors.white38, fontSize: 11)),
    ]),
  );

  Widget _finalizeChip(String label, bool done) => _statusChip(label, done);

  Widget _buildBanner(IconData icon, Color color, String text) => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _ChatBubble extends StatelessWidget {
  final String text, time, label;
  final bool isMe;
  final String? fileURL;
  const _ChatBubble({required this.text, required this.isMe, required this.time, required this.label, this.fileURL});

  bool get _isImage {
    if (fileURL == null) return false;
    final url = fileURL!.toLowerCase().split('?').first;
    return url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.png') || url.endsWith('.gif') || url.endsWith('.webp');
  }

  bool get _isFile => fileURL != null && fileURL!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10))),
            const SizedBox(height: 3),
            GestureDetector(
              onTap: _isFile ? () async {
                try { await launchUrl(Uri.parse(fileURL!), mode: LaunchMode.externalApplication); }
                catch (_) { try { await launchUrl(Uri.parse(fileURL!), mode: LaunchMode.platformDefault); } catch (_) {} }
              } : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF3395FF) : const Color(0xFF1C242F),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: _isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16)),
                        child: Image.network(fileURL!, width: screenWidth * 0.65, fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(width: screenWidth * 0.65, height: 140, color: Colors.white10, child: const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)));
                          },
                          errorBuilder: (_, __, ___) => _fileTile(screenWidth),
                        ),
                      )
                    : _isFile ? _fileTile(screenWidth)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4), softWrap: true, overflow: TextOverflow.visible),
                      ),
              ),
            ),
            const SizedBox(height: 3),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10))),
          ],
        ),
      ),
    );
  }

  Widget _fileTile(double screenWidth) {
    final fileName = text.replaceFirst('📎 ', '').trim().isNotEmpty ? text.replaceFirst('📎 ', '').trim() : (fileURL ?? '').split('/').last.split('?').first;
    final ext = fileName.split('.').last.toLowerCase();
    IconData icon;
    Color iconColor;
    if (ext == 'pdf') { icon = Icons.picture_as_pdf; iconColor = Colors.redAccent; }
    else if (['doc', 'docx'].contains(ext)) { icon = Icons.description; iconColor = Colors.blueAccent; }
    else { icon = Icons.insert_drive_file; iconColor = Colors.white70; }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: iconColor, size: 22)),
        const SizedBox(width: 10),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 2),
          const SizedBox(height: 2),
          const Row(children: [Icon(Icons.touch_app, color: Colors.white38, size: 10), SizedBox(width: 3), Text('Tap to open', style: TextStyle(color: Colors.white38, fontSize: 10))]),
        ])),
        const SizedBox(width: 8),
        const Icon(Icons.open_in_new, color: Colors.white38, size: 14),
      ]),
    );
  }
}

class AIContractReviewScreen extends StatefulWidget {
  final String contractorName, proposalId, finalPrice, duration, terms;
  const AIContractReviewScreen({super.key, required this.contractorName, required this.proposalId, this.finalPrice = '', this.duration = '', this.terms = ''});
  @override
  State<AIContractReviewScreen> createState() => _AIContractReviewScreenState();
}

class _AIContractReviewScreenState extends State<AIContractReviewScreen> {
  late final TextEditingController _priceCtrl, _durationCtrl, _termsCtrl;
  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.finalPrice);
    _durationCtrl = TextEditingController(text: widget.duration);
    _termsCtrl = TextEditingController(text: widget.terms);
  }

  @override
  void dispose() { _priceCtrl.dispose(); _durationCtrl.dispose(); _termsCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('Review Contract Terms', style: TextStyle(color: Colors.white))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Review and confirm the terms extracted by AI from the negotiation history.', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 30),
          _field('Final Agreed Price (SAR)', _priceCtrl, Icons.monetization_on),
          const SizedBox(height: 20),
          _field('Project Duration', _durationCtrl, Icons.timer),
          const SizedBox(height: 20),
          _field('Contract Clauses', _termsCtrl, Icons.article, maxLines: 5),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3395FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FinalizeContractScreen(
                contractTitle: 'Final Project Contract',
                contractId: widget.proposalId,
                managerName: 'Project Manager',
                contractorName: widget.contractorName,
                effectiveDate: DateTime.now().toString().split(' ')[0],
              ))),
              child: const Text('Finalize Contract', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Color(0xFF3395FF), fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 10),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          filled: true,
          fillColor: const Color(0xFF1C242F),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3395FF))),
        ),
      ),
    ],
  );
}