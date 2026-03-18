import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'contractor_negotiation_screen.dart';
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
      if (mounted)
        setState(() {
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
      await supabase
          .from('Notification')
          .update({'readStatus': true})
          .eq('userID', userId);
      _loadNotifications();
    } catch (_) {}
  }

  Future<void> _markAsRead(dynamic id) async {
    try {
      await supabase
          .from('Notification')
          .update({'readStatus': true})
          .eq('notificationID', id);
      _loadNotifications();
    } catch (_) {}
  }

  String _timeAgo(String? ts) {
    if (ts == null) return '—';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
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
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'mark all as read',
              style: TextStyle(color: Colors.blue, fontSize: 13),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF12141D),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    color: Colors.grey,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              color: Colors.blue,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                itemBuilder: (context, i) {
                  final n = _notifications[i];
                  final isUnread = n['readStatus'] == false;
                  final type = n['type'] ?? '';
                  final isNegotiation = type.toLowerCase().contains(
                    'negotiation',
                  );
                  return InkWell(
                    onTap: () {
                      if (isUnread) _markAsRead(n['notificationID']);
                      if (isNegotiation) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContractorNegotiationScreen(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2C47),
                        borderRadius: BorderRadius.circular(12),
                        border: isNegotiation
                            ? Border.all(color: Colors.blue.withOpacity(0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isNegotiation
                                    ? Colors.orange
                                    : Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isNegotiation)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Icon(
                                          Icons.handshake_outlined,
                                          color: Colors.orange.shade400,
                                          size: 18,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isUnread
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n['message'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _timeAgo(n['timeStamp']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
