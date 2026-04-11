import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qualified_contractors_screen.dart';
import '../main.dart';
import 'manager_proposal_details_screen.dart';
import 'dart:math';

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
  bool _topsisApplied = false;
  final _searchController = TextEditingController();

  // ─────────────────────────────────────────────
  //  TOPSIS ALGORITHM
  // ─────────────────────────────────────────────

  /// Parse evaluationCriteria من RFP
  /// مثال: "Cost:20%, Experience:40%, Technical:40%"
  Map<String, double> _parseWeights(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    final weights = <String, double>{};
    for (final part in raw.split(',')) {
      final cleaned = part.trim().replaceAll('%', '');
      final kv = cleaned.split(':');
      if (kv.length == 2) {
        final name = kv[0].trim().toLowerCase();
        final val = double.tryParse(kv[1].trim()) ?? 0;
        weights[name] = val / 100; // 40% → 0.40
      }
    }
    return weights;
  }

  /// Parse scores من comments في proposals
  /// مثال: "Cost: 14000 | Experience: 5 | Technical: 1"
  /// أو يرجع الـ final score لو ما في comments
  Map<String, double> _parseCriteriaScores(Map<String, dynamic> proposal) {
    final comments = proposal['comments']?.toString() ?? '';
    final scores = <String, double>{};

    if (comments.contains('|')) {
      // شكل: "Cost: 14000 | Experience: 5 | Technical: 1"
      for (final part in comments.split('|')) {
        final kv = part.trim().split(':');
        if (kv.length == 2) {
          final name = kv[0].trim().toLowerCase();
          final val = double.tryParse(kv[1].trim()) ?? 0;
          scores[name] = val;
        }
      }
    } else {
      // fallback: استخدم الـ score الكلي
      final finalScore = (proposal['score'] as num?)?.toDouble() ?? 0;
      scores['score'] = finalScore;
    }

    return scores;
  }

  /// تطبيق خوارزمية TOPSIS الكاملة
  /// ترجع list من proposals مرتبة مع topsisScore لكل واحد
  List<Map<String, dynamic>> _applyTOPSIS(
    List<Map<String, dynamic>> proposals,
    Map<String, double> weights,
  ) {
    if (proposals.isEmpty) return proposals;
    if (weights.isEmpty) return proposals;

    final criteriaKeys = weights.keys.toList();
    final n = proposals.length;
    final m = criteriaKeys.length;

    // ── الخطوة 1: بناء Decision Matrix ──────────
    // matrix[i][j] = score المقاول i في المعيار j
    final matrix = List.generate(n, (i) {
      final scores = _parseCriteriaScores(proposals[i]);
      return List.generate(m, (j) {
        return scores[criteriaKeys[j]] ?? 0.0;
      });
    });

    // ── الخطوة 2: Normalize المصفوفة ──────────
    // normalized[i][j] = matrix[i][j] / sqrt(sum of squares in column j)
    final normalized = List.generate(n, (_) => List.filled(m, 0.0));

    for (int j = 0; j < m; j++) {
      double sumSq = 0;
      for (int i = 0; i < n; i++) {
        sumSq += matrix[i][j] * matrix[i][j];
      }
      final norm = sqrt(sumSq);
      for (int i = 0; i < n; i++) {
        normalized[i][j] = norm == 0 ? 0 : matrix[i][j] / norm;
      }
    }

    // ── الخطوة 3: Weighted Normalized Matrix ──
    // weighted[i][j] = normalized[i][j] * weight[j]
    final weighted = List.generate(n, (_) => List.filled(m, 0.0));

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < m; j++) {
        final w = weights[criteriaKeys[j]] ?? 0;
        weighted[i][j] = normalized[i][j] * w;
      }
    }

    // ── الخطوة 4: Ideal Best & Ideal Worst ────
    // كل المعايير هنا benefit (كلها أعلى = أفضل)
    final idealBest = List.filled(m, double.negativeInfinity);
    final idealWorst = List.filled(m, double.infinity);

    for (int j = 0; j < m; j++) {
      for (int i = 0; i < n; i++) {
        if (weighted[i][j] > idealBest[j]) idealBest[j] = weighted[i][j];
        if (weighted[i][j] < idealWorst[j]) idealWorst[j] = weighted[i][j];
      }
    }

    // ── الخطوة 5: حساب المسافة من Ideal Best & Worst ──
    final distBest = List.filled(n, 0.0);
    final distWorst = List.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      double sumBest = 0, sumWorst = 0;
      for (int j = 0; j < m; j++) {
        sumBest += pow(weighted[i][j] - idealBest[j], 2);
        sumWorst += pow(weighted[i][j] - idealWorst[j], 2);
      }
      distBest[i] = sqrt(sumBest);
      distWorst[i] = sqrt(sumWorst);
    }

    // ── الخطوة 6: TOPSIS Score ─────────────────
    // score = distWorst / (distBest + distWorst)
    // كلما اقترب من 1 → أفضل
    final topsisScores = List.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final denom = distBest[i] + distWorst[i];
      topsisScores[i] = denom == 0 ? 0 : distWorst[i] / denom;
    }

    // ── الخطوة 7: رتّب proposals حسب TOPSIS Score ──
    final indexed = List.generate(n, (i) => i);
    indexed.sort((a, b) => topsisScores[b].compareTo(topsisScores[a]));

    return indexed.map((i) {
      return {
        ...proposals[i],
        'topsisScore': topsisScores[i],
        'topsisRank': indexed.indexOf(i) + 1,
      };
    }).toList();
  }

  // ─────────────────────────────────────────────
  //  LOAD DATA
  // ─────────────────────────────────────────────

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
      String? evaluationCriteria;

      if (widget.rfpId != null) {
        // جيب الـ proposals + evaluationCriteria من RFP معاً
        final rfpData = await supabase
            .from('RFP')
            .select('evaluationCriteria')
            .eq('rfpID', widget.rfpId!)
            .maybeSingle();

        evaluationCriteria = rfpData?['evaluationCriteria'];

        final data = await supabase
            .from('proposals_with_username')
            .select('*, RFP(title, rfpID)')
            .eq('RFP', widget.rfpId!)
            .order('submitDate', ascending: false);
        proposals = List<Map<String, dynamic>>.from(data);
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

        // خذ الـ evaluationCriteria من أول RFP (أو يمكن تطبيقها per-RFP)
        evaluationCriteria = rfpData.isNotEmpty
            ? rfpData[0]['evaluationCriteria']
            : null;

        final data = await supabase
            .from('proposals_with_username')
            .select('*, RFP(title, rfpID)')
            .inFilter('RFP', rfpIds)
            .order('submitDate', ascending: false);
        proposals = List<Map<String, dynamic>>.from(data);
      }

      // ── تطبيق TOPSIS ──────────────────────────
      List<Map<String, dynamic>> sortedProposals = proposals;
      bool topsisApplied = false;

      final weights = _parseWeights(evaluationCriteria);
      if (weights.isNotEmpty && proposals.isNotEmpty) {
        // تطبّق TOPSIS فقط على proposals اللي عندها comments (scores)
        final withScores = proposals
            .where((p) => p['comments'] != null)
            .toList();
        final withoutScores = proposals
            .where((p) => p['comments'] == null)
            .toList();

        if (withScores.length >= 2) {
          final ranked = _applyTOPSIS(withScores, weights);
          sortedProposals = [...ranked, ...withoutScores];
          topsisApplied = true;
        }
      }

      if (mounted) {
        setState(() {
          _proposals = sortedProposals;
          _filtered = sortedProposals;
          _isLoading = false;
          _topsisApplied = topsisApplied;
        });
      }
    } catch (e) {
      debugPrint('Error loading proposals: $e');
      if (mounted) setState(() => _isLoading = false);
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

  // ─────────────────────────────────────────────
  //  UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0D1219);
    const cardColor = Color(0xFF1C242F);

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
          // ── بادج TOPSIS ──
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
          // ── Search + Qualified Button ──
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 10),
                _buildFilterButton(context),
              ],
            ),
          ),

          // ── Count + TOPSIS Label ──
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

          // ── List ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF3395FF)),
                        SizedBox(height: 12),
                        Text(
                          'Calculating TOPSIS ranking...',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
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
                        final username = p['contractorname'] ?? 'Unknown';
                        final rfpTitle = p['RFP']?['title'] ?? '—';
                        final price = p['proposedPrice'];
                        final status = p['status'] ?? 'Submitted';
                        final date = p['submitDate'] ?? '—';
                        final desc = p['description'] ?? '';
                        final topsisScore = (p['topsisScore'] as double?) ?? -1;
                        final rank = i + 1;

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
                            rank: rank,
                            username: username,
                            rfpTitle: rfpTitle,
                            price: price?.toString() ?? '—',
                            status: status,
                            date: date,
                            description: desc,
                            topsisScore: topsisScore,
                            cardColor: cardColor,
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

  // ─────────────────────────────────────────────
  //  WIDGETS
  // ─────────────────────────────────────────────

  /// لون الرتبة حسب الترتيب
  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    return Colors.grey;
  }

  /// أيقونة الرتبة
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
      hintText: "Search by contractor or RFP...",
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

  Widget _buildFilterButton(BuildContext context) => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3395FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QualifiedContractorsScreen()),
    ),
    icon: const Icon(Icons.stars, color: Colors.white, size: 18),
    label: const Text("Qualified", style: TextStyle(color: Colors.white)),
  );

  Widget _buildProposalCard({
    required int rank,
    required String username,
    required String rfpTitle,
    required String price,
    required String status,
    required String date,
    required String description,
    required double topsisScore,
    required Color cardColor,
  }) {
    final hasTopsis = topsisScore >= 0;
    final scorePercent = (topsisScore * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        // تمييز المرتبة الأولى بحد ذهبي خفيف
        border: rank == 1 && hasTopsis
            ? Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.4),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        children: [
          // ── شريط TOPSIS في الأعلى ──────────────
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
                // ── Header: الاسم + الرتبة ──
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
                    // ── Rank Badge ──
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

                // ── RFP Title ──
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

                // ── TOPSIS Score Bar ──────────────────
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
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: topsisScore.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _rankColor(rank).withOpacity(0.8),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Price + Date ──
                Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      color: Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$price SAR',
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

                // ── Description ──
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

                // ── Status Badge ──
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
