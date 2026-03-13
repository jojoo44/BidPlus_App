import 'package:flutter/material.dart';
import 'rfp_details_screen.dart';
import '../main.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<Map<String, dynamic>> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  // جيب الدرافت من Supabase
  Future<void> _loadDrafts() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('RFP')
          .select()
          .eq('creatorUser', userId)
          .eq('status', 'Draft')
          .order('creationDate', ascending: false);

      if (mounted) {
        setState(() {
          _drafts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1219),
      appBar: AppBar(
        title: const Text("My Drafts", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3395FF)),
            )
          : _drafts.isEmpty
          ? const Center(
              child: Text(
                'No drafts yet',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDrafts,
              color: const Color(0xFF3395FF),
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _drafts.length,
                itemBuilder: (context, index) {
                  final rfp = _drafts[index];
                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RFPDetailsScreen(
                            rfpId: rfp['rfpID'].toString(), // ← الـ ID الحقيقي
                          ),
                        ),
                      );
                      _loadDrafts(); // حدّث القائمة بعد الرجوع
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C242F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rfp['title'] ?? 'Untitled',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "Created: ${rfp['creationDate'] ?? '—'}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                if (rfp['budget'] != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    "Budget: \$${rfp['budget']}",
                                    style: const TextStyle(
                                      color: Color(0xFF3395FF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
