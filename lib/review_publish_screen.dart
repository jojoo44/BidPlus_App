import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class ReviewPublishScreen extends StatefulWidget {
  final String rfpId; // ← استقبل الـ ID
  const ReviewPublishScreen({super.key, required this.rfpId});

  @override
  State<ReviewPublishScreen> createState() => _ReviewPublishScreenState();
}

class _ReviewPublishScreenState extends State<ReviewPublishScreen> {
  static const Color bgColor = Color(0xFF0D1219);
  static const Color cardColor = Color(0xFF1C242F);
  static const Color primaryBlue = Color(0xFF3395FF);

  Map<String, dynamic>? _rfp;
  bool _isLoading = true;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _loadRFP();
  }

  // ============================================
  // جيب بيانات الـ RFP
  // ============================================
  Future<void> _loadRFP() async {
    try {
      final data = await supabase
          .from('RFP')
          .select()
          .eq('rfpID', widget.rfpId)
          .single();
      if (mounted) {
        setState(() {
          _rfp = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================
  // تحقق من الـ RFP قبل النشر
  // ============================================
  List<String> get _validationErrors {
    if (_rfp == null) return [];
    final errors = <String>[];
    if ((_rfp!['title'] ?? '').isEmpty) errors.add('RFP Title is missing.');
    if ((_rfp!['description'] ?? '').isEmpty) {
      errors.add('Description is missing.');
    }
    if (_rfp!['budget'] == null) errors.add('Budget is missing.');
    if (_rfp!['deadline'] == null) errors.add('Due Date is missing.');
    if ((_rfp!['evaluationCriteria'] ?? '').isEmpty) {
      errors.add('Evaluation Criteria is missing.');
    }

    // تحقق إن الـ deadline مو في الماضي
    if (_rfp!['deadline'] != null) {
      final deadline = DateTime.tryParse(_rfp!['deadline']);
      if (deadline != null && deadline.isBefore(DateTime.now())) {
        errors.add('Due Date is in the past.');
      }
    }
    return errors;
  }

  // ============================================
  // نشر الـ RFP
  // ============================================
  Future<void> _publishRFP() async {
    if (_validationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors before publishing.'),
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);
    try {
      await supabase
          .from('RFP')
          .update({'status': 'Published'})
          .eq('rfpID', widget.rfpId);

      // أضف notification
      await supabase.from('Notification').insert({
        'userID': supabase.auth.currentUser!.id,
        'message':
            'RFP "${_rfp!['title']}" has been published. Contractors can now view it.',
        'readStatus': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // ============================================
  // UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Review & Publish RFP',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بانر الأخطاء — يظهر فقط لو في مشاكل
                  if (_validationErrors.isNotEmpty) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: 20),
                  ],

                  // بانر جاهز للنشر
                  if (_validationErrors.isEmpty) ...[
                    _buildReadyBanner(),
                    const SizedBox(height: 20),
                  ],

                  _buildSectionTitle("RFP Summary"),

                  // معلومات عامة
                  _buildSummaryExpansionTile("General Information", [
                    _buildInfoRow("RFP Title", _rfp!['title'] ?? '—'),
                    _buildInfoRow("Status", _rfp!['status'] ?? '—'),
                    _buildInfoRow("Created", _rfp!['creationDate'] ?? '—'),
                  ]),

                  // تواريخ
                  _buildSummaryExpansionTile("Key Dates", [
                    _buildInfoRow("Deadline", _rfp!['deadline'] ?? '—'),
                  ]),

                  // مالية
                  _buildSummaryExpansionTile("Budget", [
                    _buildInfoRow(
                      "Estimated Budget",
                      _rfp!['budget'] != null ? '\$${_rfp!['budget']}' : '—',
                    ),
                  ]),

                  // معايير التقييم
                  _buildSummaryExpansionTile("Evaluation Criteria", [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _rfp!['evaluationCriteria'] ?? '—',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ]),

                  // وصف
                  _buildSummaryExpansionTile("Description", [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _rfp!['description'] ?? '—',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 40),

                  // زر Edit
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Edit RFP",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // زر Publish
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _validationErrors.isNotEmpty
                            ? Colors.grey
                            : primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isPublishing || _validationErrors.isNotEmpty
                          ? null
                          : _publishRFP,
                      child: _isPublishing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Publish RFP",
                              style: TextStyle(
                                color: Colors.white,
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

  // ============================================
  // Widgets مساعدة
  // ============================================
  Widget _buildErrorBanner() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.1),
      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Please fix the issues before publishing:",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        ..._validationErrors.map(
          (e) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  e,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildReadyBanner() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.green.withOpacity(0.1),
      border: Border.all(color: Colors.green.withOpacity(0.4)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.check_circle, color: Colors.green),
        SizedBox(width: 10),
        Text(
          "RFP is ready to publish!",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Widget _buildSummaryExpansionTile(String title, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          iconColor: Colors.white,
          collapsedIconColor: Colors.grey,
          childrenPadding: const EdgeInsets.all(15),
          children: children,
        ),
      );

  Widget _buildInfoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      title,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Published!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your RFP is now visible to contractors.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx); // أغلق الديالوج
                  Navigator.pop(context); // ارجع لـ RFP Details
                  Navigator.pop(context); // ارجع للداشبورد
                },
                child: const Text(
                  "Back to Dashboard",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
