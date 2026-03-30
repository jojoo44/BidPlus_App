// final_total_score_screen.dart
import 'package:flutter/material.dart';
import '../main.dart';
import 'contractor_proposal_details_screen.dart';

class FinalTotalScoreScreen extends StatelessWidget {
  final String contractorName;
  final int score; // 0..100
  final String? proposalId; // ← لمراجعة العرض بعد الإرسال

  const FinalTotalScoreScreen({
    super.key,
    required this.contractorName,
    required this.score,
    this.proposalId,
  });

  String _rankText(int s) {
    if (s >= 90) return 'Rank #1';
    if (s >= 80) return 'Rank #2';
    if (s >= 70) return 'Rank #3';
    return 'Rank #4';
  }

  // ── جلب بيانات العرض من Supabase ثم فتح صفحة التفاصيل ──
  Future<void> _reviewProposal(BuildContext context) async {
    if (proposalId == null) return;
    try {
      final data = await supabase
          .from('proposals')
          .select('*, RFP(*)')
          .eq('ProposalID', proposalId!)
          .single();
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContractorProposalDetailsScreen(
              proposal: Map<String, dynamic>.from(data),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load proposal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg     = Color(0xFF0B1220);
    const card   = Color(0xFF111A2A);
    const stroke = Color(0xFF22314A);
    const hint   = Color(0xFF7F8EA3);
    const ring   = Color(0xFF6D7CFF);
    const accent = Color(0xFF3395FF);

    final safeScore = score.clamp(0, 100);
    final rank      = _rankText(safeScore);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation      : 0,
        leading: IconButton(
          icon     : const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Final Total Score',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon     : const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── بطاقة السكور ──
                Container(
                  width      : double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding    : const EdgeInsets.fromLTRB(18, 26, 18, 26),
                  decoration : BoxDecoration(
                    color       : card,
                    borderRadius: BorderRadius.circular(18),
                    border      : Border.all(color: stroke),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        contractorName,
                        style: const TextStyle(
                          color     : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize  : 15.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rank,
                        style: const TextStyle(
                          color     : ring,
                          fontWeight: FontWeight.w700,
                          fontSize  : 12.5,
                        ),
                      ),
                      const SizedBox(height: 22),

                      SizedBox(
                        width : 150,
                        height: 150,
                        child : Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width : 140,
                              height: 140,
                              child : CircularProgressIndicator(
                                value          : safeScore / 100.0,
                                strokeWidth    : 10,
                                backgroundColor: const Color(0xFF1A2740),
                                valueColor     :
                                    const AlwaysStoppedAnimation<Color>(ring),
                                strokeCap      : StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$safeScore',
                                  style: const TextStyle(
                                    color     : Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize  : 40,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Final Score',
                                  style: TextStyle(
                                    color     : hint,
                                    fontWeight: FontWeight.w600,
                                    fontSize  : 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      const Text(
                        'This score is the culmination of analysis across\nmanager-defined criteria.',
                        style: TextStyle(
                          color   : hint,
                          height  : 1.35,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // ── زر مراجعة العرض (يظهر فقط إذا توفر proposalId) ──
                if (proposalId != null) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width : double.infinity,
                    height: 50,
                    child : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side           : const BorderSide(color: accent),
                        foregroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon : const Icon(Icons.visibility_outlined),
                      label: const Text(
                        'Review My Proposal',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _reviewProposal(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}