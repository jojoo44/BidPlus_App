import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';
import 'create_rfp_screen.dart';
import 'rfp_details_screen.dart';
import 'proposals_list_screen.dart';
import 'active_rfp_details_screen.dart';
import 'notifications_screen.dart';
import 'negotiation_mng_screen.dart';
import 'contractor_evaluation_screen.dart';
import 'login_screen.dart';
import '../main.dart';

class BidPlus extends StatefulWidget {
  const BidPlus({super.key});
  @override
  State<BidPlus> createState() => _BidPlusState();
}

class _BidPlusState extends State<BidPlus> {
  String selectedFilter = "All";

  // ============================================
  // بيانات حقيقية من Supabase
  // ============================================
  List<Map<String, dynamic>> _rfps = [];
  bool _isLoading = true;
  String _username = '';
  int _activeCount = 0;
  int _pendingCount = 0;
  int _draftCount = 0;

  // Realtime channel
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadData();
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
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    final data = await supabase
        .from('User')
        .select('role, username')
        .eq('id', user.id)
        .single();

    if (data['role'] != 'manager' && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    if (mounted) setState(() => _username = data['username'] ?? 'Manager');
  }

  // ============================================
  // جيب البيانات من Supabase
  // ============================================
  Future<void> _loadData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('RFP')
          .select()
          .eq('creatorUser', userId)
          .order('creationDate', ascending: false);

      final rfps = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          _rfps = rfps;
          _activeCount = rfps.where((r) => r['status'] == 'Published').length;
          _pendingCount = rfps.where((r) => r['status'] == 'In Review').length;
          _draftCount = rfps.where((r) => r['status'] == 'Draft').length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================
  // Realtime — يتحدث فوراً عند أي تغيير في RFP
  // ============================================
  void _subscribeRealtime() {
    _realtimeChannel = supabase
        .channel('rfp_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // INSERT + UPDATE + DELETE
          schema: 'public',
          table: 'RFP',
          callback: (payload) => _loadData(), // أعد التحميل تلقائياً
        )
        .subscribe();
  }

  // ============================================
  // فلترة الـ RFPs
  // ============================================
  List<Map<String, dynamic>> get filteredRFPs {
    if (selectedFilter == "All") return _rfps;
    final map = {
      "Active": "Published",
      "Completed": "Completed",
      "Urgent": "Urgent",
      "In Review": "In Review",
      "Drafts": "Draft",
    };
    final status = map[selectedFilter] ?? selectedFilter;
    return _rfps.where((r) => r['status'] == status).toList();
  }

  double _getProgress(String? status) {
    switch (status) {
      case 'Draft':
        return 0.1;
      case 'Published':
        return 0.4;
      case 'In Review':
        return 0.6;
      case 'Negotiation':
        return 0.75;
      case 'Completed':
        return 1.0;
      default:
        return 0.2;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Published':
        return const Color(0xFF3395FF);
      case 'In Review':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Urgent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ============================================
  // UI
  // ============================================
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
        actions: [_buildNotificationIcon(context), _buildProfileIcon(context)],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData, // سحب لأسفل يحدّث
        color: primaryBlue,
        backgroundColor: cardColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Text(
                _username.isEmpty ? 'Dashboard' : 'Welcome, $_username 👋',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 25),

              // Buttons
              _buildActionButton(
                context,
                "Create New RFP",
                Icons.add,
                primaryBlue,
                () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateRFPScreen()),
                  );
                  _loadData(); // حدّث بعد الرجوع
                },
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
                    builder: (_) => const ProposalsListScreen(),
                  ),
                ),
                isOutlined: true,
              ),

              const SizedBox(height: 30),

              // Stats — أرقام حقيقية
              Row(
                children: [
                  _buildStatCard(
                    context,
                    "Active",
                    _activeCount.toString(),
                    cardColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActiveRFPDetailsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  _buildStatCard(
                    context,
                    "In Review",
                    _pendingCount.toString(),
                    cardColor,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildStatCard(
                context,
                "Drafts",
                _draftCount.toString(),
                cardColor,
                isFullWidth: true,
                onTap: () => setState(() => selectedFilter = "Drafts"),
              ),

              const SizedBox(height: 30),
              Row(
                children: [
                  _buildQuickAction(
                    context,
                    "AI Negotiate",
                    Icons.auto_awesome,
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NegotiationArchiveScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  _buildQuickAction(
                    context,
                    "Rate Team",
                    Icons.star_rate,
                    Colors.amber,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContractorEvaluationScreen(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Recent RFPs header
              Row(
                children: [
                  const Text(
                    'Recent RFPs',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // مؤشر Realtime
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Live',
                          style: TextStyle(color: Colors.green, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    "All",
                    "Active",
                    "Drafts",
                    "Completed",
                    "In Review",
                  ].map(_buildFilterChip).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // List
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: Color(0xFF3395FF),
                        ),
                      ),
                    )
                  : filteredRFPs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredRFPs.length,
                      itemBuilder: (context, index) {
                        final rfp = filteredRFPs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RFPDetailsScreen(
                                    rfpId: rfp['rfpID'].toString(),
                                  ),
                                ),
                              );
                              _loadData(); // حدّث الداشبورد بعد الرجوع
                            },
                            child: _buildRecentRFPCard(
                              cardColor,
                              rfp['title'] ?? 'Untitled',
                              rfp['deadline'] ?? rfp['creationDate'] ?? '—',
                              _getProgress(rfp['status']),
                              _getStatusColor(rfp['status']),
                              rfp['status'] ?? 'Draft',
                              rfp['budget'],
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // Empty State
  // ============================================
  Widget _buildEmptyState() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(40),
    decoration: BoxDecoration(
      color: const Color(0xFF1C242F),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, color: Colors.grey, size: 48),
        const SizedBox(height: 12),
        const Text(
          'No RFPs yet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Create your first RFP to get started',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3395FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateRFPScreen()),
            );
            _loadData();
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Create RFP',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  // ============================================
  // Widgets المساعدة
  // ============================================
  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1C242F),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3395FF) : const Color(0xFF1C242F),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.grey),
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
  }) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      minimumSize: const Size(double.infinity, 55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: onPressed,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );

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
    dynamic budget,
  ) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: progressColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: progressColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (budget != null) ...[
          const SizedBox(height: 5),
          Text(
            'Budget: \$$budget',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
        const SizedBox(height: 5),
        Text(
          'Deadline: $date',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white10,
          color: progressColor,
          minHeight: 5,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    ),
  );

  Widget _buildNotificationIcon(BuildContext context) => IconButton(
    icon: const Icon(Icons.notifications, color: Colors.white),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    ),
  );

  Widget _buildProfileIcon(BuildContext context) => IconButton(
    icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen(isManager: true)),
    ),
  );
}
