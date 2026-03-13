import 'package:flutter/material.dart';
import 'manager_negotiation_screen.dart';
import 'rfp_details_screen.dart';
import '../main.dart';

class ActiveRFPDetailsScreen extends StatefulWidget {
  const ActiveRFPDetailsScreen({super.key});

  @override
  State<ActiveRFPDetailsScreen> createState() => _ActiveRFPDetailsScreenState();
}

class _ActiveRFPDetailsScreenState extends State<ActiveRFPDetailsScreen> {
  List<Map<String, dynamic>> _activeRFPs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveRFPs();
  }

  // ============================================
  // جيب الـ RFPs المنشورة للمنجر الحالي
  // ============================================
  Future<void> _loadActiveRFPs() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('RFP')
          .select()
          .eq('creatorUser', userId)
          .eq('status', 'Published')
          .order('creationDate', ascending: false);

      if (mounted) {
        setState(() {
          _activeRFPs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Active RFPs", style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3395FF)),
            )
          : _activeRFPs.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadActiveRFPs,
              color: const Color(0xFF3395FF),
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _activeRFPs.length,
                itemBuilder: (context, index) {
                  final rfp = _activeRFPs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildRFPCard(rfp),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildRFPCard(Map<String, dynamic> rfp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C242F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان والـ status
          Row(
            children: [
              Expanded(
                child: Text(
                  rfp['title'] ?? 'Untitled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Published',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // معلومات سريعة
          if (rfp['budget'] != null)
            _buildInfoChip(
              Icons.attach_money,
              '\$${rfp['budget']}',
              Colors.blue,
            ),
          const SizedBox(height: 6),
          if (rfp['deadline'] != null)
            _buildInfoChip(
              Icons.calendar_today,
              'Deadline: ${rfp['deadline']}',
              Colors.orange,
            ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // أزرار الإجراءات
          Row(
            children: [
              // زر التفاصيل
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RFPDetailsScreen(rfpId: rfp['rfpID'].toString()),
                    ),
                  ),
                  icon: const Icon(
                    Icons.info_outline,
                    color: Colors.white70,
                    size: 16,
                  ),
                  label: const Text(
                    'Details',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // زر التفاوض
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NegotiationArchiveScreen(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.blue,
                    size: 16,
                  ),
                  label: const Text(
                    'AI Negotiate',
                    style: TextStyle(color: Colors.blue, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) => Row(
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(color: color, fontSize: 13)),
    ],
  );

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.rocket_launch_outlined, color: Colors.grey, size: 48),
        const SizedBox(height: 12),
        const Text(
          'No active RFPs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Publish an RFP to see it here',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    ),
  );
}
