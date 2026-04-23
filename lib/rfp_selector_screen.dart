// rfp_selector_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'proposals_list_screen.dart';

class RFPSelectorScreen extends StatefulWidget {
  const RFPSelectorScreen({super.key});

  @override
  State<RFPSelectorScreen> createState() => _RFPSelectorScreenState();
}

class _RFPSelectorScreenState extends State<RFPSelectorScreen> {
  static const Color bgColor = Color(0xFF0D1219);
  static const Color cardColor = Color(0xFF1C242F);
  static const Color primaryBlue = Color(0xFF3395FF);

  List<Map<String, dynamic>> _rfps = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRFPs();
    _searchController.addListener(() {
      final q = _searchController.text.toLowerCase();
      setState(() {
        _filtered = _rfps
            .where(
              (r) => (r['title'] ?? '').toString().toLowerCase().contains(q),
            )
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRFPs() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('RFP')
          .select('rfpID, title, status, deadline, budget')
          .eq('creatorUser', userId)
          .order('creationDate', ascending: false);

      // لكل RFP احسب عدد الـ proposals
      final rfps = List<Map<String, dynamic>>.from(data);
      for (final rfp in rfps) {
        try {
          final count = await supabase
              .from('proposals')
              .select('ProposalID')
              .eq('RFP', rfp['rfpID']);
          rfp['proposalCount'] = (count as List).length;
        } catch (_) {
          rfp['proposalCount'] = 0;
        }
      }

      if (mounted) {
        setState(() {
          _rfps = rfps;
          _filtered = rfps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'Published':
        return const Color(0xFF3395FF);
      case 'In Review':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Draft':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Project',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search projects...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Count
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filtered.length} project${_filtered.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  )
                : _filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, color: Colors.grey, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No projects found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRFPs,
                    color: primaryBlue,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final rfp = _filtered[i];
                        final rfpId = rfp['rfpID'].toString();
                        final title = rfp['title'] ?? 'Untitled';
                        final status = rfp['status'] ?? 'Draft';
                        final deadline = rfp['deadline'] ?? '—';
                        final budget = rfp['budget'];
                        final count = rfp['proposalCount'] as int? ?? 0;

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProposalsListScreen(rfpId: rfpId),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title + Status
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          status,
                                        ).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Info Row
                                Row(
                                  children: [
                                    // Proposals count
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.description_outlined,
                                            color: primaryBlue,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$count proposal${count != 1 ? 's' : ''}',
                                            style: const TextStyle(
                                              color: primaryBlue,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (budget != null) ...[
                                      const Icon(
                                        Icons.attach_money,
                                        color: Colors.grey,
                                        size: 13,
                                      ),
                                      Text(
                                        '$budget SAR',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.grey,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      deadline,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
}
