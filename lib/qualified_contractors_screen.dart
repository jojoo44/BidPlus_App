// qualified_contractors_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'topsis_service.dart';
import '../main.dart';
import 'criteria_selection_screen.dart';

class QualifiedContractorsScreen extends StatefulWidget {
  final String? rfpId;
  final List<TopsisResult>? topsisResults;
  final Map<String, double>? weights;

  const QualifiedContractorsScreen({
    super.key,
    this.rfpId,
    this.topsisResults,
    this.weights,
  });

  @override
  State<QualifiedContractorsScreen> createState() =>
      _QualifiedContractorsScreenState();
}

class _QualifiedContractorsScreenState
    extends State<QualifiedContractorsScreen> {
  static const Color bgColor = Color(0xFF0D1219);
  static const Color cardColor = Color(0xFF1C242F);
  static const Color primaryBlue = Color(0xFF3395FF);

  List<TopsisResult> _results = [];
  List<TopsisResult> _filtered = [];
  bool _isLoading = true;
  bool _showAll = false;

  final _searchController = TextEditingController();

  int get _qualifiedCount => _results.where((r) => r.isQualified).length;
  int get _totalCount => _results.length;

  double get _rfpThreshold =>
      widget.weights != null && widget.weights!.isNotEmpty
      ? TopsisService.calculateRFPThreshold(widget.weights!)
      : TopsisService.qualificationThreshold;

  @override
  void initState() {
    super.initState();
    if (widget.topsisResults != null && widget.topsisResults!.isNotEmpty) {
      _results = widget.topsisResults!;
      _filtered = _getFiltered();
      _isLoading = false;
    } else {
      _loadAndAnalyze();
    }

    _searchController.addListener(() {
      final q = _searchController.text.toLowerCase();
      setState(() {
        _filtered = _getFiltered()
            .where((r) => r.contractorName.toLowerCase().contains(q))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TopsisResult> _getFiltered() =>
      _showAll ? _results : _results.where((r) => r.isQualified).toList();

  Future<void> _loadAndAnalyze() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      Map<String, dynamic>? rfp;
      if (widget.rfpId != null) {
        rfp = await supabase
            .from('RFP')
            .select('rfpID, evaluationCriteria')
            .eq('rfpID', widget.rfpId!)
            .maybeSingle();
      } else {
        final rfps = await supabase
            .from('RFP')
            .select('rfpID, evaluationCriteria')
            .eq('creatorUser', userId)
            .order('created_at', ascending: false)
            .limit(1);
        if ((rfps as List).isNotEmpty) rfp = rfps.first;
      }

      if (rfp == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final rfpId = rfp['rfpID'];
      final weights =
          widget.weights ??
          TopsisService.parseWeights(rfp['evaluationCriteria']);
      if (weights.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final proposalsData = await supabase
          .from('proposals_with_username')
          .select('*, RFP(title, rfpID)')
          .eq('RFP', rfpId);

      final proposals = List<Map<String, dynamic>>.from(proposalsData);
      final results = TopsisService.analyze(
        proposals: proposals,
        weights: weights,
      );

      if (mounted) {
        setState(() {
          _results = results;
          _filtered = _getFiltered();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('QualifiedContractors error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  //  Invite — يحفظ NegoSession ويجيب session_id
  //  ثم يمرره لـ CriteriaSelectionScreen
  // ─────────────────────────────────────────────
  Future<void> _invite(TopsisResult result) async {
    try {
      // ← الجديد: .select('session_id').single() عشان نجيب الـ ID
      final sessionData = await supabase
          .from('NegoSession')
          .insert({
            'rfp_id': widget.rfpId,
            'contractor_id': result.contractorId,
            'status': 'Invited',
            'start_date': DateTime.now().toIso8601String(),
          })
          .select('session_id')
          .single();

      final sessionId = sessionData['session_id']?.toString() ?? '';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${result.contractorName} invited'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        // ← الجديد: مرر sessionId عشان الـ Realtime يشتغل
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CriteriaSelectionScreen(
              contractorName: result.contractorName,
              rfpId: widget.rfpId ?? '',
              sessionId: sessionId, // ← هذا اللي كان ناقص
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thresholdPercent = _rfpThreshold * 100;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Smart Ranking Results',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryBlue.withOpacity(0.4)),
                  ),
                  child: Text(
                    '$_qualifiedCount / $_totalCount qualified',
                    style: const TextStyle(
                      color: primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryBlue),
                  SizedBox(height: 12),
                  Text(
                    'Running TOPSIS...',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by contractor name...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryBlue.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: primaryBlue,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'TOPSIS Analysis Complete',
                                  style: TextStyle(
                                    color: primaryBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'RFP Threshold: ${thresholdPercent.toStringAsFixed(0)}%'
                              '  ·  $_qualifiedCount qualified'
                              '  ·  ${_totalCount - _qualifiedCount} below threshold',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          _filterChip('Qualified only', !_showAll, () {
                            setState(() {
                              _showAll = false;
                              _filtered = _getFiltered();
                            });
                          }),
                          const SizedBox(width: 8),
                          _filterChip('Show all', _showAll, () {
                            setState(() {
                              _showAll = true;
                              _filtered = _getFiltered();
                            });
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: Colors.grey.withOpacity(0.5),
                                size: 52,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _showAll
                                    ? 'No results'
                                    : 'No contractors met the '
                                          '${thresholdPercent.toStringAsFixed(0)}% threshold',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _buildResultCard(_filtered[i], i + 1),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? primaryBlue.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? primaryBlue.withOpacity(0.6) : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? primaryBlue : Colors.grey,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

  Widget _buildResultCard(TopsisResult result, int rank) {
    final isQualified = result.isQualified;
    final threshold = _rfpThreshold;
    final scorePercent = result.ciPercent.toStringAsFixed(1);

    final medalColor = rank == 1 && isQualified
        ? const Color(0xFFFFD700)
        : rank == 2 && isQualified
        ? const Color(0xFFC0C0C0)
        : rank == 3 && isQualified
        ? const Color(0xFFCD7F32)
        : isQualified
        ? primaryBlue
        : Colors.red.shade700;

    final medalLabel = !isQualified
        ? '✗'
        : rank == 1
        ? '🥇'
        : rank == 2
        ? '🥈'
        : rank == 3
        ? '🥉'
        : '#$rank';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isQualified ? cardColor : cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isQualified
              ? (rank <= 3 ? medalColor.withOpacity(0.4) : Colors.white12)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              color: isQualified
                  ? medalColor.withOpacity(0.7)
                  : Colors.red.withOpacity(0.5),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: medalColor.withOpacity(0.15),
                      radius: 20,
                      child: Text(
                        medalLabel,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.contractorName,
                            style: TextStyle(
                              color: isQualified
                                  ? Colors.white
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '$scorePercent%',
                                style: TextStyle(
                                  color: medalColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isQualified ? Colors.green : Colors.red)
                                          .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isQualified
                                      ? '✓ Qualified'
                                      : '✗ Below Threshold',
                                  style: TextStyle(
                                    color: isQualified
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isQualified)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () => _invite(result),
                        child: const Text(
                          'Invite',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: result.ciScore.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.07),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isQualified
                              ? medalColor.withOpacity(0.8)
                              : Colors.red.withOpacity(0.6),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    Positioned(
                      left: MediaQuery.of(context).size.width * threshold - 50,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RFP Threshold: ${(threshold * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      isQualified ? 'Passed ✓' : 'Did not meet minimum',
                      style: TextStyle(
                        color: isQualified
                            ? Colors.green.withOpacity(0.7)
                            : Colors.red.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),

                if (result.criteriaScores.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: result.criteriaScores.entries.map((e) {
                      final score = e.value;
                      final color = score >= 70
                          ? Colors.green
                          : score >= 50
                          ? Colors.orange
                          : Colors.red;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${_capitalize(e.key)}: ${score.toInt()}',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryBlue.withOpacity(0.12)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: primaryBlue,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          TopsisService.generateInsight(
                            result,
                            widget.weights ?? {},
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
