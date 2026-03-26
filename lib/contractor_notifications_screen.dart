import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'contractor_negotiation_archive_screen.dart';
import 'contractor_rfp_details_screen.dart';
import 'contractor_proposal_details_screen.dart';
import '../main.dart';

class ContractorNotificationsScreen extends StatefulWidget {
  const ContractorNotificationsScreen({super.key});

  @override
  State<ContractorNotificationsScreen> createState() =>
      _ContractorNotificationsScreenState();
}

class _ContractorNotificationsScreenState
    extends State<ContractorNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await supabase
          .from('Notification')
          .select()
          .eq('userID', userId)
          .order('timeStamp', ascending: false);
      if (mounted) setState(() {
        _notifications = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('Notification')
          .update({'readStatus': true}).eq('userID', userId);
      _loadNotifications();
    } catch (_) {}
  }

  Future<void> _markAsRead(dynamic id) async {
    try {
      await supabase.from('Notification')
          .update({'readStatus': true}).eq('notificationID', id);
    } catch (_) {}
  }

  // توجيه حسب نوع الإشعار والـ relatedID
  Future<void> _handleTap(Map<String, dynamic> n) async {
    if (n['readStatus'] == false) await _markAsRead(n['notificationID']);
    _loadNotifications();

    final type      = (n['type'] ?? '').toString().toLowerCase();
    final relatedId = n['relatedID']?.toString();

    print('🔔 Notification tap: type=$type, relatedId=$relatedId');

    if (!mounted) return;

    if (type.contains('rfp')) {
      if (relatedId != null) {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => ContractorRFPDetailsScreen(rfpId: relatedId)));
      }
    } else if (type.contains('accepted') || type.contains('rejected') ||
               type.contains('review')) {
      if (relatedId != null) {
        try {
          final proposal = await supabase
              .from('proposals_with_username')
              .select('*, RFP(title, rfpID)')
              .eq('ProposalID', int.parse(relatedId))
              .single();
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => ContractorProposalDetailsScreen(
                    proposal: proposal)));
          }
        } catch (e) {
          print('proposal fetch error: $e');
        }
      }
      // إشعار قديم بدون relatedID — لا يفعل شي
    } else if (type.contains('negotiation')) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => const ContractorNegotiationArchiveScreen()));
    }
  }

  IconData _getIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('negotiation')) return Icons.handshake_outlined;
    if (t.contains('accepted'))    return Icons.check_circle_outline;
    if (t.contains('rejected'))    return Icons.cancel_outlined;
    if (t.contains('review'))      return Icons.hourglass_top;
    if (t.contains('rfp'))         return Icons.work_outline;
    return Icons.notifications_none;
  }

  Color _getColor(String type, bool isUnread) {
    final t = type.toLowerCase();
    if (t.contains('accepted'))    return Colors.green;
    if (t.contains('rejected'))    return Colors.red;
    if (t.contains('negotiation')) return Colors.orange;
    if (t.contains('review'))      return Colors.blue;
    if (t.contains('rfp'))         return Colors.purple;
    return isUnread ? Colors.blue : Colors.grey;
  }

  String _timeAgo(String? ts) {
    if (ts == null) return '—';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1F3A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('mark all as read',
                style: TextStyle(color: Colors.blue, fontSize: 13)),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF12141D),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _notifications.isEmpty
              ? const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        color: Colors.grey, size: 48),
                    SizedBox(height: 12),
                    Text('No notifications yet',
                        style: TextStyle(color: Colors.grey)),
                  ]))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: Colors.blue,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, i) {
                      final n        = _notifications[i];
                      final isUnread = n['readStatus'] == false;
                      final type     = n['type'] ?? '';
                      final color    = _getColor(type, isUnread);
                      final icon     = _getIcon(type);

                      return InkWell(
                        onTap: () => _handleTap(n),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2C47),
                            borderRadius: BorderRadius.circular(12),
                            border: isUnread
                                ? Border.all(color: color.withOpacity(0.3))
                                : null,
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(type, style: TextStyle(fontSize: 14,
                                  fontWeight: isUnread
                                      ? FontWeight.w700 : FontWeight.w500,
                                  color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(n['message'] ?? '',
                                  style: TextStyle(fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                      height: 1.4)),
                            ])),
                            const SizedBox(width: 8),
                            Column(crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                              Text(_timeAgo(n['timeStamp']),
                                  style: TextStyle(fontSize: 11,
                                      color: Colors.white.withOpacity(0.4))),
                              if (isUnread) ...[
                                const SizedBox(height: 6),
                                Container(width: 8, height: 8,
                                    decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle)),
                              ],
                              const SizedBox(height: 4),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white24, size: 16),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}