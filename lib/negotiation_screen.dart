import 'package:flutter/material.dart';
import 'finalize_contract_screen.dart';

class AINegotiationScreen extends StatelessWidget {
  final String contractorName;
  final List<String> selectedCriteria;
  final String proposalId;

  const AINegotiationScreen({
    super.key,
    required this.contractorName,
    required this.selectedCriteria,
    required this.proposalId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          contractorName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              "Negotiable Criteria",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: selectedCriteria
                  .map(
                    (criterion) => Chip(
                      label: Text(
                        criterion,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: const Color(0xFF1C242F),
                      side: const BorderSide(
                        color: Color(0xFF3395FF),
                        width: 0.5,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // زر توليد الاقتراحات (AI Suggestions) - تم استعادته
            // ==========================================
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3395FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // هنا يمكن إضافة أكشن لإظهار كرت اقتراح جديد
                },
                icon: const Icon(Icons.auto_awesome, color: Colors.white),
                label: const Text(
                  "Generate Suggestions",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildSuggestionCard(),
            const Spacer(),
            _buildInputSection(),
            const SizedBox(height: 15),

            // الزر الأخضر للانتقال لصفحة المراجعة
            _buildStatusButton(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C242F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3395FF).withOpacity(0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "AI SUGGESTION",
            style: TextStyle(
              color: Color(0xFF3395FF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Offer \$48,500",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Propose a 3% discount in exchange for a 50% upfront payment.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C242F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.attach_file, color: Colors.grey),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Enter your offer...",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
          Icon(Icons.send, color: Color(0xFF3395FF)),
        ],
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: () {
          // الانتقال لصفحة مراجعة العقد المستخرج
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AIContractReviewScreen(
                contractorName: contractorName,
                proposalId: proposalId,
              ),
            ),
          );
        },
        child: const Text(
          "Negotiation Completed",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// صفحة مراجعة العقد المستخرج (AI Contract Review)
// ============================================================
class AIContractReviewScreen extends StatefulWidget {
  final String contractorName;
  final String proposalId;

  const AIContractReviewScreen({
    super.key,
    required this.contractorName,
    required this.proposalId,
  });

  @override
  State<AIContractReviewScreen> createState() => _AIContractReviewScreenState();
}

class _AIContractReviewScreenState extends State<AIContractReviewScreen> {
  final TextEditingController _priceController = TextEditingController(
    text: "48,500",
  );
  final TextEditingController _durationController = TextEditingController(
    text: "60 Days",
  );
  final TextEditingController _termsController = TextEditingController(
    text:
        "3% discount applied. 50% upfront payment. Maintenance for 12 months included.",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Review Contract Terms"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Review and confirm the terms extracted by AI from the negotiation history.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),

            _buildEditableField(
              "Final Agreed Price (\$)",
              _priceController,
              Icons.monetization_on,
            ),
            const SizedBox(height: 20),
            _buildEditableField(
              "Project Duration",
              _durationController,
              Icons.timer,
            ),
            const SizedBox(height: 20),
            _buildEditableField(
              "Contract Clauses",
              _termsController,
              Icons.article,
              maxLines: 5,
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3395FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FinalizeContractScreen(
                        contractTitle: "Final Project Contract",
                        contractId: widget.proposalId,
                        managerName: "Project Manager",
                        contractorName: widget.contractorName,
                        effectiveDate: DateTime.now().toString().split(' ')[0],
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Finalize Contract",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3395FF),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey, size: 20),
            filled: true,
            fillColor: const Color(0xFF1C242F),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3395FF)),
            ),
          ),
        ),
      ],
    );
  }
}
