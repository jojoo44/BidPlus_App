// criteria_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
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
  // ← الجديد: Map ديناميكية بدل الثابتة
  Map<String, bool> _criteria = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ← الجديد: جيب المعايير من الـ RFP
    _loadCriteriaFromRFP();
  }

  // ─────────────────────────────────────────────
  //  جيب المعايير من evaluationCriteria في RFP
  // ─────────────────────────────────────────────
  Future<void> _loadCriteriaFromRFP() async {
    try {
      if (widget.rfpId.isNotEmpty) {
        final rfpData = await supabase
            .from('RFP')
            .select('evaluationCriteria')
            .eq('rfpID', widget.rfpId)
            .maybeSingle();

        final raw = rfpData?['evaluationCriteria'] as String?;

        if (raw != null && raw.isNotEmpty) {
          // Parse "Cost:40%, Experience:60%" → ['Cost', 'Experience']
          final criteriaNames = raw
              .split(',')
              .map((part) {
                final trimmed = part.trim();
                final colonIdx = trimmed.indexOf(':');
                return colonIdx == -1
                    ? trimmed
                    : trimmed.substring(0, colonIdx).trim();
              })
              .where((name) => name.isNotEmpty)
              .toList();

          if (mounted && criteriaNames.isNotEmpty) {
            setState(() {
              // الأول محدد افتراضياً، الباقي غير محددة
              _criteria = {
                for (int i = 0; i < criteriaNames.length; i++)
                  criteriaNames[i]: i == 0,
              };
              _isLoading = false;
            });
            return;
          }
        }
      }

      // Fallback لو ما في rfpId أو ما في معايير
      if (mounted) {
        setState(() {
          _criteria = {
            'Total Project Cost': true,
            'Project Deadline': false,
            'Maintenance Period': false,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('CriteriaSelection error: $e');
      if (mounted) {
        setState(() {
          _criteria = {
            'Total Project Cost': true,
            'Project Deadline': false,
            'Maintenance Period': false,
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Negotiation Setup',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Defining terms for: ${widget.contractorName}',
              style: const TextStyle(
                color: Color(0xFF3395FF),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            // ← الجديد: توضيح إن المعايير من الـ RFP
            if (!_isLoading && widget.rfpId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Based on RFP evaluation criteria',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 25),

            // ← الجديد: Loading state
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF3395FF),
                      ),
                    )
                  : _criteria.isEmpty
                  ? Center(
                      child: Text(
                        'No criteria found',
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    )
                  : ListView(
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
                              setState(() => _criteria[key] = value!);
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
                // ← الجديد: تحقق إن في معيار محدد
                onPressed: _isLoading
                    ? null
                    : () {
                        final selected = _criteria.entries
                            .where((e) => e.value)
                            .map((e) => e.key)
                            .toList();

                        if (selected.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select at least one criterion',
                              ),
                            ),
                          );
                          return;
                        }

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
                  'Start AI Negotiation',
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
