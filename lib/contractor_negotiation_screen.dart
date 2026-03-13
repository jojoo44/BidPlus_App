import 'package:flutter/material.dart';
// تأكدي أن هذا الملف موجود بنفس الاسم في مجلدك
import 'contractor_contract_review.dart';

class ContractorNegotiationScreen extends StatefulWidget {
  const ContractorNegotiationScreen({super.key});

  @override
  State<ContractorNegotiationScreen> createState() =>
      _ContractorNegotiationScreenState();
}

class _ContractorNegotiationScreenState
    extends State<ContractorNegotiationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.addAll([
      ChatMessage(
        text:
            "We've reviewed your proposal. We can offer \$42,500 for the project, with a 60-day timeline. Let me know your thoughts",
        isManager: true,
        time: "2:15 PM",
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1F3A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Downtown Office Renovation',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              'John Doe • Active Only',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Project Details Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A2C47),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price:',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: '\$44,500',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: ' vs. \$50,000',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Timeline:',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: '60 Days',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: ' vs. 45 Days',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatBubble(
                  message: message.text,
                  isManager: message.isManager,
                  time: message.time,
                );
              },
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showCounterOfferDialog,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Counter Offer',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showAcceptDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Accept Offer',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A2C47),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F1F3A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      if (_messageController.text.isNotEmpty) {
                        setState(() {
                          _messages.add(
                            ChatMessage(
                              text: _messageController.text,
                              isManager: false,
                              time: "Now",
                            ),
                          );
                          _messageController.clear();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAcceptDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2C47),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Accept Offer',
          style: TextStyle(color: Colors.white),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accepting this offer will extract the final terms for the contract:',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 15),
            Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'Final Price: \$44,500',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Timeline: 60 Days',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // إغلاق التنبيه
              // الانتقال لصفحة مراجعة العقد الرسمية
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContractorContractReviewScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Confirm & Review Contract',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showCounterOfferDialog() {
    // كود التفاوض
  }
}

// الويجيتس المساعدة
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isManager;
  final String time;
  const ChatBubble({
    super.key,
    required this.message,
    required this.isManager,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isManager ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isManager ? const Color(0xFF1A2C47) : Colors.blue.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isManager;
  final String time;
  ChatMessage({
    required this.text,
    required this.isManager,
    required this.time,
  });
}
