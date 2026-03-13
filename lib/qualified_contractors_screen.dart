import 'package:flutter/material.dart';

// استيراد صفحة المعايير (تأكد من مطابقة اسم الملف)
import 'criteria_selection_screen.dart';

class QualifiedContractorsScreen extends StatelessWidget {
  const QualifiedContractorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219), // نفس خلفيتك
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Qualified Contractors",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search by contractor name...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1C242F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildContractorRow(context, "Innovate Construction", "92%"),
            _buildContractorRow(context, "BuildRight Inc.", "89%"),
            _buildContractorRow(
              context,
              "Apex Solutions",
              "85%",
              isInvited: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractorRow(
    BuildContext context,
    String name,
    String score, {
    bool isInvited = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF1C242F),
            radius: 20,
            child: Icon(Icons.person, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Overall Score: $score",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isInvited
                  ? Colors.grey.withOpacity(0.1)
                  : const Color(0xFF3395FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: isInvited
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CriteriaSelectionScreen(contractorName: name),
                      ),
                    );
                  },
            child: Text(
              isInvited ? "Invited" : "Invite",
              style: TextStyle(
                color: isInvited ? Colors.white38 : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
