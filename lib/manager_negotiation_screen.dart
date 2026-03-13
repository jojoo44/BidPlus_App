import 'package:flutter/material.dart';
import 'qualified_contractors_screen.dart';

// تعريف الألوان بناءً على صورك
class AppColors {
  static const Color background = Color(0xFF0B1015); // الخلفية الداكنة جداً
  static const Color surface = Color(0xFF161B22); // لون الكروت (Cards)
  static const Color primaryPurple = Color(
    0xFF6342E8,
  ); // البنفسجي حق Suggestion
  static const Color accentBlue = Color(0xFF2188FF); // الأزرق حق Create New RFP
  static const Color textGrey = Color(0xFF8B949E); // الرمادي للنصوص الفرعية
}

class NegotiationArchiveScreen extends StatelessWidget {
  const NegotiationArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "AI Negotiation Archive",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.white),
          ),
          const CircleAvatar(
            radius: 15,
            backgroundImage: NetworkImage('https://via.placeholder.com/150'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // إحصائيات سريعة تشبه نمط الداشبورد حقك
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildMiniStat("Active", "4"),
                const SizedBox(width: 12),
                _buildMiniStat("Completed", "18"),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              "Recent Negotiations",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) {
                return _buildNegotiationItem(
                  title: "Modern Villa Project",
                  contractor: "Al-Fardan Contracting",
                  status: index % 2 == 0 ? "In Progress" : "Closed",
                  price: "\$50,000",
                );
              },
            ),
          ),
        ],
      ),

      // زر بدء محادثة جديدة بنفس لون زر "Create New RFP" في صورتك
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const QualifiedContractorsScreen(),
            ),
          );
          // هنا تربط واجهة دعوة المقاولين
        },
        backgroundColor: AppColors.accentBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "New Negotiation",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNegotiationItem({
    required String title,
    required String contractor,
    required String status,
    required String price,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.handshake_outlined,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contractor,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  color: status == "In Progress"
                      ? Colors.orangeAccent
                      : AppColors.textGrey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
