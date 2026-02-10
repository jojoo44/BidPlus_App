import 'package:flutter/material.dart';
import 'create_rfp_screen.dart';
import 'review_publish_screen.dart';

class RFPDetailsScreen extends StatelessWidget {
  const RFPDetailsScreen({super.key});

  // 1. دالة إظهار نافذة التأكيد عند الحذف (Cancel RFP)
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1C242F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // أيقونة الإكس الحمراء
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
                  "If you cancel this RFP, its status will be changed to 'Cancelled'. Are you sure you want to proceed?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
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
                        onPressed: () => Navigator.pop(context),
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
                          // هنا يتم الحذف الفعلي
                          Navigator.pop(context);
                          Navigator.pop(context);
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0D1219);
    const Color fieldColor = Color(0xFF1C242F);
    const Color primaryBlue = Color(0xFF3395FF);

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة العنوان والحالة
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
                  const Text(
                    "New Website Redesign Project",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Status: Draft",
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            _buildSectionTitle("Summary"),
            _buildContentBox(
              "This RFP outlines the requirements for a complete overhaul of our corporate website...",
            ),

            const SizedBox(height: 25),
            _buildSectionTitle("Key Information"),
            _buildKeyInfoRow("Client Name", "Innovate Corp."),
            _buildKeyInfoRow("Project ID", "RFP-2024-001"),
            _buildKeyInfoRow("Estimated Budget", "\$150,000"),

            const SizedBox(height: 40),

            // صف الأزرار (حذف، تعديل، نشر)
            Row(
              children: [
                // 2. زر الحذف (السلة)
                _buildActionButton(
                  Icons.delete_outline,
                  Colors.red,
                  isIconOnly: true,
                  onTap: () => _showDeleteConfirmation(context),
                ),
                const SizedBox(width: 12),

                // 3. زر التعديل (Edit)
                Expanded(
                  child: _buildActionButton(
                    null,
                    Colors.white,
                    label: "Edit",
                    textColor: Colors.white,
                    btnColor: const Color(0xFF252B35),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateRFPScreen(
                            initialTitle: "New Website Redesign Project",
                            initialBudget: "150,000",
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // 4. زر النشر (Publish)
                Expanded(
                  child: _buildActionButton(
                    null,
                    Colors.white,
                    label: "Publish",
                    btnColor: primaryBlue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReviewPublishScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- عناصر مساعدة للتصميم ---

  Widget _buildSectionTitle(String title) {
    return Padding(
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
  }

  Widget _buildContentBox(String text) {
    return Container(
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
  }

  Widget _buildKeyInfoRow(String label, String value) {
    return Padding(
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
  }

  Widget _buildActionButton(
    IconData? icon,
    Color color, {
    bool isIconOnly = false,
    String? label,
    Color? textColor,
    Color? btnColor,
    required VoidCallback onTap, // جعل الـ onTap مطلوب لضمان الربط
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: btnColor ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap, // هنا يتم استلام الحدث
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: isIconOnly
              ? Icon(icon, color: color)
              : Text(
                  label!,
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
