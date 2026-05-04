import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qualified_contractors_screen.dart';
import 'topsis_service.dart';
import '../main.dart';
import 'manager_proposal_details_screen.dart';

class ProposalsListScreen extends StatefulWidget {
  final String? rfpId;
  const ProposalsListScreen({super.key, this.rfpId});

  @override
  State<ProposalsListScreen> createState() => _ProposalsListScreenState();
}

class _ProposalsListScreenState extends State<ProposalsListScreen> {
  List<Map<String, dynamic>> _proposals = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  bool _isAnalyzing = false;
  bool _topsisApplied = false;
  String? _evaluationCriteria;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProposals();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProposals() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      List<Map<String, dynamic>> proposals = [];

      if (widget.rfpId != null) {
        final rfpData = await supabase
            .from('RFP')
            .select('evaluationCriteria')
            .eq('rfpID', widget.rfpId!)
            .maybeSingle();
        _evaluationCriteria = rfpData?['evaluationCriteria'];

        final data = await supabase
            .from('proposals')
            .select(
              '*, RFP(rfpID, title, deadline, budget), User:submitterUserId(username)',
            )
            .eq('RFP', widget.rfpId!)
            .order('submitDate', ascending: false);

        proposals = (data as List).map((p) {
          final map = Map<String, dynamic>.from(p);
          map['contractorname'] = p['User']?['username'] ?? 'Unknown';
          return map;
        }).toList();
      } else {
        final rfpData = await supabase
            .from('RFP')
            .select('rfpID, evaluationCriteria')
            .eq('creatorUser', userId);

        final rfpIds = (rfpData as List).map((r) => r['rfpID']).toList();
        if (rfpIds.isEmpty) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        _evaluationCriteria = rfpData.isNotEmpty
            ? rfpData[0]['evaluationCriteria']
            : null;

        final data = await supabase
            .from('proposals')
            .select(
              '*, RFP(rfpID, title, deadline, budget), User:submitterUserId(username)',
            )
            .inFilter('RFP', rfpIds)
            .order('submitDate', ascending: false);

        proposals = (data as List).map((p) {
          final map = Map<String, dynamic>.from(p);
          map['contractorname'] = p['User']?['username'] ?? 'Unknown';
          return map;
        }).toList();
      }

      if (mounted) {
        setState(() {
          _proposals = proposals;
          _filtered = proposals;
          _isLoading = false;
          _topsisApplied = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading proposals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _analyzeAndRank() async {
    final weights = TopsisService.parseWeights(_evaluationCriteria);
    if (weights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No evaluation criteria found for this RFP'),
        ),
      );
      return;
    }

    final withScores = _proposals
        .where(
          (p) =>
              p['comments'] != null && (p['comments'] as String).contains('|'),
        )
        .toList();

    if (withScores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No proposals with AI scores yet')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final results = TopsisService.analyze(
        proposals: withScores,
        weights: weights,
      );

      final rankedProposals = <Map<String, dynamic>>[];
      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        final original = withScores.firstWhere(
          (p) => (p['ProposalID']?.toString() ?? '') == r.proposalId,
          orElse: () => withScores[i],
        );
        rankedProposals.add({
          ...original,
          'topsisScore': r.ciScore,
          'topsisPercent': r.ciPercent,
          'isQualified': r.isQualified,
          'aiInsight': TopsisService.generateInsight(r, weights),
        });
      }

      final withoutScores = _proposals
          .where(
            (p) =>
                p['comments'] == null ||
                !(p['comments'] as String).contains('|'),
          )
          .toList();

      if (mounted) {
        setState(() {
          _proposals = [...rankedProposals, ...withoutScores];
          _filtered = [...rankedProposals, ...withoutScores];
          _topsisApplied = true;
          _isAnalyzing = false;
        });
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QualifiedContractorsScreen(
              rfpId: widget.rfpId,
              topsisResults: results,
              weights: weights,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Analyze error: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _proposals.where((p) {
        final name = (p['contractorname'] ?? '').toString().toLowerCase();
        final title = (p['RFP']?['title'] ?? '').toLowerCase();
        return name.contains(q) || title.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0D1219);
    const cardColor = Color(0xFF1C242F);

    final scoredCount = _proposals
        .where(
          (p) =>
              p['comments'] != null && (p['comments'] as String).contains('|'),
        )
        .length;

    final weights = TopsisService.parseWeights(_evaluationCriteria);
    final rfpThreshold = weights.isNotEmpty
        ? TopsisService.calculateRFPThreshold(weights)
        : TopsisService.qualificationThreshold;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Proposals', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_topsisApplied)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text(
                  'TOPSIS ✓',
                  style: TextStyle(
                    color: Color(0xFF3395FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: const Color(0xFF3395FF).withOpacity(0.12),
                side: BorderSide(
                  color: const Color(0xFF3395FF).withOpacity(0.3),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
            child: _buildSearchField(),
          ),

          // زر Analyze — يظهر من مقاول واحد
          if (!_isLoading && scoredCount >= 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAnalyzing
                        ? const Color(0xFF1C242F)
                        : const Color(0xFF3395FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isAnalyzing ? null : _analyzeAndRank,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 18,
                        ),
                  label: Text(
                    _isAnalyzing
                        ? 'Applying TOPSIS...'
                        : _topsisApplied
                        ? 'Re-Analyze & Rank'
                        : 'Analyze & Rank  ($scoredCount proposals)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // تحذير لو ما في scores
          if (!_isLoading && scoredCount < 1 && _proposals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No proposals with AI scores yet.',
                        style: TextStyle(
                          color: Colors.orange.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Text(
                    '${_filtered.length} proposal${_filtered.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  if (_topsisApplied) ...[
                    const SizedBox(width: 8),
                    const Text(
                      '· Sorted by TOPSIS',
                      style: TextStyle(
                        color: Color(0xFF3395FF),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3395FF)),
                  )
                : _filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          color: Colors.grey,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No proposals yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadProposals,
                    color: const Color(0xFF3395FF),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final p = _filtered[i];
                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManagerProposalDetailsScreen(
                                  proposal: p,
                                  onStatusChanged: _loadProposals,
                                ),
                              ),
                            );
                            _loadProposals();
                          },
                          child: _buildProposalCard(
                            rank: i + 1,
                            proposal: p,
                            cardColor: cardColor,
                            rfpThreshold: rfpThreshold,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey;
  }

  String _rankLabel(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'shortlisted':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Widget _buildSearchField() => TextField(
    controller: _searchController,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: 'Search by contractor or RFP...',
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: const Icon(Icons.search, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF161D27),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _buildProposalCard({
    required int rank,
    required Map<String, dynamic> proposal,
    required Color cardColor,
    required double rfpThreshold,
  }) {
    final username = proposal['contractorname'] ?? 'Unknown';
    final rfpTitle = proposal['RFP']?['title'] ?? '—';
    final price = proposal['proposedPrice'];
    final status = proposal['status'] ?? 'Submitted';
    final date = proposal['submitDate'] ?? '—';
    final description = proposal['description'] ?? '';
    final topsisScore = (proposal['topsisScore'] as double?) ?? -1;
    final isQualified = proposal['isQualified'] as bool?;
    final aiInsight = proposal['aiInsight'] as String?;

    final hasTopsis = topsisScore >= 0;
    final scorePercent = (topsisScore * 100).toStringAsFixed(1);

    Color? borderColor;
    if (hasTopsis) {
      borderColor = isQualified == true
          ? Colors.green.withOpacity(0.3)
          : Colors.red.withOpacity(0.3);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1.2)
            : null,
      ),
      child: Column(
        children: [
          if (hasTopsis)
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                gradient: LinearGradient(
                  colors: [
                    _rankColor(rank).withOpacity(0.8),
                    _rankColor(rank).withOpacity(0.2),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (hasTopsis)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _rankColor(rank).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _rankColor(rank).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          _rankLabel(rank),
                          style: TextStyle(
                            color: _rankColor(rank),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      color: Colors.grey,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        rfpTitle,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                if (hasTopsis) ...[
                  Row(
                    children: [
                      const Text(
                        'TOPSIS',
                        style: TextStyle(
                          color: Color(0xFF3395FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
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
                              (isQualified == true ? Colors.green : Colors.red)
                                  .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isQualified == true
                              ? '✓ Qualified'
                              : '✗ Below Threshold',
                          style: TextStyle(
                            color: isQualified == true
                                ? Colors.green
                                : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$scorePercent%',
                        style: TextStyle(
                          color: _rankColor(rank),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: topsisScore.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isQualified == true
                            ? _rankColor(rank).withOpacity(0.8)
                            : Colors.red.withOpacity(0.6),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RFP Threshold: ${(rfpThreshold * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        ),
                      ),
                      if (isQualified == false)
                        Text(
                          'Below minimum',
                          style: TextStyle(
                            color: Colors.red.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                if (aiInsight != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3395FF).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3395FF).withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF3395FF),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            aiInsight,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      color: Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${price ?? '—'} SAR',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.grey,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: _statusColor(status), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
