import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_rfp_screen.dart';
import 'review_publish_screen.dart';
import '../main.dart';

class RFPDetailsScreen extends StatefulWidget {
  final String rfpId;
  const RFPDetailsScreen({super.key, required this.rfpId});

  @override
  State<RFPDetailsScreen> createState() => _RFPDetailsScreenState();
}

class _RFPDetailsScreenState extends State<RFPDetailsScreen> {
  static const Color bgColor = Color(0xFF0D1219);
  static const Color fieldColor = Color(0xFF1C242F);
  static const Color primaryBlue = Color(0xFF3395FF);

  Map<String, dynamic>? _rfp;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadRFP();
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading RFP: $e')));
    }
  }

  Future<void> _cancelRFP() async {
    setState(() => _isDeleting = true);
    try {
      await supabase
          .from('RFP')
          .update({'status': 'Cancelled'})
          .eq('rfpID', widget.rfpId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RFP has been cancelled.')),
        );
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: fieldColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 20),
              const Text(
                "Cancel RFP?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "This RFP status will be changed to 'Cancelled'. Are you sure?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D3748),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "No, keep it",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cancelRFP();
                      },
                      child: const Text(
                        "Yes, Cancel",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: fieldColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rfp!['title'] ?? 'Untitled',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusBadge(_rfp!['status']),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  _buildSectionTitle("Summary"),
                  _buildContentBox(
                    _rfp!['description'] ?? 'No description provided.',
                  ),

                  const SizedBox(height: 25),
                  _buildSectionTitle("Key Information"),
                  _buildKeyInfoRow(
                    "RFP ID",
                    '#${widget.rfpId.substring(0, widget.rfpId.length.clamp(0, 8)).toUpperCase()}',
                  ),
                  _buildKeyInfoRow(
                    "Estimated Budget",
                    _rfp!['budget'] != null ? '\$${_rfp!['budget']}' : '—',
                  ),
                  _buildKeyInfoRow("Deadline", _rfp!['deadline'] ?? '—'),
                  _buildKeyInfoRow("Created", _rfp!['creationDate'] ?? '—'),

                  if (_rfp!['evaluationCriteria'] != null) ...[
                    const SizedBox(height: 25),
                    _buildSectionTitle("Evaluation Criteria"),
                    _buildContentBox(_rfp!['evaluationCriteria']),
                  ],

                  const SizedBox(height: 40),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildActionButtons() {
    final status = _rfp!['status'];

    if (status == 'Published') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(
              'RFP is Published — Visible to Contractors',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        _buildActionButton(
          Icons.delete_outline,
          Colors.red,
          isIconOnly: true,
          isLoading: _isDeleting,
          onTap: _showCancelDialog,
        ),
        const SizedBox(width: 12),

        Expanded(
          child: _buildActionButton(
            null,
            Colors.white,
            label: "Edit",
            btnColor: const Color(0xFF252B35),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateRFPScreen(
                    // ✅ نمرر كل البيانات
                    initialTitle: _rfp!['title'],
                    initialBudget: _rfp!['budget']?.toString(),
                    initialDescription: _rfp!['description'],
                    initialDeadline: _rfp!['deadline'],
                    initialEvaluationCriteria: _rfp!['evaluationCriteria'],
                    initialRequiredTag: _rfp!['requiredTag'],
                    rfpId: widget.rfpId, // ✅ عشان يعرف يعدّل مو يضيف جديد
                  ),
                ),
              );
              _loadRFP();
            },
          ),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: _buildActionButton(
            null,
            Colors.white,
            label: "Publish",
            btnColor: primaryBlue,
            isLoading: false,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewPublishScreen(rfpId: widget.rfpId),
                ),
              );
              _loadRFP();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color;
    switch (status) {
      case 'Published':
        color = Colors.green;
        break;
      case 'In Review':
        color = Colors.orange;
        break;
      case 'Cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Status: ${status ?? 'Draft'}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildContentBox(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF161D27),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 14),
    ),
  );

  Widget _buildKeyInfoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );

  Widget _buildActionButton(
    IconData? icon,
    Color color, {
    bool isIconOnly = false,
    String? label,
    Color? btnColor,
    bool isLoading = false,
    required VoidCallback onTap,
  }) => Container(
    height: 55,
    decoration: BoxDecoration(
      color: btnColor ?? color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : isIconOnly
            ? Icon(icon, color: color)
            : Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ),
  );
}
