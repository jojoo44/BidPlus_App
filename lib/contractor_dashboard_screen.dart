import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'contractor_offers_screen.dart';
import 'contractor_bids_screen.dart';
import 'contractor_tasks_screen.dart';
import 'contractor_notifications_screen.dart';
import 'contractor_negotiation_screen.dart';
import 'contractor_rfp_details_screen.dart'; // شاشة تفاصيل RFP للكونتراكتور
import 'profile_screen.dart';
import 'login_screen.dart';
import '../main.dart';

class ContractorDashboardScreen extends StatefulWidget {
  const ContractorDashboardScreen({super.key});

  @override
  State<ContractorDashboardScreen> createState() =>
      _ContractorDashboardScreenState();
}

class _ContractorDashboardScreenState extends State<ContractorDashboardScreen> {
  int _selectedIndex = 0;
  String _username = 'Contractor';

  // ============================================
  // بيانات حقيقية من Supabase
  // ============================================
  List<Map<String, dynamic>> _publishedRFPs = [];
  bool _isLoadingRFPs = true;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadPublishedRFPs();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ============================================
  // التحقق من الصلاحية
  // ============================================
  Future<void> _checkAuth() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      return;
    }

    final data = await supabase
        .from('User')
        .select('role, username')
        .eq('id', user.id)
        .single();

    if (data['role'] != 'contractor' && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (mounted) setState(() => _username = data['username'] ?? 'Contractor');
  }

  // ============================================
  // جيب الـ RFPs المنشورة
  // ============================================
  Future<void> _loadPublishedRFPs() async {
    try {
      final data = await supabase
          .from('RFP')
          .select()
          .eq('status', 'Published')
          .order('creationDate', ascending: false);

      if (mounted) {
        setState(() {
          _publishedRFPs = List<Map<String, dynamic>>.from(data);
          _isLoadingRFPs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRFPs = false);
    }
  }

  // ============================================
  // Realtime — يتحدث عند نشر RFP جديد
  // ============================================
  void _subscribeRealtime() {
    _realtimeChannel = supabase
        .channel('contractor_rfp_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'RFP',
          callback: (payload) => _loadPublishedRFPs(),
        )
        .subscribe();
  }

  // ============================================
  // UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF12141D);

    return Scaffold(
      backgroundColor: bg,
      body: _selectedIndex == 0
          ? _homeBody()
          : _selectedIndex == 1
          ? const ContractorOffersScreen()
          : _selectedIndex == 2
          ? const ContractorBidsScreen()
          : const ContractorTasksScreen(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F1F3A),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade400,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel_outlined),
            label: 'Bids',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }

  Widget _homeBody() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Welcome, $_username',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white70,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContractorNotificationsScreen(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.person_outline,
                        color: Colors.white70,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(isManager: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Text(
              'Current Projects',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _ProjectCard(
                    title: 'Yasmin Villa',
                    progress: 0.75,
                    progressText: 'In Progress - 75%',
                  ),
                  SizedBox(width: 15),
                  _ProjectCard(
                    title: 'Commerce',
                    progress: 0.40,
                    progressText: 'In Progress - 40%',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ============================================
            // New Bids — بيانات حقيقية من Supabase
            // ============================================
            Row(
              children: [
                const Text(
                  'New Bids',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                // بادج عدد الـ RFPs المتاحة
                if (_publishedRFPs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_publishedRFPs.length} available',
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 15),

            _isLoadingRFPs
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Colors.blue),
                    ),
                  )
                : _publishedRFPs.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2C47),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          color: Colors.grey,
                          size: 36,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No available RFPs right now',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _publishedRFPs
                        .map(
                          (rfp) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BidRow(
                              rfpId: rfp['rfpID'].toString(),
                              title: rfp['title'] ?? 'Untitled',
                              deadline: rfp['deadline'] ?? '—',
                              budget: rfp['budget'],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ContractorRFPDetailsScreen(
                                    rfpId: rfp['rfpID'].toString(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),

            const SizedBox(height: 30),
            const Text(
              'Smart Tools',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 180,
                child: _QuickActionCard(
                  label: 'AI Negotiate',
                  icon: Icons.auto_awesome,
                  iconColor: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ContractorNegotiationScreen(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Widgets المساعدة
// ============================================
class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2C47),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String title;
  final double progress;
  final String progressText;

  const _ProjectCard({
    required this.title,
    required this.progress,
    required this.progressText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progressText,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                color: Colors.blue,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ← عُدّل عشان يعرض بيانات حقيقية ويوجّه للتفاصيل
class _BidRow extends StatelessWidget {
  final String rfpId;
  final String title;
  final String deadline;
  final dynamic budget;
  final VoidCallback onTap;

  const _BidRow({
    required this.rfpId,
    required this.title,
    required this.deadline,
    required this.budget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2C47),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.work_outline,
                color: Colors.blue.shade300,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deadline: $deadline',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  if (budget != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Budget: \$$budget',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 14),
          ],
        ),
      ),
    );
  }
}
