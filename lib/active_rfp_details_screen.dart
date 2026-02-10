import 'package:flutter/material.dart';

class ManageMyBidsScreen extends StatelessWidget {
  const ManageMyBidsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0D1219);
    const Color cardColor = Color(0xFF1C242F);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Active RFPs',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildActiveBidCard(
            context,
            title: "Website Redesign",
            proposalsCount: "12",
            timeLeft: "3 Days",
            progress: 0.7,
            cardColor: cardColor,
          ),
          _buildActiveBidCard(
            context,
            title: "Cloud Migration",
            proposalsCount: "8",
            timeLeft: "12 Days",
            progress: 0.4,
            cardColor: cardColor,
          ),
          _buildActiveBidCard(
            context,
            title: "Security Audit",
            proposalsCount: "3",
            timeLeft: "1 Day",
            progress: 0.9,
            cardColor: cardColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBidCard(
    BuildContext context, {
    required String title,
    required String proposalsCount,
    required String timeLeft,
    required double progress,
    required Color cardColor,
    bool isExpired = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // السطر الأول: العنوان والحالة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.circle,
                size: 10,
                color: isExpired ? Colors.red : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // السطر الثاني: عدد البروبوزال والوقت المتبقي
          Row(
            children: [
              // عدد البروبوزالات
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proposalsCount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Proposals",
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // الوقت المتبقي
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeLeft,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Remaining",
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // السطر الثالث: شريط التقدم (Progress Bar)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: isExpired ? Colors.red : Colors.blue,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
