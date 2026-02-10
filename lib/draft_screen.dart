import 'package:flutter/material.dart';
import 'rfp_details_screen.dart'; // سننشئ هذا الملف في الخطوة التالية

class DraftsScreen extends StatelessWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // بيانات تجريبية للمسودات
    final List<Map<String, String>> drafts = [
      {"title": "New Website Redesign Project", "date": "12/15/2023"},
      {"title": "Mobile App Development", "date": "01/10/2024"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(
        title: const Text("My Drafts", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: drafts.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // عند الضغط، ننتقل لصفحة التفاصيل التي أرفقتِ صورتها
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RFPDetailsScreen(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C242F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drafts[index]["title"]!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Created: ${drafts[index]["date"]}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
