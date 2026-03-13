import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qualified_contractors_screen.dart';
import '../main.dart';

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
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. جيب الـ proposals
      List<Map<String, dynamic>> proposals = [];

      if (widget.rfpId != null) {
        final data = await supabase
            .from('proposals_with_username')
            .select('*, RFP(title, rfpID)')
            .eq('RFP', widget.rfpId!)
            .order('submitDate', ascending: false);
        proposals = List<Map<String, dynamic>>.from(data);
      } else {
        final rfpData = await supabase
            .from('RFP')
            .select('rfpID')
            .eq('creatorUser', userId);
        final rfpIds = (rfpData as List).map((r) => r['rfpID']).toList();
        if (rfpIds.isEmpty) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final data = await supabase
            .from('proposals_with_username')
            .select('*, RFP(title, rfpID)')
            .inFilter('RFP', rfpIds)
            .order('submitDate', ascending: false);
        proposals = List<Map<String, dynamic>>.from(data);
      }

      if (mounted) {
        setState(() {
          _proposals = proposals;
          _filtered = proposals;
          _isLoading = false;
        });
      }
    } catch (e) {
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
      ),
      body: Column(
        children: [
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

          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filtered.length} proposal${_filtered.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
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
                        final username = p['contractorname'] ?? 'Unknown';
                        final rfpTitle = p['RFP']?['title'] ?? '—';
                        final price = p['proposedPrice'];
                        final status = p['status'] ?? 'Submitted';
                        final date = p['submitDate'] ?? '—';
                        final desc = p['description'] ?? '';

                        return _buildProposalCard(
                          rank: '#${i + 1}',
                          username: username,
                          rfpTitle: rfpTitle,
                          price: price?.toString() ?? '—',
                          status: status,
                          date: date,
                          description: desc,
                          cardColor: cardColor,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
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
    required String rank,
    required String username,
    required String rfpTitle,
    required String price,
    required String status,
    required String date,
    required String description,
    required Color cardColor,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 15),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(15),
    ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                rank,
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.article_outlined, color: Colors.grey, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                rfpTitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.attach_money, color: Colors.grey, size: 16),
            const SizedBox(width: 4),
            Text(
              '$price SAR',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Spacer(),
            const Icon(Icons.calendar_today, color: Colors.grey, size: 14),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      ],
    ),
  );
}
