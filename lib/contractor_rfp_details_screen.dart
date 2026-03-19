// contractor_rfp_details_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';

class ContractorRFPDetailsScreen extends StatefulWidget {
  final String rfpId;
  const ContractorRFPDetailsScreen({super.key, required this.rfpId});

  @override
  State<ContractorRFPDetailsScreen> createState() =>
      _ContractorRFPDetailsScreenState();
}

class _ContractorRFPDetailsScreenState
    extends State<ContractorRFPDetailsScreen> {
  static const Color bgColor = Color(0xFF0D1219);
  static const Color cardColor = Color(0xFF1C242F);
  static const Color primaryBlue = Color(0xFF3395FF);

  Map<String, dynamic>? _rfp;
  List<Map<String, dynamic>> _rfpDocuments = [];
  bool _isLoading = true;
  bool _hasSubmitted = false;

  // ─── Parse criteria من الـ string "Cost:40%, Experience:60%"
  List<Map<String, String>> get _parsedCriteria {
    final raw = _rfp?['evaluationCriteria'] as String?;
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((part) {
      final trimmed = part.trim();
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx == -1) return {'name': trimmed, 'weight': ''};
      return {
        'name': trimmed.substring(0, colonIdx).trim(),
        'weight': trimmed.substring(colonIdx + 1).trim(),
      };
    }).toList();
  }

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

      // جيب ملفات الـ RFP من جدول Document
      final docs = await supabase
          .from('Document')
          .select()
          .eq('uploader', data['creatorUser'])
          .eq('uploadType', 'RFP_Attachment');

      if (mounted) {
        setState(() {
          _rfp = data;
          _rfpDocuments = List<Map<String, dynamic>>.from(docs);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfSubmitted() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await supabase
          .from('proposals')
          .select('id')
          .eq('RFP', widget.rfpId)
          .eq('submitterUserId', userId);
      if (mounted) setState(() => _hasSubmitted = (data as List).isNotEmpty);
    } catch (_) {}
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
        'userID': managerId,
        'type': 'New Proposal Received',
        'message': '$contractorName submitted a proposal for "$rfpTitle"',
        'readStatus': false,
        'timeStamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ─── Bottom Sheet لتقديم العرض
  void _showSubmitProposalSheet() {
    final priceController = TextEditingController();
    final descController = TextEditingController();

    // Controllers للمعايير — واحد لكل criterion
    final criteria = _parsedCriteria;
    final criteriaControllers = criteria
        .map((_) => TextEditingController())
        .toList();

    final List<PlatformFile> pickedFiles = [];
    final List<String> uploadedUrls = [];
    bool isSubmitting = false;
    bool isUploadingFile = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // ─── دالة رفع الملفات
          Future<void> pickFiles() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
              allowMultiple: true,
              withData: true,
            );
            if (result == null || result.files.isEmpty) return;
            setSheetState(() => isUploadingFile = true);
            try {
              final userId = supabase.auth.currentUser!.id;
              for (final file in result.files) {
                final bytes = file.bytes;
                if (bytes == null) continue;
                final path =
                    'proposals/$userId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
                await supabase.storage
                    .from('proposal_attachments')
                    .uploadBinary(path, bytes);
                final url = supabase.storage
                    .from('proposal_attachments')
                    .getPublicUrl(path);
                setSheetState(() {
                  pickedFiles.add(file);
                  uploadedUrls.add(url);
                });
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Upload failed: $e')),
                );
              }
            } finally {
              setSheetState(() => isUploadingFile = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Submit Proposal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── السعر
                  _sheetLabel('Your Price (SAR)'),
                  const SizedBox(height: 8),
                  _sheetTextField(
                    controller: priceController,
                    hint: 'e.g. 50000',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.attach_money,
                  ),
                  const SizedBox(height: 16),

                  // ── Cover Letter
                  _sheetLabel('Cover Letter'),
                  const SizedBox(height: 8),
                  _sheetTextField(
                    controller: descController,
                    hint: 'Describe your experience and approach...',
                    maxLines: 4,
                  ),

                  // ── المعايير اللي طلبها المدير
                  if (criteria.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.checklist_rounded,
                          color: primaryBlue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Evaluation Criteria',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fill in your details for each criterion set by the manager',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ...criteria.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final c = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: primaryBlue.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '${c['name']} — ${c['weight']}',
                                    style: const TextStyle(
                                      color: primaryBlue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _sheetTextField(
                              controller: criteriaControllers[idx],
                              hint:
                                  'Your ${c['name']?.toLowerCase()} details...',
                              maxLines: 2,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // ── المرفقات
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        color: primaryBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Attachments',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // قائمة الملفات المرفوعة
                  ...pickedFiles.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final file = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: primaryBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${(file.size / 1024).toStringAsFixed(1)} KB',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setSheetState(() {
                              pickedFiles.removeAt(idx);
                              uploadedUrls.removeAt(idx);
                            }),
                            child: const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // زر رفع الملفات
                  GestureDetector(
                    onTap: isUploadingFile ? null : pickFiles,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isUploadingFile
                          ? const Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.file_upload_outlined,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '+ Add Files (PDF, Word, Images)',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── زر الإرسال
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (priceController.text.isEmpty ||
                                  descController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill all fields'),
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => isSubmitting = true);
                              try {
                                final userId =
                                    supabase.auth.currentUser!.id;

                                // بناء نص المعايير المعبّأة من الكونتراكتر
                                String criteriaResponse = '';
                                if (criteria.isNotEmpty) {
                                  criteriaResponse = criteria
                                      .asMap()
                                      .entries
                                      .map((e) =>
                                          '${e.value['name']}: ${criteriaControllers[e.key].text.trim()}')
                                      .join(' | ');
                                }

                                // أدخل الـ proposal
                                final proposalResult = await supabase
                                    .from('proposals')
                                    .insert({
                                      'RFP': widget.rfpId,
                                      'submitterUserId': userId,
                                      'proposedPrice':
                                          double.tryParse(
                                            priceController.text,
                                          ) ??
                                          0,
                                      'description':
                                          descController.text.trim(),
                                      'status': 'Submitted',
                                      'submitDate': DateTime.now()
                                          .toIso8601String()
                                          .split('T')[0],
                                      // احفظ ردود المعايير في comments
                                      'comments': criteriaResponse.isEmpty
                                          ? null
                                          : criteriaResponse,
                                    })
                                    .select('ProposalID')
                                    .single();

                                final proposalId =
                                    proposalResult['ProposalID'];

                                // احفظ الملفات في جدول Document
                                for (int i = 0;
                                    i < pickedFiles.length;
                                    i++) {
                                  await supabase.from('Document').insert({
                                    'fullName': pickedFiles[i].name,
                                    'fileURL': uploadedUrls[i],
                                    'uploadDate': DateTime.now()
                                        .toIso8601String()
                                        .split('T')[0],
                                    'uploader': userId,
                                    'proposalID': proposalId,
                                    'uploadType': 'Proposal_Attachment',
                                  });
                                }

                                // أرسل إشعار للمدير
                                final userData = await supabase
                                    .from('User')
                                    .select('username')
                                    .eq('id', userId)
                                    .single();
                                await _notifyManager(
                                  userData['username'] ?? 'A contractor',
                                );

                                if (mounted) {
                                  Navigator.pop(ctx);
                                  setState(() => _hasSubmitted = true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Proposal submitted successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              } finally {
                                setSheetState(
                                  () => isSubmitting = false,
                                );
                              }
                            },
                      child: isSubmitting
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'Submit Proposal',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'RFP Details',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryBlue),
            )
          : _rfp == null
          ? const Center(
              child: Text(
                'RFP not found',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rfp!['title'] ?? 'Untitled',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Open for Proposals',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Key Information
                  _buildSectionTitle('Key Information'),
                  _buildInfoCard([
                    _buildInfoRow(
                      Icons.attach_money,
                      'Budget',
                      _rfp!['budget'] != null
                          ? '\$${_rfp!['budget']}'
                          : '—',
                    ),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Deadline',
                      _rfp!['deadline'] ?? '—',
                    ),
                    _buildInfoRow(
                      Icons.date_range,
                      'Posted',
                      _rfp!['creationDate'] ?? '—',
                    ),
                    if (_rfp!['requiredTag'] != null)
                      _buildInfoRow(
                        Icons.label_outline,
                        'Category',
                        _rfp!['requiredTag'],
                      ),
                    if (_rfp!['requiredSpecialization'] != null)
                      _buildInfoRow(
                        Icons.workspace_premium_outlined,
                        'Required Spec.',
                        _rfp!['requiredSpecialization'],
                      ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Description
                  _buildSectionTitle('Description'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _rfp!['description'] ?? 'No description provided.',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.6,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // ── Evaluation Criteria
                  if (_parsedCriteria.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('Evaluation Criteria'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: _parsedCriteria.map((c) {
                          final weight = c['weight'] ?? '';
                          final pct = double.tryParse(
                                weight.replaceAll('%', ''),
                              ) ??
                              0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      c['name'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      weight,
                                      style: const TextStyle(
                                        color: primaryBlue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: pct / 100,
                                    minHeight: 6,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.08),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // ── RFP Attachments
                  if (_rfpDocuments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('RFP Documents'),
                    ..._rfpDocuments.map(
                      (doc) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: primaryBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                doc['fullName'] ?? 'Document',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                // يمكن فتح الرابط لاحقاً بـ url_launcher
                              },
                              child: const Icon(
                                Icons.download_outlined,
                                color: Colors.grey,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // ── Submit Button
                  _hasSubmitted
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Proposal Already Submitted',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _showSubmitProposalSheet,
                            child: const Text(
                              'Submit Proposal',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ── Helpers
  Widget _sheetLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    ),
  );

  Widget _sheetTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: bgColor,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: Colors.grey, size: 20)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _buildSectionTitle(String title) => Padding(
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

  Widget _buildInfoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: rows),
  );

  Widget _buildInfoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: Colors.grey, size: 16),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}