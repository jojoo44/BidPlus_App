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
  bool _isLoading = true;
  bool _hasSubmitted = false;

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
      final data = await supabase
          .from('proposals')
          .select('id')
          .eq('RFP', widget.rfpId)
          .eq('submitterUserId', userId);
      if (mounted) setState(() => _hasSubmitted = (data as List).isNotEmpty);
    } catch (_) {}
  }

  // ── Parse معايير التقييم وأزل النسب
  List<String> get _criteriaNames {
    final raw = _rfp?['evaluationCriteria'] as String?;
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((part) {
      final trimmed = part.trim();
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx == -1) return trimmed;
      return trimmed.substring(0, colonIdx).trim(); // اسم المعيار فقط بدون نسبة
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
        'userID': managerId,
        'type': 'New Proposal Received',
        'message': '$contractorName submitted a proposal for "$rfpTitle"',
        'readStatus': false,
        'timeStamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void _showSubmitProposalSheet() {
    final priceController = TextEditingController();
    final descController = TextEditingController();
    final List<PlatformFile> pickedFiles = [];
    final List<String> uploadedUrls = [];
    bool isSubmitting = false;
    bool isUploadingFile = false;

    // Controller لكل معيار
    final criteria = _criteriaNames;
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
              type: FileType.custom,
              allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg'],
              allowMultiple: true,
              withData: true,
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
                  pickedFiles.add(file);
                  uploadedUrls.add(url);
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

          return Padding(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Submit Proposal',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // السعر
                  const Text('Your Price (SAR)',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. 50000',
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

                  // Cover Letter
                  const Text('Cover Letter',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController, maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Describe your experience and approach...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: bgColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  // المعايير بدون نسب
                  if (criteria.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      const Icon(Icons.checklist_rounded,
                          color: primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      const Text('Evaluation Criteria',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    const Text(
                      'Fill in your details for each criterion',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ...criteria.asMap().entries.map((entry) {
                      final idx = entry.key;
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
                                color: primaryBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(name,
                                  style: const TextStyle(
                                      color: primaryBlue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: criteriaControllers[idx],
                              maxLines: 2,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Your ${name.toLowerCase()} details...',
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

                  // الملفات
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.attach_file_rounded,
                        color: primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    const Text('Attachments',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 10),

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
                      child: Row(children: [
                        const Icon(Icons.description_outlined,
                            color: primaryBlue, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(file.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                        GestureDetector(
                          onTap: () => setSheetState(() {
                            pickedFiles.removeAt(idx);
                            uploadedUrls.removeAt(idx);
                          }),
                          child: const Icon(Icons.close,
                              color: Colors.grey, size: 18),
                        ),
                      ]),
                    );
                  }),

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
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.grey)))
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

                  const SizedBox(height: 24),

                  // زر الإرسال
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

                          // بناء ردود المعايير
                          String criteriaResponse = '';
                          if (criteria.isNotEmpty) {
                            criteriaResponse = criteria
                                .asMap()
                                .entries
                                .map((e) =>
                                    '${e.value}: ${criteriaControllers[e.key].text.trim()}')
                                .join(' | ');
                          }

                          // أدخل الـ proposal
                          final proposalResult = await supabase
                              .from('proposals')
                              .insert({
                                'RFP': widget.rfpId,
                                'submitterUserId': userId,
                                'proposedPrice':
                                    double.tryParse(priceController.text) ?? 0,
                                'description': descController.text.trim(),
                                'status': 'Submitted',
                                'submitDate': DateTime.now()
                                    .toIso8601String()
                                    .split('T')[0],
                                'comments': criteriaResponse.isEmpty
                                    ? null
                                    : criteriaResponse,
                              })
                              .select('ProposalID')
                              .single();

                          final proposalId = proposalResult['ProposalID'];

                          // احفظ الملفات
                          for (int i = 0; i < pickedFiles.length; i++) {
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
                              userData['username'] ?? 'A contractor');

                          if (mounted) {
                            Navigator.pop(ctx);
                            setState(() => _hasSubmitted = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Proposal submitted successfully!'),
                                  backgroundColor: Colors.green));
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
                                  color: Colors.white,
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
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: const Text('RFP Details',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : _rfp == null
          ? const Center(
              child: Text('RFP not found', style: TextStyle(color: Colors.grey)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_rfp!['title'] ?? 'Untitled',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('Open for Proposals',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle('Key Information'),
                  _buildInfoCard([
                    _buildInfoRow(Icons.attach_money, 'Budget',
                        _rfp!['budget'] != null ? '\$${_rfp!['budget']}' : '—'),
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
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        _rfp!['description'] ?? 'No description provided.',
                        style: const TextStyle(
                            color: Colors.white70,
                            height: 1.6,
                            fontSize: 14)),
                  ),

                  // المعايير بدون نسب
                  if (_criteriaNames.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('Evaluation Criteria'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12)),
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _criteriaNames
                            .map((name) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: primaryBlue.withOpacity(0.3)),
                                  ),
                                  child: Text(name,
                                      style: const TextStyle(
                                          color: primaryBlue,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  _hasSubmitted
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Proposal Already Submitted',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ))
                      : SizedBox(
                          width: double.infinity, height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                            onPressed: _showSubmitProposalSheet,
                            child: const Text('Submit Proposal',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          )),
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
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold)));

  Widget _buildInfoCard(List<Widget> rows) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(12)),
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
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}