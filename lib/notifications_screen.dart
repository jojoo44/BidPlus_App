import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          _buildNotificationCard(
            "New Proposal Received",
            "From: ABC Construction - Downtown Project",
            "5m ago",
            true,
          ),
          _buildNotificationCard(
            "Contract Signed",
            "The contract for 'Villa Renovation' is now active.",
            "1h ago",
            true,
          ),
          _buildNotificationCard(
            "Negotiation Update",
            "Contractor sent a new counter-offer.",
            "Yesterday",
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    String title,
    String subtitle,
    String time,
    bool isUnread,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212A),
        borderRadius: BorderRadius.circular(16),
        border: isUnread
            ? Border.all(color: Colors.blue.withOpacity(0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: isUnread
                ? Colors.blue.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            child: Icon(
              Icons.notifications_none,
              color: isUnread ? Colors.blue : Colors.grey,
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}
