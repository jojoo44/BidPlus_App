// criteria_selection_screen.dart
import 'package:flutter/material.dart';
import 'negotiation_screen.dart';

class CriteriaSelectionScreen extends StatefulWidget {
  final String contractorName;
  final String proposalId;
  final String sessionId;
  final String rfpId;
  final String rfpTitle;

  const CriteriaSelectionScreen({
    super.key,
    required this.contractorName,
    this.proposalId = '',
    this.sessionId = '',
    this.rfpId = '',
    this.rfpTitle = '',
  });

  @override
  State<CriteriaSelectionScreen> createState() =>
      _CriteriaSelectionScreenState();
}

class _CriteriaSelectionScreenState extends State<CriteriaSelectionScreen> {
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
                  final selected = _criteria.entries
                      .where((e) => e.value)
                      .map((e) => e.key)
                      .toList();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AINegotiationScreen(
                        contractorName: widget.contractorName,
                        selectedCriteria: selected,
                        proposalId: widget.proposalId,
                        sessionId: widget.sessionId,
                        rfpId: widget.rfpId,
                        rfpTitle: widget.rfpTitle.isEmpty
                            ? widget.contractorName
                            : widget.rfpTitle,
                        isManager: true,
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