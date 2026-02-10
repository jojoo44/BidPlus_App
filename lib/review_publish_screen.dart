import 'package:flutter/material.dart';

class ReviewPublishScreen extends StatelessWidget {
  const ReviewPublishScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0D1219);
    const Color cardColor = Color(0xFF1C242F);
    const Color primaryBlue = Color(0xFF3395FF);

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رسالة التنبيه الحمراء (إذا وجدت أخطاء)
            _buildErrorBanner(),

            const SizedBox(height: 20),
            _buildSectionTitle("Participation Threshold"),
            _buildScoreCard(cardColor),

            const SizedBox(height: 25),
            _buildSectionTitle("RFP Summary"),

            // القوائم المنسدلة للملخص (ExpansionTiles)
            _buildSummaryExpansionTile("General Information", cardColor, [
              _buildInfoRow("RFP Title", "New Website Redesign Project"),
              _buildInfoRow("Project Code", "RFP-2024-001"),
              _buildInfoRow("Department", "IT Operations"),
            ]),
            _buildSummaryExpansionTile("Key Dates", cardColor, []),
            _buildSummaryExpansionTile("Contacts", cardColor, []),
            _buildSummaryExpansionTile("Attachments", cardColor, []),

            const SizedBox(height: 40),

            // أزرار النهاية
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
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _showSuccessDialog(context);
                },
                child: const Text(
                  "Publish RFP",
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
  }

  // --- Widgets المساعدة ---

  Widget _buildErrorBanner() {
    return Container(
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
          _buildErrorItem("Due Date is in the past."),
          _buildErrorItem("Primary Contact is missing."),
        ],
      ),
    );
  }

  Widget _buildErrorItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.redAccent),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Score: 85",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Good",
                    style: TextStyle(color: Colors.green, fontSize: 14),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit, size: 16),
                label: const Text("Adjust Score"),
              ),
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: 0.85,
            backgroundColor: Colors.white10,
            color: Colors.green,
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryExpansionTile(
    String title,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color,
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
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C242F),
        title: const Text("Success!", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Your RFP has been published successfully.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
