import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'create_rfp_screen.dart';
import 'rfp_details_screen.dart';
import 'proposals_list_screen.dart';
import 'active_rfp_details_screen.dart';

class BidPlus extends StatefulWidget {
  const BidPlus({super.key});

  @override
  State<BidPlus> createState() => _BidPlusState();
}

class _BidPlusState extends State<BidPlus> {
  // 1. متغير الحالة للفلتر المختار
  String selectedFilter = "All";

  // 2. قائمة بيانات وهمية (Dummy Data) لتمثيل البدات
  final List<Map<String, dynamic>> allRFPs = [
    {
      "title": "Q3 Marketing Analytics Platform",
      "date": "12/15/2023",
      "progress": 0.6,
      "color": Colors.orange,
      "status": "In Review",
    },
    {
      "title": "Mobile App Redesign",
      "date": "01/20/2024",
      "progress": 0.3,
      "color": const Color(0xFF3395FF),
      "status": "Active",
    },
    {
      "title": "Security Infrastructure",
      "date": "11/05/2023",
      "progress": 1.0,
      "color": Colors.green,
      "status": "Completed",
    },
    {
      "title": "Urgent Server Migration",
      "date": "02/12/2024",
      "progress": 0.8,
      "color": Colors.red,
      "status": "Urgent",
    },
  ];

  // 3. دالة لجلب البيانات بناءً على الفلتر
  List<Map<String, dynamic>> get filteredRFPs {
    if (selectedFilter == "All") return allRFPs;
    return allRFPs.where((rfp) => rfp['status'] == selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0D1219);
    const cardColor = Color(0xFF1C242F);
    const primaryBlue = Color(0xFF3395FF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Bid Plus',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [_buildNotificationIcon(), _buildProfileIcon(context)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 25),

            // أزرار الأكشن السريعة
            _buildActionButton(
              context,
              "Create New RFP",
              Icons.add,
              primaryBlue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateRFPScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              "View All Proposals",
              Icons.laptop_mac,
              cardColor,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProposalsListScreen(),
                ),
              ),
              isOutlined: true,
            ),

            const SizedBox(height: 30),

            // قسم الإحصائيات - عند الضغط على Active يفتح إدارة البدات
            Row(
              children: [
                _buildStatCard(
                  context,
                  "Active",
                  "12",
                  cardColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageMyBidsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 15),
                _buildStatCard(context, "Pending Review", "3", cardColor),
              ],
            ),
            const SizedBox(height: 15),
            _buildStatCard(
              context,
              "Drafts",
              "5",
              cardColor,
              isFullWidth: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RFPDetailsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
            const Text(
              'Recent RFPs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),

            // الفلاتر التفاعلية
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  "All",
                  "Active",
                  "Completed",
                  "Urgent",
                  "In Review",
                ].map((label) => _buildFilterChip(label)).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // قائمة الكروت المفلترة
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredRFPs.length,
              itemBuilder: (context, index) {
                final rfp = filteredRFPs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: _buildRecentRFPCard(
                    cardColor,
                    rfp['title'],
                    rfp['date'],
                    rfp['progress'],
                    rfp['color'],
                    rfp['status'],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- Widgets مساعدة ---

  Widget _buildFilterChip(String label) {
    bool isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3395FF) : const Color(0xFF1C242F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isOutlined = false,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: isOutlined ? BorderSide.none : null,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isOutlined ? Colors.white70 : Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isOutlined ? Colors.white70 : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String count,
    Color color, {
    bool isFullWidth = false,
    VoidCallback? onTap,
  }) {
    Widget card = Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    return isFullWidth
        ? GestureDetector(onTap: onTap, child: card)
        : Expanded(
            child: GestureDetector(onTap: onTap, child: card),
          );
  }

  Widget _buildRecentRFPCard(
    Color color,
    String title,
    String date,
    double progress,
    Color progressColor,
    String status,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Due Date: $date',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: progressColor,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications, color: Colors.white),
        ),
        const Positioned(
          right: 14,
          top: 14,
          child: CircleAvatar(radius: 4, backgroundColor: Colors.red),
        ),
      ],
    );
  }

  Widget _buildProfileIcon(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EditProfileScreen(isManager: true),
        ),
      ),
    );
  }
}
