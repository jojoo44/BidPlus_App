import 'package:flutter/material.dart';
import 'contractor_negotiation_screen.dart';

class ContractorNotificationsScreen extends StatelessWidget {
  const ContractorNotificationsScreen({super.key});

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
            onPressed: () {},
            child: const Text(
              'mark all as read',
              style: TextStyle(color: Colors.blue, fontSize: 13),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          NotificationItem(
            title: 'New Negotiation Invitation',
            subtitle: 'Project: Downtown Office Renovation',
            time: '2m ago',
            isUnread: true,
            isNegotiation: true,
          ),
          NotificationItem(
            title: 'New Proposal Received',
            subtitle: 'From: ABC Construction',
            time: '5m ago',
            isUnread: true,
          ),
          NotificationItem(
            title: 'Contract Sent for Signature',
            subtitle: 'Project: Downtown Office Renovation',
            time: '2h ago',
            isUnread: true,
          ),
          NotificationItem(
            title: 'New Message in Negotiation',
            subtitle: 'Project: Riverside Bridge Repair',
            time: 'Yesterday',
            isUnread: false,
          ),
          NotificationItem(
            title: 'Contract Approved',
            subtitle: 'By: City Council',
            time: '4yr 15',
            isUnread: false,
          ),
          NotificationItem(
            title: 'Proposal Viewed',
            subtitle: 'By: City Planning Department',
            time: '4yr 14',
            isUnread: false,
          ),
        ],
      ),
    );
  }
}

// ==================== Notification Item Widget ====================
class NotificationItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final bool isNegotiation;

  const NotificationItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    this.isNegotiation = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isNegotiation
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContractorNegotiationScreen(),
                ),
              );
            }
          : null,
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
                  color: isNegotiation ? Colors.orange : Colors.blue,
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
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.handshake_outlined,
                            color: Colors.orange.shade400,
                            size: 18,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
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
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
