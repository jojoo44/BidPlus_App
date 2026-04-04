// contractor_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'contractor_edit_account_screen.dart';
import 'change_password_screen.dart';
import 'account_actions_dialogs.dart';
import 'login_screen.dart';
import '../main.dart';

class ContractorProfileScreen extends StatefulWidget {
  final String? contractorId; // إذا فتحه المنجر يمرر الـ ID
  const ContractorProfileScreen({super.key, this.contractorId});

  @override
  State<ContractorProfileScreen> createState() =>
      _ContractorProfileScreenState();
}

class _ContractorProfileScreenState extends State<ContractorProfileScreen> {
  static const bg      = Color(0xFF0D1219);
  static const surface = Color(0xFF1C242F);
  static const blue    = Color(0xFF3395FF);

  String  _username       = '';
  String  _email          = '';
  String  _specialization = '';
  String  _tag            = '';
  String? _photoUrl;
  double  _avgQuality     = 0;
  double  _avgTimeliness  = 0;
  double  _avgOverall     = 0;
  int     _reviewCount    = 0;

  List<Map<String, dynamic>> _reviews   = [];
  List<Map<String, dynamic>> _portfolio = [];
  bool _isLoading    = true;
  bool _isUploading  = false;
  bool _isOwner      = false; // هل هو صاحب الحساب

  String get _targetId =>
      widget.contractorId ?? supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _isOwner = widget.contractorId == null;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      // بيانات المستخدم
      final data = await supabase
          .from('User')
          .select('username, email, specialization, specializationTag, photoUrl')
          .eq('id', _targetId)
          .single();

      // التقييمات
      final reviews = await supabase
          .from('ContractorEvaluation')
          .select()
          .eq('contractorId', _targetId)
          .order('created_at', ascending: false);

      double avgQ = 0, avgT = 0, avgO = 0;
      if ((reviews as List).isNotEmpty) {
        avgQ = reviews.map((r) => (r['quality'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a + b) / reviews.length;
        avgT = reviews.map((r) => (r['timeliness'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a + b) / reviews.length;
        avgO = reviews.map((r) => (r['overallScore'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a + b) / reviews.length;
      }

      // البورتفوليو
      final portfolio = await supabase
          .from('ContractorPortfolio')
          .select()
          .eq('contractorId', _targetId)
          .order('created_at', ascending: false);

      if (mounted) setState(() {
        _username       = data['username'] ?? '';
        _email          = data['email'] ?? '';
        _specialization = data['specialization'] ?? '';
        _tag            = data['specializationTag'] ?? '';
        _photoUrl       = data['photoUrl'];
        _avgQuality     = avgQ;
        _avgTimeliness  = avgT;
        _avgOverall     = avgO;
        _reviewCount    = (reviews as List).length;
        _reviews        = List<Map<String, dynamic>>.from(reviews);
        _portfolio      = List<Map<String, dynamic>>.from(portfolio);
        _isLoading      = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPortfolioItem() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isUploading = true);

      final ext      = file.extension?.toLowerCase() ?? 'jpg';
      final fileType = ext == 'pdf' ? 'pdf' : 'image';
      final path     = 'portfolio/$_targetId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('profiles').uploadBinary(
        path, file.bytes!,
        fileOptions: FileOptions(
          upsert: true,
          contentType: fileType == 'pdf' ? 'application/pdf' : 'image/jpeg',
        ),
      );

      final url = supabase.storage.from('profiles').getPublicUrl(path);

      // اسأل عن عنوان
      String title = file.name;
      if (mounted) {
        final ctrl = TextEditingController(text: file.name.split('.').first);
        await showDialog(context: context, builder: (ctx) => AlertDialog(
          backgroundColor: surface,
          title: const Text('Add Title', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Project title',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true, fillColor: bg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: blue),
              onPressed: () { title = ctrl.text.trim(); Navigator.pop(ctx); },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ));
      }

      await supabase.from('ContractorPortfolio').insert({
        'contractorId': _targetId,
        'title':        title,
        'fileUrl':      url,
        'fileType':     fileType,
        'uploadDate':   DateTime.now().toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploaded successfully!'),
                backgroundColor: Colors.green));
        _loadAll();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePortfolioItem(int portfolioId) async {
    try {
      await supabase.from('ContractorPortfolio')
          .delete().eq('portfolioID', portfolioId);
      _loadAll();
    } catch (_) {}
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        foregroundColor: Colors.white,
        title: Text(_isOwner ? 'My Profile' : '$_username\'s Profile',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: !_isOwner,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: blue))
          : RefreshIndicator(
              onRefresh: _loadAll, color: blue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(children: [

                  // ── Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(children: [
                      Stack(alignment: Alignment.bottomRight, children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF5D78FF),
                          backgroundImage: _photoUrl != null
                              ? NetworkImage(_photoUrl!) as ImageProvider
                              : null,
                          child: _photoUrl == null
                              ? Text(_username.isNotEmpty
                                      ? _username[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 36))
                              : null,
                        ),
                        if (_isOwner)
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => const ContractorEditAccountScreen()));
                              _loadAll();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                  color: blue, shape: BoxShape.circle),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      Text(_username, style: const TextStyle(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_email, style: const TextStyle(
                          color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 8),
                      if (_tag.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_tag, style: const TextStyle(
                              color: blue, fontSize: 12)),
                        ),
                      if (_specialization.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(_specialization, style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                      ],
                    ]),
                  ),

                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                      // ── Reviews
                      _sectionTitle(_reviews.isEmpty
                          ? 'Reviews'
                          : 'Reviews (${_reviews.length})'),
                      if (_reviews.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(color: surface,
                              borderRadius: BorderRadius.circular(14)),
                          child: const Column(children: [
                            Icon(Icons.rate_review_outlined,
                                color: Colors.grey, size: 36),
                            SizedBox(height: 8),
                            Text('No reviews yet',
                                style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ]),
                        )
                      else ...[
                        ..._reviews.map((r) => _buildReviewCard(r)),
                        const SizedBox(height: 20),
                      ],

                      // ── Portfolio
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionTitle('Portfolio'),
                          if (_isOwner)
                            GestureDetector(
                              onTap: _isUploading ? null : _uploadPortfolioItem,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: _isUploading
                                    ? const SizedBox(width: 16, height: 16,
                                        child: CircularProgressIndicator(
                                            color: blue, strokeWidth: 2))
                                    : const Row(children: [
                                        Icon(Icons.add, color: blue, size: 16),
                                        SizedBox(width: 4),
                                        Text('Upload', style: TextStyle(
                                            color: blue, fontSize: 12)),
                                      ]),
                              ),
                            ),
                        ],
                      ),

                      _portfolio.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: surface,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Column(children: [
                                const Icon(Icons.photo_library_outlined,
                                    color: Colors.grey, size: 40),
                                const SizedBox(height: 8),
                                Text(_isOwner
                                    ? 'Upload your past work'
                                    : 'No portfolio items yet',
                                    style: const TextStyle(color: Colors.grey)),
                              ]))
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: _portfolio.length,
                              itemBuilder: (_, i) =>
                                  _buildPortfolioCard(_portfolio[i]),
                            ),

                      const SizedBox(height: 24),

                      // ── Account actions (للكونتراكتور نفسه فقط)
                      if (_isOwner) ...[
                        _buildItem(Icons.lock_outline, 'Change Password',
                            () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen()))),
                        _buildItem(Icons.delete_outline, 'Delete Account',
                            () => AccountActionsDialogs
                                .showDeleteAccountDialog(context),
                            color: Colors.red),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF1E161E),
                              padding: const EdgeInsets.all(15),
                            ),
                            onPressed: () => AccountActionsDialogs
                                .showLogoutDialog(context, onConfirm: _logout),
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text('Logout',
                                style: TextStyle(color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                    ]),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(color: Colors.white,
        fontSize: 16, fontWeight: FontWeight.bold)),
  );

  Widget _ratingBar(String label, double value, Color color) => Row(children: [
    SizedBox(width: 70,
        child: Text(label, style: const TextStyle(
            color: Colors.grey, fontSize: 12))),
    Expanded(child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value / 5,
        backgroundColor: Colors.white10,
        color: color, minHeight: 6,
      ),
    )),
    const SizedBox(width: 8),
    Text(value.toStringAsFixed(1),
        style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);

  Widget _buildReviewCard(Map<String, dynamic> r) {
    final comment = r['comment']?.toString() ?? '';
    if (comment.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: surface,
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.format_quote, color: Colors.blue, size: 18),
          const Spacer(),
          Text(_fmtDate(r['created_at'] ?? ''),
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Text(comment, style: const TextStyle(
            color: Colors.white70, fontSize: 13, height: 1.5)),
      ]),
    );
  }

  Widget _miniRating(String label, double val) => Row(children: [
    Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 11)),
    ...List.generate(5, (i) => Icon(
        i < val.round() ? Icons.star : Icons.star_border,
        color: Colors.amber, size: 11)),
  ]);

  Widget _buildPortfolioCard(Map<String, dynamic> item) {
    final isImage = item['fileType'] == 'image';
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          color: surface, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
              child: isImage
                  ? Image.network(item['fileUrl'] ?? '',
                      width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1A2C47),
                        child: const Icon(Icons.broken_image,
                            color: Colors.grey, size: 40)))
                  : Container(color: const Color(0xFF1A2C47),
                      child: const Center(child: Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red, size: 48))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(item['title'] ?? '—',
                style: const TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
      if (_isOwner)
        Positioned(top: 6, right: 6,
          child: GestureDetector(
            onTap: () => _deletePortfolioItem(item['portfolioID']),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          )),
    ]);
  }

  Widget _buildItem(IconData icon, String title, VoidCallback onTap,
      {Color color = Colors.white}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: surface,
            borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon,
              color: color == Colors.red ? Colors.red : Colors.grey),
          title: Text(title, style: TextStyle(color: color, fontSize: 15)),
          trailing: const Icon(Icons.arrow_forward_ios,
              size: 14, color: Colors.grey),
          onTap: onTap,
        ),
      );

  String _fmtDate(String d) {
    try {
      final dt = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return ''; }
  }
}