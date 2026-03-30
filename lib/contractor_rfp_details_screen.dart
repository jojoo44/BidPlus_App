// contractor_rfp_details_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'final_total_score_screen.dart';
import 'contractor_proposal_details_screen.dart';

// ─────────────────────────────────────────────
//  نقطة تكامل AI (مستقبلاً)
// ─────────────────────────────────────────────
Future<int> _computeAiScore({
  required List<String> filePaths,
  required String coverLetter,
  required Map<String, String> criteriaAnswers,
}) async {
  // TODO: ربط AI هنا لاحقاً
  return _scoreFromFileCount(filePaths.length);
}

int _scoreFromFileCount(int count) {
  if (count == 0) return 20;
  if (count == 1) return 40;
  if (count == 2) return 60;
  if (count == 3) return 80;
  return 100;
}
// ─────────────────────────────────────────────

class ContractorRFPDetailsScreen extends StatefulWidget {
  final String rfpId;
  const ContractorRFPDetailsScreen({super.key, required this.rfpId});

  @override
  State<ContractorRFPDetailsScreen> createState() =>
      _ContractorRFPDetailsScreenState();
}

class _ContractorRFPDetailsScreenState
    extends State<ContractorRFPDetailsScreen> {
  static const Color bgColor     = Color(0xFF0D1219);
  static const Color cardColor   = Color(0xFF1C242F);
  static const Color primaryBlue = Color(0xFF3395FF);

  Map<String, dynamic>? _rfp;
  bool _isLoading    = true;
  bool _hasSubmitted = false;
  Map<String, dynamic>? _submittedProposal;

  @override
  void initState() {
    super.initState();
    _loadRFP();
    _checkIfSubmitted();
  }

  Future<void> _loadRFP() async {
    try {
      final data = await supabase
          .from('RFP')
          .select()
          .eq('rfpID', widget.rfpId)
          .single();
      if (mounted) setState(() { _rfp = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfSubmitted() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      // ← التعديل الوحيد: إضافة RFP(*) حتى يُرسل كـ Map وليس int
      final data = await supabase
          .from('proposals')
          .select('*, RFP(*)')
          .eq('RFP', widget.rfpId)
          .eq('submitterUserId', userId);
      final list = data as List;
      if (mounted) {
        setState(() {
          _hasSubmitted = list.isNotEmpty;
          if (list.isNotEmpty) {
            _submittedProposal = Map<String, dynamic>.from(list.first);
          }
        });
      }
    } catch (_) {}
  }

  List<String> get _criteriaNames {
    final raw = _rfp?['evaluationCriteria'] as String?;
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((part) {
      final trimmed  = part.trim();
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx == -1) return trimmed;
      return trimmed.substring(0, colonIdx).trim();
    }).toList();
  }

  Future<void> _notifyManager(String contractorName) async {
    try {
      final managerId = _rfp?['creatorUser'];
      if (managerId == null) return;
      final managerData = await supabase
          .from('User')
          .select('notificationsEnabled')
          .eq('id', managerId)
          .single();
      if (managerData['notificationsEnabled'] == false) return;
      final rfpTitle = _rfp?['title'] ?? 'an RFP';
      await supabase.from('Notification').insert({
        'userID'   : managerId,
        'type'     : 'New Proposal Received',
        'message'  : '$contractorName submitted a proposal for "$rfpTitle"',
        'readStatus': false,
        'timeStamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _openPickedFile(Map<String, dynamic> fileData) async {
    final url       = fileData['url'] as String? ?? '';
    final localPath = fileData['localPath'] as String? ?? '';

    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      final uri = Uri.file(localPath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open file')));
    }
  }

  void _showSubmitProposalSheet() {
    final priceController = TextEditingController();
    final descController  = TextEditingController();

    final List<Map<String, dynamic>> pickedFiles = [];
    bool isSubmitting    = false;
    bool isUploadingFile = false;

    final criteria           = _criteriaNames;
    final criteriaControllers =
        criteria.map((_) => TextEditingController()).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {

          Future<void> pickFiles() async {
            final result = await FilePicker.platform.pickFiles(
              type             : FileType.custom,
              allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg'],
              allowMultiple    : true,
              withData         : true,
            );
            if (result == null) return;
            setSheetState(() => isUploadingFile = true);
            try {
              final userId = supabase.auth.currentUser!.id;
              for (final file in result.files) {
                if (file.bytes == null) continue;
                final path =
                    'proposals/$userId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
                await supabase.storage
                    .from('proposal_attachments')
                    .uploadBinary(path, file.bytes!);
                final url = supabase.storage
                    .from('proposal_attachments')
                    .getPublicUrl(path);
                setSheetState(() {
                  pickedFiles.add({
                    'name'     : file.name,
                    'localPath': file.path ?? '',
                    'url'      : url,
                  });
                });
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Upload failed: $e')));
              }
            } finally {
              setSheetState(() => isUploadingFile = false);
            }
          }

          final previewScore = _scoreFromFileCount(pickedFiles.length);

          return Padding(
            padding: EdgeInsets.only(
                left  : 24, right: 24, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize     : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width : 40, height: 4,
                      decoration: BoxDecoration(
                          color       : Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Submit Proposal',
                      style: TextStyle(
                          color     : Colors.white,
                          fontSize  : 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  const Text('Your Price (SAR)',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller  : priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText : 'e.g. 50000',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: bgColor,
                      prefixIcon: const Icon(Icons.attach_money,
                          color: Colors.grey, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Cover Letter',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController, maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText : 'Describe your experience and approach...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: bgColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  if (criteria.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      const Icon(Icons.checklist_rounded,
                          color: primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      const Text('Evaluation Criteria',
                          style: TextStyle(
                              color     : Colors.white,
                              fontSize  : 15,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    const Text('Fill in your details for each criterion',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),
                    ...criteria.asMap().entries.map((entry) {
                      final idx  = entry.key;
                      final name = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color       : primaryBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(name,
                                  style: const TextStyle(
                                      color     : primaryBlue,
                                      fontSize  : 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: criteriaControllers[idx],
                              maxLines  : 2,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText : 'Your ${name.toLowerCase()} details...',
                                hintStyle: const TextStyle(color: Colors.grey),
                                filled: true, fillColor: bgColor,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.attach_file_rounded,
                        color: primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    const Text('Attachments',
                        style: TextStyle(
                            color     : Colors.white,
                            fontSize  : 15,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 10),

                  ...pickedFiles.asMap().entries.map((entry) {
                    final idx  = entry.key;
                    final file = entry.value;
                    return Container(
                      margin : const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color       : bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border      : Border.all(color: Colors.white10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.description_outlined,
                            color: primaryBlue, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openPickedFile(file),
                            child: Text(
                              file['name'] as String,
                              style: const TextStyle(
                                color          : Colors.white,
                                fontSize       : 13,
                                decoration     : TextDecoration.underline,
                                decorationColor: Colors.white54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setSheetState(
                              () => pickedFiles.removeAt(idx)),
                          child: const Icon(Icons.close,
                              color: Colors.grey, size: 18),
                        ),
                      ]),
                    );
                  }),

                  GestureDetector(
                    onTap: isUploadingFile ? null : pickFiles,
                    child: Container(
                      width  : double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border      : Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isUploadingFile
                          ? const Center(
                              child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey)))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.file_upload_outlined,
                                    color: Colors.grey, size: 18),
                                SizedBox(width: 8),
                                Text('+ Add Files (PDF, Word, Images)',
                                    style: TextStyle(color: Colors.grey)),
                              ]),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color       : bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border      : Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bar_chart_rounded,
                            color: primaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estimated Score: $previewScore / 100  •  ${pickedFiles.length} file(s)',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12.5),
                          ),
                        ),
                        // TODO: مستقبلاً "Analyze with AI"
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: isSubmitting ? null : () async {
                        if (priceController.text.isEmpty ||
                            descController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please fill all fields')));
                          return;
                        }
                        setSheetState(() => isSubmitting = true);
                        try {
                          final userId = supabase.auth.currentUser!.id;

                          String criteriaResponse = '';
                          if (criteria.isNotEmpty) {
                            criteriaResponse = criteria
                                .asMap()
                                .entries
                                .map((e) =>
                                    '${e.value}: ${criteriaControllers[e.key].text.trim()}')
                                .join(' | ');
                          }

                          final Map<String, String> criteriaMap = {};
                          for (int i = 0; i < criteria.length; i++) {
                            criteriaMap[criteria[i]] =
                                criteriaControllers[i].text.trim();
                          }
                          final filePaths = pickedFiles
                              .map((f) => f['localPath'] as String)
                              .toList();
                          final score = await _computeAiScore(
                            filePaths      : filePaths,
                            coverLetter    : descController.text.trim(),
                            criteriaAnswers: criteriaMap,
                          );

                          final proposalResult = await supabase
                              .from('proposals')
                              .insert({
                                'RFP'            : widget.rfpId,
                                'submitterUserId': userId,
                                'proposedPrice'  :
                                    double.tryParse(priceController.text) ?? 0,
                                'description': descController.text.trim(),
                                'status'     : 'Submitted',
                                'score'      : score,
                                'submitDate' : DateTime.now()
                                    .toIso8601String()
                                    .split('T')[0],
                                'comments': criteriaResponse.isEmpty
                                    ? null
                                    : criteriaResponse,
                              })
                              .select('ProposalID')
                              .single();

                          final proposalId = proposalResult['ProposalID'];

                          for (final file in pickedFiles) {
                            await supabase.from('Document').insert({
                              'fullName'  : file['name'],
                              'fileURL'   : file['url'],
                              'uploadDate': DateTime.now()
                                  .toIso8601String()
                                  .split('T')[0],
                              'uploader'  : userId,
                              'proposalID': proposalId,
                              'uploadType': 'Proposal_Attachment',
                            });
                          }

                          final userData = await supabase
                              .from('User')
                              .select('username')
                              .eq('id', userId)
                              .single();
                          await _notifyManager(
                              userData['username'] ?? 'A contractor');

                          if (mounted) {
                            Navigator.pop(ctx);
                            setState(() => _hasSubmitted = true);

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FinalTotalScoreScreen(
                                  contractorName:
                                      userData['username'] ?? 'Contractor',
                                  score     : score,
                                  proposalId: proposalId.toString(),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        } finally {
                          setSheetState(() => isSubmitting = false);
                        }
                      },
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Proposal',
                              style: TextStyle(
                                  color     : Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
            icon    : const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: const Text('RFP Details',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : _rfp == null
          ? const Center(
              child: Text('RFP not found',
                  style: TextStyle(color: Colors.grey)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width  : double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color       : cardColor,
                        borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_rfp!['title'] ?? 'Untitled',
                            style: const TextStyle(
                                color     : Colors.white,
                                fontSize  : 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color       : Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('Open for Proposals',
                              style: TextStyle(
                                  color     : Colors.green,
                                  fontSize  : 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Key Information'),
                  _buildInfoCard([
                    _buildInfoRow(Icons.attach_money, 'Budget',
                        _rfp!['budget'] != null
                            ? '\$${_rfp!['budget']}' : '—'),
                    _buildInfoRow(Icons.calendar_today, 'Deadline',
                        _rfp!['deadline'] ?? '—'),
                    _buildInfoRow(Icons.date_range, 'Posted',
                        _rfp!['creationDate'] ?? '—'),
                    if (_rfp!['requiredTag'] != null)
                      _buildInfoRow(Icons.label_outline, 'Category',
                          _rfp!['requiredTag']),
                  ]),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Description'),
                  Container(
                    width  : double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color       : cardColor,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        _rfp!['description'] ?? 'No description provided.',
                        style: const TextStyle(
                            color   : Colors.white70,
                            height  : 1.6,
                            fontSize: 14)),
                  ),

                  if (_criteriaNames.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('Evaluation Criteria'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color       : cardColor,
                          borderRadius: BorderRadius.circular(12)),
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _criteriaNames.map((name) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color       : primaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border      : Border.all(
                                color: primaryBlue.withOpacity(0.3)),
                          ),
                          child: Text(name,
                              style: const TextStyle(
                                  color     : primaryBlue,
                                  fontSize  : 13,
                                  fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  if (_hasSubmitted) ...[
                    Container(
                      width  : double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color       : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border      : Border.all(
                            color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Proposal Already Submitted',
                              style: TextStyle(
                                  color     : Colors.green,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_submittedProposal != null)
                      SizedBox(
                        width : double.infinity,
                        height: 50,
                        child : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side           : const BorderSide(color: primaryBlue),
                            foregroundColor: primaryBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon : const Icon(Icons.visibility_outlined),
                          label: const Text('Review My Proposal',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContractorProposalDetailsScreen(
                                proposal: _submittedProposal!,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ] else
                    SizedBox(
                      width : double.infinity,
                      height: 55,
                      child : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        onPressed: _showSubmitProposalSheet,
                        child: const Text('Submit Proposal',
                            style: TextStyle(
                                color     : Colors.white,
                                fontSize  : 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: const TextStyle(
              color     : Colors.white,
              fontSize  : 16,
              fontWeight: FontWeight.bold)));

  Widget _buildInfoCard(List<Widget> rows) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color       : cardColor,
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: rows));

  Widget _buildInfoRow(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: Colors.grey, size: 16),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color     : Colors.white,
                  fontSize  : 14,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}