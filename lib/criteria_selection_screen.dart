import 'package:flutter/material.dart';
import 'negotiation_screen.dart';

class CriteriaSelectionScreen extends StatefulWidget {
  final String contractorName; // هذا السطر الضروري لاستقبال الاسم

  const CriteriaSelectionScreen({super.key, required this.contractorName});

  @override
  State<CriteriaSelectionScreen> createState() =>
      _CriteriaSelectionScreenState();
}

class _CriteriaSelectionScreenState extends State<CriteriaSelectionScreen> {
  // هنا نضع قائمة الشروط
  final Map<String, bool> _criteria = {
    "Total Project Cost": true,
    "Project Deadline": false,
    "Maintenance Period": false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Negotiation Setup",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // هنا نستخدم الاسم اللي مررناه باستخدام widget.contractorName
            Text(
              "Defining terms for: ${widget.contractorName}",
              style: const TextStyle(
                color: Color(0xFF3395FF),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: ListView(
                children: _criteria.keys.map((String key) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C242F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _criteria[key]!
                            ? const Color(0xFF3395FF)
                            : Colors.transparent,
                      ),
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        key,
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: _criteria[key],
                      activeColor: const Color(0xFF3395FF),
                      onChanged: (bool? value) {
                        setState(() {
                          _criteria[key] = value!;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            // زر البدء النهائي باللون الأزرق
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
                  // نجمع فقط المعايير التي تم اختيارها (التي قيمتها true)
                  List<String> selected = _criteria.entries
                      .where((e) => e.value)
                      .map((e) => e.key)
                      .toList();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AINegotiationScreen(
                        contractorName: widget.contractorName,
                        selectedCriteria: selected,
                        proposalId: "proposal_001", // 👈 أضفناه
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Start AI Negotiation",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
