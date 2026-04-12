// contractor_rfp_details_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'final_total_score_screen.dart';
import 'contractor_proposal_details_screen.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

const String _mistralApiKey = 'MVa2RmzLbQhwrJ3M18YwrwR7uVvhyrIq';

// ─────────────────────────────────────────────
//  استخراج النص من PDF عبر pdf.js (مع إصلاح Promise)
// ─────────────────────────────────────────────
Future<String> _extractPdfText(Uint8List bytes) async {
  if (!kIsWeb) {
    // Mobile: استخراج بسيط
    try {
      final raw = utf8.decode(bytes, allowMalformed: true);
      final buffer = StringBuffer();
      final regex = RegExp(r'\(([^)]{2,})\)');
      for (final match in regex.allMatches(raw)) {
        final text = match.group(1) ?? '';
        if (text.codeUnits.every((c) => c >= 32 && c < 127)) {
          buffer.write('$text ');
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }

  // Web: نستخدم pdf.js
  try {
    final base64Data = base64Encode(bytes);
    final completer = Completer<String>();

    final jsPromise = js.context.callMethod('extractPdfText', [base64Data]);
    final jsObject = js.JsObject.fromBrowserObject(jsPromise);

    jsObject.callMethod('then', [
      js.allowInterop((dynamic result) {
        if (!completer.isCompleted) {
          completer.complete(result?.toString() ?? '');
        }
      })
    ]);

    jsObject.callMethod('catch', [
      js.allowInterop((dynamic error) {
        debugPrint('=== pdf.js error: $error ===');
        if (!completer.isCompleted) {
          completer.complete('');
        }
      })
    ]);

    final text = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('=== pdf.js TIMEOUT ===');
        return '';
      },
    );

    debugPrint('=== PDF text extracted: ${text.length} chars ===');
    if (text.isNotEmpty) {
      debugPrint('=== Sample: ${text.substring(0, text.length.clamp(0, 500))} ===');
    }
    return text;
  } catch (e) {
    debugPrint('=== _extractPdfText ERROR: $e ===');
    return '';
  }
}

// ─────────────────────────────────────────────
//  Mistral يقيّم ملف واحد
// ─────────────────────────────────────────────
Future<int> _evaluateSingleFile({
  required Uint8List fileBytes,
  required String fileName,
  required String criterionName,
  required String rfpDescription,
}) async {
  try {
    final ext = fileName.toLowerCase().split('.').last;
    String documentContent;

    if (ext == 'pdf') {
      documentContent = await _extractPdfText(fileBytes);
      if (documentContent.isEmpty) {
        documentContent = 'PDF file: $fileName';
      }
    } else {
      documentContent = 'Image/document file: $fileName submitted for $criterionName';
    }

    debugPrint('=== Evaluating: $fileName for $criterionName ===');
    debugPrint('=== Content (200 chars): ${documentContent.substring(0, documentContent.length.clamp(0, 200))} ===');

    final prompt = '''
You are a STRICT document evaluator for RFP proposals.

RFP Description: $rfpDescription
Required Criterion: "$criterionName"

Document Content:
$documentContent

TASK: Does this document DIRECTLY and SPECIFICALLY prove the "$criterionName" criterion?

CRITICAL RULES:
1. The document must be DIRECTLY about "$criterionName" - not just mention it indirectly
2. General company profiles, experience letters, or unrelated documents = 0
3. A financial document for "Technical" criterion = 0
4. An experience profile for "Cost" criterion = 0
5. Only give points if the document's PRIMARY PURPOSE is to prove "$criterionName"

Ask yourself: "Is the MAIN CONTENT of this document specifically about $criterionName?"
- If NO → return 0
- If YES → rate the quality:
  - 100 = Excellent proof with complete and clear evidence
  - 80  = Good proof with most evidence present
  - 60  = Satisfactory proof with basic evidence
  - 40  = Poor proof, missing key evidence
  - 20  = Very weak, barely related
  - 0   = Not related at all

Reply with ONLY ONE number: 0, 20, 40, 60, 80, or 100
''';

    final response = await http.post(
      Uri.parse('https://api.mistral.ai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_mistralApiKey',
      },
      body: jsonEncode({
        'model': 'mistral-small-latest',
        'messages': [{'role': 'user', 'content': prompt}],
        'max_tokens': 10,
        'temperature': 0,
      }),
    );

    debugPrint('=== Mistral STATUS: ${response.statusCode} ===');

    if (response.statusCode != 200) return 20;

    final data = jsonDecode(response.body);
    final text = (data['choices'][0]['message']['content'] as String).trim();
    debugPrint('=== AI RESPONSE for $fileName: $text ===');

    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    final score = int.tryParse(cleaned) ?? 20;
    final valid = [0, 20, 40, 60, 80, 100].contains(score) ? score : 0;
    return valid;
  } catch (e) {
    debugPrint('❌ _evaluateSingleFile ERROR: $e');
    return 20;
  }
}

// ─────────────────────────────────────────────
//  تقييم قائمة ملفات لمعيار واحد
//  يأخذ أعلى نقطة من بين الملفات
// ─────────────────────────────────────────────
Future<int> _evaluateCriterionFiles({
  required List<Map<String, dynamic>> files,
  required String criterionName,
  required String rfpDescription,
}) async {
  if (files.isEmpty) return 0;

  int totalScore = 0;
  for (final file in files) {
    final score = await _evaluateSingleFile(
      fileBytes: file['bytes'] as Uint8List,
      fileName: file['name'] as String,
      criterionName: criterionName,
      rfpDescription: rfpDescription,
    );
    debugPrint('=== File ${file['name']}: $score ===');
    totalScore += score;
  }

  final average = (totalScore / files.length).round();
  debugPrint('=== Average score for $criterionName: $average ===');
  return average;
}

// ─────────────────────────────────────────────
//  حساب الـ Final Score الكامل
// ─────────────────────────────────────────────
Future<int> _computeAiScore({
  required Map<String, List<Map<String, dynamic>>> criteriaFiles,
  required String rfpDescription,
  required String evaluationCriteria,
}) async {
  try {
    debugPrint('=== evaluationCriteria: "$evaluationCriteria" ===');
    if (evaluationCriteria.isEmpty) return 20;

    final weights = <String, double>{};
    for (final part in evaluationCriteria.split(',')) {
      final kv = part.trim().split(':');
      if (kv.length == 2) {
        final rawValue = kv[1].trim().replaceAll('%', '');
        weights[kv[0].trim()] = (double.tryParse(rawValue) ?? 0) / 100;
      }
    }
    debugPrint('=== weights: $weights ===');
    if (weights.isEmpty) return 20;

    double total = 0;
    for (final entry in weights.entries) {
      final files = criteriaFiles[entry.key] ?? [];
      if (files.isEmpty) {
        debugPrint('=== No files for ${entry.key} → 0 ===');
        continue;
      }

      final score = await _evaluateCriterionFiles(
        files: files,
        criterionName: entry.key,
        rfpDescription: rfpDescription,
      );

      final weighted = score * entry.value;
      debugPrint('=== ${entry.key}: $score × ${entry.value} = $weighted ===');
      total += weighted;
    }

    final finalScore = total.round().clamp(0, 100);
    debugPrint('=== FINAL SCORE: $finalScore ===');
    return finalScore;
  } catch (e) {
    debugPrint('=== _computeAiScore ERROR: $e ===');
    return 0;
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
          .from('RFP').select().eq('rfpID', widget.rfpId).single();
      if (mounted) {
        setState(() { _rfp = data; _isLoading = false; });
        debugPrint('=== RFP evaluationCriteria: "${data['evaluationCriteria']}" ===');
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
          .from('proposals').select('*, RFP(*)')
          .eq('RFP', widget.rfpId).eq('submitterUserId', userId);
      final list = data as List;
      if (mounted) {
        setState(() {
          _hasSubmitted = list.isNotEmpty;
          if (list.isNotEmpty) _submittedProposal = Map<String, dynamic>.from(list.first);
        });
      }
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
          .from('User').select('notificationsEnabled').eq('id', managerId).single();
      if (managerData['notificationsEnabled'] == false) return;
      await supabase.from('Notification').insert({
        'userID': managerId,
        'type': 'New Proposal Received',
        'message': '$contractorName submitted a proposal for "${_rfp?['title'] ?? 'an RFP'}"',
        'readStatus': false,
        'timeStamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _openPickedFile(Map<String, dynamic> fileData) async {
    final url = fileData['url'] as String? ?? '';
    final localPath = fileData['localPath'] as String? ?? '';
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); return; }
    }
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      final uri = Uri.file(localPath);
      if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); return; }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open file')));
  }

  void _showSubmitProposalSheet() {
    final priceController = TextEditingController();
    final descController = TextEditingController();

    // ← قائمة ملفات لكل معيار (بدال ملف واحد)
    final Map<String, List<Map<String, dynamic>>> criteriaFiles = {};
    bool isSubmitting = false;
    bool isUploadingFile = false;
    String? uploadingForCriterion;
    final criteria = _criteriaNames;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {

          Future<void> pickFileForCriterion(String criterionName) async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'png', 'jpg'],
              withData: true,
              allowMultiple: true, // ← أكثر من ملف
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
                Uint8List? fileBytes = picked.bytes;
                if (fileBytes == null && picked.path != null) {
                  try { fileBytes = await File(picked.path!).readAsBytes(); } catch (_) {}
                }
                if (fileBytes == null || fileBytes.isEmpty) continue;

                final path = 'proposals/$userId/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
                await supabase.storage
                    .from('proposal_attachments')
                    .uploadBinary(path, fileBytes);
                final publicUrl = supabase.storage
                    .from('proposal_attachments')
                    .getPublicUrl(path);

                criteriaFiles[criterionName]!.add({
                  'name': picked.name,
                  'bytes': fileBytes,
                  'url': publicUrl,
                  'localPath': picked.path ?? '',
                });
                debugPrint('=== Added: ${picked.name} for $criterionName ===');
              }
              setSheetState(() {});
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Upload failed: $e')));
            } finally {
              setSheetState(() { isUploadingFile = false; uploadingForCriterion = null; });
            }
          }

          final totalUploaded = criteriaFiles.values.fold(0, (sum, list) => sum + list.length);

          return Padding(
            padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),

                  const Text('Submit Proposal',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  const Text('Your Price (SAR)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. 50000', hintStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: bgColor,
                      prefixIcon: const Icon(Icons.attach_money, color: Colors.grey, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Cover Letter', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController, maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Describe your experience and approach...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),

                  if (criteria.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      const Icon(Icons.checklist_rounded, color: primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      const Text('Evaluation Criteria',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    const Text('Upload one or more PDFs for each criterion',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),

                    ...criteria.map((criterionName) {
                      final files = criteriaFiles[criterionName] ?? [];
                      final isLoadingThis = isUploadingFile && uploadingForCriterion == criterionName;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // اسم المعيار
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(criterionName,
                                  style: const TextStyle(color: primaryBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 8),

                            // الملفات المرفوعة
                            ...files.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final file = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _openPickedFile(file),
                                      child: Text(file['name'] as String,
                                          style: const TextStyle(
                                            color: Colors.white, fontSize: 12,
                                            decoration: TextDecoration.underline,
                                            decorationColor: Colors.white54,
                                          ),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setSheetState(() {
                                      criteriaFiles[criterionName]!.removeAt(idx);
                                    }),
                                    child: const Icon(Icons.close, color: Colors.grey, size: 16),
                                  ),
                                ]),
                              );
                            }),

                            // زر إضافة ملف
                            GestureDetector(
                              onTap: isLoadingThis ? null : () => pickFileForCriterion(criterionName),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: files.isEmpty ? Colors.white12 : primaryBlue.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: isLoadingThis
                                    ? const Center(child: SizedBox(width: 18, height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)))
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            files.isEmpty ? Icons.upload_file_outlined : Icons.add,
                                            color: files.isEmpty ? Colors.grey : primaryBlue,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            files.isEmpty
                                                ? 'Upload PDF for $criterionName'
                                                : '+ Add another file',
                                            style: TextStyle(
                                                color: files.isEmpty ? Colors.grey : primaryBlue,
                                                fontSize: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.bar_chart_rounded, color: primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        '$totalUploaded file(s) uploaded  •  AI will read & score each',
                        style: const TextStyle(color: Colors.grey, fontSize: 12.5),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isSubmitting ? null : () async {
                        if (priceController.text.isEmpty || descController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all fields')));
                          return;
                        }

                        // تحقق أن كل معيار عنده ملف واحد على الأقل
                        final missing = criteria.where((c) =>
                            (criteriaFiles[c] ?? []).isEmpty).toList();
                        if (missing.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please upload files for: ${missing.join(', ')}')));
                          return;
                        }

                        setSheetState(() => isSubmitting = true);
                        try {
                          final userId = supabase.auth.currentUser!.id;

                          // ─── AI يقرأ الملفات ويحسب الـ Score ───
                          final score = await _computeAiScore(
                            criteriaFiles: criteriaFiles,
                            rfpDescription: _rfp?['description'] ?? '',
                            evaluationCriteria: _rfp?['evaluationCriteria'] ?? '',
                          );
                          debugPrint('=== SCORE TO SAVE: $score ===');

                          final criteriaResponse = criteriaFiles.entries
                              .map((e) => '${e.key}: ${e.value.map((f) => f['name']).join(', ')}')
                              .join(' | ');

                          final proposalResult = await supabase.from('proposals').insert({
                            'RFP': widget.rfpId,
                            'submitterUserId': userId,
                            'proposedPrice': double.tryParse(priceController.text) ?? 0,
                            'description': descController.text.trim(),
                            'status': 'Submitted',
                            'score': score,
                            'submitDate': DateTime.now().toIso8601String().split('T')[0],
                            'comments': criteriaResponse.isEmpty ? null : criteriaResponse,
                          }).select('ProposalID').single();

                          final proposalId = proposalResult['ProposalID'];

                          // حفظ كل الملفات
                          for (final entry in criteriaFiles.entries) {
                            for (final file in entry.value) {
                              await supabase.from('Document').insert({
                                'fullName': file['name'],
                                'fileURL': file['url'],
                                'uploadDate': DateTime.now().toIso8601String().split('T')[0],
                                'uploader': userId,
                                'proposalID': proposalId,
                                'uploadType': 'Proposal_Attachment',
                              });
                            }
                          }

                          final userData = await supabase.from('User')
                              .select('username').eq('id', userId).single();
                          await _notifyManager(userData['username'] ?? 'A contractor');

                          if (mounted) {
                            Navigator.pop(ctx);
                            setState(() => _hasSubmitted = true);
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FinalTotalScoreScreen(
                                contractorName: userData['username'] ?? 'Contractor',
                                score: score,
                                proposalId: proposalId.toString(),
                              ),
                            ));
                          }
                        } catch (e) {
                          debugPrint('=== SUBMIT ERROR: $e ===');
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        } finally {
                          setSheetState(() => isSubmitting = false);
                        }
                      },
                      child: isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                SizedBox(width: 12),
                                Text('AI is reading files...', style: TextStyle(color: Colors.white)),
                              ],
                            )
                          : const Text('Submit Proposal',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        title: const Text('RFP Details', style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : _rfp == null
              ? const Center(child: Text('RFP not found', style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_rfp!['title'] ?? 'Untitled',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Open for Proposals',
                                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 20),
                      _buildSectionTitle('Key Information'),
                      _buildInfoCard([
                        _buildInfoRow(Icons.attach_money, 'Budget', _rfp!['budget'] != null ? '\$${_rfp!['budget']}' : '—'),
                        _buildInfoRow(Icons.calendar_today, 'Deadline', _rfp!['deadline'] ?? '—'),
                        _buildInfoRow(Icons.date_range, 'Posted', _rfp!['creationDate'] ?? '—'),
                        if (_rfp!['requiredTag'] != null) _buildInfoRow(Icons.label_outline, 'Category', _rfp!['requiredTag']),
                      ]),

                      const SizedBox(height: 20),
                      _buildSectionTitle('Description'),
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                        child: Text(_rfp!['description'] ?? 'No description provided.',
                            style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 14)),
                      ),

                      if (_criteriaNames.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildSectionTitle('Evaluation Criteria'),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                          child: Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _criteriaNames.map((name) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: primaryBlue.withOpacity(0.3)),
                              ),
                              child: Text(name, style: const TextStyle(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                            )).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),

                      if (_hasSubmitted) ...[
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Proposal Already Submitted', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        if (_submittedProposal != null)
                          SizedBox(
                            width: double.infinity, height: 50,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: primaryBlue), foregroundColor: primaryBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Review My Proposal', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ContractorProposalDetailsScreen(proposal: _submittedProposal!),
                              )),
                            ),
                          ),
                      ] else
                        SizedBox(
                          width: double.infinity, height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: _showSubmitProposalSheet,
                            child: const Text('Submit Proposal',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)));

  Widget _buildInfoCard(List<Widget> rows) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(children: rows));

  Widget _buildInfoRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: Colors.grey, size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      ]));
}