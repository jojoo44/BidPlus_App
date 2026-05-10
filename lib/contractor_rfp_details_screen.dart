// contractor_rfp_details_screen.dart
import 'dart:async';
// ignore: unused_import
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'final_total_score_screen.dart';
import 'contractor_proposal_details_screen.dart';

// ✅ يرسل fileUrl للـ Edge Function التي تحمل الملف وترسله لـ GPT-4o
Future<int> _evaluateSingleFile({
  required String fileUrl,
  required String fileName,
  required String criterionName,
  required String rfpDescription,
}) async {
  try {
    debugPrint('🔍 Evaluating: $fileName | criterion: $criterionName');
    final response = await supabase.functions.invoke(
      'evaluate-proposal',
      body: {
        'fileUrl': fileUrl,
        'fileName': fileName,
        'criterionName': criterionName,
        'rfpDescription': rfpDescription,
      },
    );
    final data = response.data as Map<String, dynamic>?;
    debugPrint('📨 Edge Function response: $data');
    final score = data?['score'] as int? ?? 0;
    debugPrint('🏆 Score for $criterionName ($fileName): $score');
    return [0, 20, 40, 60, 80, 100].contains(score) ? score : 0;
  } catch (e) {
    debugPrint('❌ Edge Function error: $e');
    return 0;
  }
}

Future<int> _evaluateCriterionFiles({
  required List<Map<String, dynamic>> files,
  required String criterionName,
  required String rfpDescription,
}) async {
  if (files.isEmpty) {
    debugPrint('⚠️ No files for: $criterionName');
    return 0;
  }
  int totalScore = 0;
  for (final file in files) {
    totalScore += await _evaluateSingleFile(
      fileUrl: file['url'] as String,
      fileName: file['name'] as String,
      criterionName: criterionName,
      rfpDescription: rfpDescription,
    );
  }
  return (totalScore / files.length).round();
}

Future<Map<String, dynamic>> _computeAiScoreWithDetails({
  required Map<String, List<Map<String, dynamic>>> criteriaFiles,
  required String rfpDescription,
  required String evaluationCriteria,
}) async {
  try {
    debugPrint('📊 evaluationCriteria from DB: "$evaluationCriteria"');
    debugPrint('📁 criteriaFiles keys: ${criteriaFiles.keys.toList()}');

    if (evaluationCriteria.trim().isEmpty) {
      debugPrint('❌ evaluationCriteria is empty!');
      return {'finalScore': 0, 'criteriaScores': <String, int>{}};
    }

    final weights = <String, double>{};
    for (final part in evaluationCriteria.split(',')) {
      final trimmed = part.trim();
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx == -1) continue;
      final name = trimmed.substring(0, colonIdx).trim();
      final rawWeight = trimmed
          .substring(colonIdx + 1)
          .trim()
          .replaceAll('%', '')
          .trim();
      final weight = (double.tryParse(rawWeight) ?? 0) / 100;
      debugPrint('⚖️ "$name" | raw="$rawWeight" | weight=$weight');
      if (weight > 0) weights[name] = weight;
    }

    if (weights.isEmpty) {
      debugPrint('❌ No valid weights parsed!');
      return {'finalScore': 0, 'criteriaScores': <String, int>{}};
    }

    debugPrint('✅ Parsed weights: $weights');

    final criteriaScores = <String, int>{};
    double total = 0;
    for (final entry in weights.entries) {
      final matchingKey = criteriaFiles.keys.firstWhere(
        (k) => k.trim().toLowerCase() == entry.key.trim().toLowerCase(),
        orElse: () => entry.key,
      );
      final score = await _evaluateCriterionFiles(
        files: criteriaFiles[matchingKey] ?? [],
        criterionName: entry.key,
        rfpDescription: rfpDescription,
      );
      criteriaScores[entry.key] = score;
      total += score * entry.value;
      debugPrint(
          '📈 ${entry.key}: score=$score × weight=${entry.value} = ${score * entry.value}');
    }

    final finalScore = total.round().clamp(0, 100);
    debugPrint('🎯 FINAL SCORE: $finalScore');
    return {
      'finalScore': finalScore,
      'criteriaScores': criteriaScores,
    };
  } catch (e) {
    debugPrint('❌ _computeAiScoreWithDetails error: $e');
    return {'finalScore': 0, 'criteriaScores': <String, int>{}};
  }
}

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
          .maybeSingle();
      if (mounted){
        setState(() {
          _rfp = data;
          _isLoading = false;
        });}
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
          .select('*, RFP(*)')
          .eq('RFP', widget.rfpId)
          .eq('submitterUserId', userId);
      final list = data as List;
      if (mounted){
        setState(() {
          _hasSubmitted = list.isNotEmpty;
          if (list.isNotEmpty) {
            _submittedProposal = Map<String, dynamic>.from(list.first);
          }
        });}
    } catch (_) {}
  }

  List<String> get _criteriaNames {
    final raw = _rfp?['evaluationCriteria'] as String?;
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((part) {
      final trimmed = part.trim();
      final colonIdx = trimmed.indexOf(':');
      return colonIdx == -1 ? trimmed : trimmed.substring(0, colonIdx).trim();
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
          .maybeSingle();
      if (managerData == null || managerData['notificationsEnabled'] == false){
        return;}
      await supabase.from('Notification').insert({
        'userID': managerId,
        'type': 'New Proposal Received',
        'message':
            '$contractorName submitted a proposal for "${_rfp?['title'] ?? 'an RFP'}"',
        'readStatus': false,
        'timeStamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
// ignore: unused_element
  Future<void> _openFile(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      } catch (_) {
        if (mounted){
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Cannot open file')));
        }
      }
    }
  }

  Future<void> _openPickedFile(Map<String, dynamic> fileData) async {
  final url = fileData['url'] as String? ?? '';
  if (url.isNotEmpty) {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
        return;
      } catch (_) {}
    }
  }
  if (mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Cannot open file')));
  }
}

  void _showSubmitProposalSheet() {
    final priceController = TextEditingController();
    final descController = TextEditingController();
    final Map<String, List<Map<String, dynamic>>> criteriaFiles = {};
    bool isSubmitting = false;
    bool isUploadingFile = false;
    String? uploadingForCriterion;
    final criteria = _criteriaNames;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> pickFileForCriterion(String criterionName) async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'doc'],
              withData: true,
              allowMultiple: true,
            );
            if (result == null || result.files.isEmpty) return;
            setSheetState(() {
              isUploadingFile = true;
              uploadingForCriterion = criterionName;
            });
            try {
              final userId = supabase.auth.currentUser!.id;
              criteriaFiles[criterionName] ??= [];
              for (final picked in result.files) {
                Uint8List? fileBytes;

                if (picked.bytes != null && picked.bytes!.isNotEmpty) {
                  fileBytes = picked.bytes;
                } else if (picked.path != null && picked.path!.isNotEmpty) {
                  try {
                    final f = File(picked.path!);
                    if (await f.exists()) {
                      fileBytes = await f.readAsBytes();
                    }
                  } catch (e) {
                    debugPrint('Read file error: $e');
                  }
                }

                if (fileBytes == null || fileBytes.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Could not read: ${picked.name}')),
                    );
                  }
                  continue;
                }

                final sanitized =
                    picked.name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
                final path =
                    'proposals/$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitized';
                await supabase.storage
                    .from('proposal_attachments')
                    .uploadBinary(
                      path,
                      fileBytes,
                      fileOptions: const FileOptions(upsert: true),
                    );
                final publicUrl = supabase.storage
                    .from('proposal_attachments')
                    .getPublicUrl(path);

                criteriaFiles[criterionName]!.add({
                  'name': picked.name,
                  'bytes': fileBytes,
                  'url': publicUrl,
                  'localPath': picked.path ?? '',
                });
              }
              setSheetState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ File uploaded!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
              }
            } finally {
              setSheetState(() {
                isUploadingFile = false;
                uploadingForCriterion = null;
              });
            }
          }

          final totalUploaded = criteriaFiles.values
              .fold(0, (sum, list) => sum + list.length);

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
                      filled: true,
                      fillColor: bgColor,
                      prefixIcon: const Icon(Icons.attach_money,
                          color: Colors.grey, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Cover Letter',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Describe your experience and approach...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (criteria.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.checklist_rounded,
                            color: primaryBlue, size: 18),
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
                    const Text('Upload one or more files for each criterion',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),
                    ...criteria.map((criterionName) {
                      final files = criteriaFiles[criterionName] ?? [];
                      final isLoadingThis = isUploadingFile &&
                          uploadingForCriterion == criterionName;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                criterionName,
                                style: const TextStyle(
                                  color: primaryBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...files.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final file = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.green.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.green, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _openPickedFile(file),
                                        child: Text(
                                          file['name'] as String,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Colors.white54,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setSheetState(() =>
                                          criteriaFiles[criterionName]!
                                              .removeAt(idx)),
                                      child: const Icon(Icons.close,
                                          color: Colors.grey, size: 16),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            GestureDetector(
                              onTap: isLoadingThis
                                  ? null
                                  : () => pickFileForCriterion(criterionName),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: files.isEmpty
                                        ? Colors.white12
                                        : primaryBlue.withValues(alpha: 0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: isLoadingThis
                                    ? const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.grey),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            files.isEmpty
                                                ? Icons.upload_file_outlined
                                                : Icons.add,
                                            color: files.isEmpty
                                                ? Colors.grey
                                                : primaryBlue,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            files.isEmpty
                                                ? 'Upload file for $criterionName'
                                                : '+ Add another file',
                                            style: TextStyle(
                                              color: files.isEmpty
                                                  ? Colors.grey
                                                  : primaryBlue,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bar_chart_rounded,
                            color: primaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$totalUploaded file(s) uploaded  •  AI will read & score each',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (priceController.text.isEmpty ||
                                  descController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Please fill all fields')),
                                );
                                return;
                              }
                              final missing = criteria
                                  .where((c) =>
                                      (criteriaFiles[c] ?? []).isEmpty)
                                  .toList();
                              if (missing.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Please upload files for: ${missing.join(', ')}'),
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => isSubmitting = true);
                              try {
                                final userId =
                                    supabase.auth.currentUser!.id;
                                final result =
                                    await _computeAiScoreWithDetails(
                                  criteriaFiles: criteriaFiles,
                                  rfpDescription:
                                      _rfp?['description'] ?? '',
                                  evaluationCriteria:
                                      _rfp?['evaluationCriteria'] ?? '',
                                );
                                final finalScore =
                                    result['finalScore'] as int;
                                final criteriaScores =
                                    result['criteriaScores']
                                        as Map<String, int>;
                                final criteriaResponse = criteriaScores
                                    .entries
                                    .map((e) => '${e.key}: ${e.value}')
                                    .join(' | ');

                                final proposalResult = await supabase
                                    .from('proposals')
                                    .insert({
                                      'RFP': widget.rfpId,
                                      'submitterUserId': userId,
                                      'proposedPrice':
                                          double.tryParse(
                                                  priceController.text) ??
                                              0,
                                      'description':
                                          descController.text.trim(),
                                      'status': 'Submitted',
                                      'score': finalScore,
                                      'submitDate': DateTime.now()
                                          .toIso8601String()
                                          .split('T')[0],
                                      'comments':
                                          criteriaResponse.isEmpty
                                              ? null
                                              : criteriaResponse,
                                    })
                                    .select('ProposalID')
                                    .maybeSingle();

                                if (proposalResult == null){
                                  throw Exception(
                                      'Failed to insert proposal');
                                      }
                                final proposalId =
                                    proposalResult['ProposalID'];

                                for (final entry
                                    in criteriaFiles.entries) {
                                  for (final file in entry.value) {
                                    await supabase
                                        .from('Document')
                                        .insert({
                                      'fullName': file['name'],
                                      'fileURL': file['url'],
                                      'uploadDate': DateTime.now()
                                          .toIso8601String()
                                          .split('T')[0],
                                      'uploader': userId,
                                      'proposalID': proposalId,
                                      'uploadType': 'Proposal_Attachment',
                                    });
                                  }
                                }

                                final userData = await supabase
                                    .from('User')
                                    .select('username')
                                    .eq('id', userId)
                                    .maybeSingle();
                                await _notifyManager(
                                    userData?['username'] ??
                                        'A contractor');

                                if (mounted) {
                                  Navigator.pop(context);
                                  setState(() => _hasSubmitted = true);
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FinalTotalScoreScreen(
                                        contractorName:
                                            userData?['username'] ??
                                                'Contractor',
                                        score: finalScore,
                                        proposalId:
                                            proposalId.toString(),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Error: $e')));
                              } finally {
                                setSheetState(
                                    () => isSubmitting = false);
                              }
                            },
                      child: isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('AI is reading files...',
                                    style:
                                        TextStyle(color: Colors.white)),
                              ],
                            )
                          : const Text(
                              'Submit Proposal',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
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
        title: const Text('RFP Details',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryBlue))
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
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Open for Proposals',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Key Information'),
                      _buildInfoCard([
                        _buildInfoRow(Icons.attach_money, 'Budget',
                            _rfp!['budget'] != null
                                ? '\$${_rfp!['budget']}'
                                : '—'),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _rfp!['description'] ??
                              'No description provided.',
                          style: const TextStyle(
                              color: Colors.white70,
                              height: 1.6,
                              fontSize: 14),
                        ),
                      ),
                      if (_criteriaNames.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildSectionTitle('Evaluation Criteria'),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _criteriaNames
                                .map((name) => Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            primaryBlue.withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: primaryBlue
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Text(name,
                                          style: const TextStyle(
                                              color: primaryBlue,
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      if (_hasSubmitted) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green),
                              SizedBox(width: 8),
                              Text('Proposal Already Submitted',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_submittedProposal != null)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: primaryBlue),
                                foregroundColor: primaryBlue,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              icon: const Icon(
                                  Icons.visibility_outlined),
                              label: const Text('Review My Proposal',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ContractorProposalDetailsScreen(
                                          proposal: _submittedProposal!),
                                ),
                              ),
                            ),
                          ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            onPressed: _showSubmitProposalSheet,
                            child: const Text('Submit Proposal',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
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
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      );

  Widget _buildInfoCard(List<Widget> rows) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: rows),
      );

  Widget _buildInfoRow(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 16),
            const SizedBox(width: 10),
            Text(label,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 14)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}