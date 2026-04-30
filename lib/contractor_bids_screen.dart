// contractor_bids_screen.dart
import 'package:flutter/material.dart';
import 'contractor_rfp_details_screen.dart';
import '../main.dart';

const List<Map<String, String>> kTags = [
  {'label': 'All', 'value': ''},
  {'label': 'Construction', 'value': 'construction'},
  {'label': 'Engineering', 'value': 'engineering'},
  {'label': 'IT & Software', 'value': 'it'},
  {'label': 'Design', 'value': 'design'},
  {'label': 'Maintenance', 'value': 'maintenance'},
  {'label': 'Consulting', 'value': 'consulting'},
  {'label': 'Logistics', 'value': 'logistics'},
  {'label': 'Other', 'value': 'other'},
];

class BidFilters {
  final String? tag;
  final double? minBudget;
  final double? maxBudget;
  final DateTime? beforeDeadline;

  const BidFilters({this.tag, this.minBudget, this.maxBudget, this.beforeDeadline});

  bool get isEmpty =>
      (tag == null || tag!.isEmpty) &&
      minBudget == null &&
      maxBudget == null &&
      beforeDeadline == null;
}

class ContractorBidsScreen extends StatefulWidget {
  const ContractorBidsScreen({super.key});

  @override
  State<ContractorBidsScreen> createState() => _ContractorBidsScreenState();
}

class _ContractorBidsScreenState extends State<ContractorBidsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  BidFilters _filters = const BidFilters();

  List<Map<String, dynamic>> _openRFPs = [];
  List<Map<String, dynamic>> _myProposals = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _userId = supabase.auth.currentUser?.id;
      if (_userId == null) return;

      // جيب الـ RFPs المنشورة
      final rfpData = await supabase
          .from('RFP')
          .select()
          .eq('status', 'Published')
          .order('creationDate', ascending: false);

      // جيب proposals الكونتراكتر
      final proposalData = await supabase
          .from('proposals')
          .select('RFP, status')
          .eq('submitterUserId', _userId!)
          .order('submissionDate', ascending: false);

      if (mounted) {
        setState(() {
          _openRFPs = List<Map<String, dynamic>>.from(rfpData);
          _myProposals = List<Map<String, dynamic>>.from(proposalData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _proposalStatus(String rfpId) {
    final found = _myProposals.where((p) => p['RFP'].toString() == rfpId);
    if (found.isEmpty) return null;
    return found.first['status'] as String?;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _openRFPs.where((rfp) {
      final rfpId = rfp['rfpID'].toString();
      // فقط الـ RFPs اللي ما قدّم عليها الكونتراكتور بعد
      if (_proposalStatus(rfpId) != null) return false;

      final title = (rfp['title'] ?? '').toString().toLowerCase();
      final tag = (rfp['requiredTag'] ?? '').toString().toLowerCase();
      final budget = (rfp['budget'] as num?)?.toDouble() ?? 0;

      final matchSearch = q.isEmpty || title.contains(q);
      final matchTag = (_filters.tag == null || _filters.tag!.isEmpty) ||
          tag == _filters.tag!.toLowerCase();
      final matchMin = _filters.minBudget == null || budget >= _filters.minBudget!;
      final matchMax = _filters.maxBudget == null || budget <= _filters.maxBudget!;
      final matchDate = _filters.beforeDeadline == null ||
          (rfp['deadline'] != null &&
              !DateTime.tryParse(rfp['deadline'])!.isAfter(_filters.beforeDeadline!));

      return matchSearch && matchTag && matchMin && matchMax && matchDate;
    }).toList();
  }

  Color get _bg => const Color(0xFF0B1720);
  Color get _card => const Color(0xFF0F2230);
  Color get _card2 => const Color(0xFF0C1C27);
  Color get _line => const Color(0xFF1F3A4B);
  Color get _accent => const Color(0xFF41C0FF);
  Color get _muted => const Color(0xFF93A7B6);

  Color _statusColor(String? s) {
    switch (s?.toLowerCase()) {
      case 'accepted': return const Color(0xFF52C41A);
      case 'rejected': return Colors.redAccent;
      case 'submitted': return const Color(0xFFFFA940);
      case 'negotiation': return Colors.purpleAccent;
      default: return const Color(0xFF41C0FF);
    }
  }

  String _statusLabel(String? s) {
    if (s == null) return 'Open';
    switch (s.toLowerCase()) {
      case 'accepted': return 'Accepted';
      case 'rejected': return 'Rejected';
      case 'submitted': return 'Submitted';
      case 'negotiation': return 'Negotiation';
      default: return 'Open';
    }
  }

  IconData _statusIcon(String? s) {
    if (s == null) return Icons.radio_button_unchecked;
    switch (s.toLowerCase()) {
      case 'accepted': return Icons.verified_rounded;
      case 'rejected': return Icons.cancel_outlined;
      case 'submitted': return Icons.send_rounded;
      case 'negotiation': return Icons.handshake_outlined;
      default: return Icons.radio_button_unchecked;
    }
  }

  String _fmtDate(String? d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return d; }
  }

  bool _isOverdue(String? d) {
    if (d == null) return false;
    try { return DateTime.parse(d).isBefore(DateTime.now()); } catch (_) { return false; }
  }

  int get _openCount => _filtered.where((r) => _proposalStatus(r['rfpID'].toString()) == null).length;
  int get _submittedCount => _filtered.where((r) => _proposalStatus(r['rfpID'].toString()) == 'Submitted').length;
  int get _acceptedCount => _filtered.where((r) => _proposalStatus(r['rfpID'].toString()) == 'Accepted').length;

  void _onTapRFP(Map<String, dynamic> rfp) {
    final rfpId = rfp['rfpID'].toString();
    final pStatus = _proposalStatus(rfpId);
    final _accent = _statusColor(pStatus);

    showModalBottomSheet(
      context: context,
      backgroundColor: _card2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
            )),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Text(rfp['title'] ?? '—',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _accent.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(pStatus), color: _accent, size: 14),
                  const SizedBox(width: 5),
                  Text(_statusLabel(pStatus),
                      style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            if (rfp['requiredTag'] != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
                ),
                child: Text(rfp['requiredTag'], style: TextStyle(color: _accent, fontSize: 12)),
              ),
            const SizedBox(height: 8),
            _detailRow(Icons.payments_rounded, 'Budget',
                rfp['budget'] != null ? '${rfp['budget']} SAR' : '—'),
            _detailRow(Icons.event_rounded, 'Deadline', _fmtDate(rfp['deadline']),
                valueColor: _isOverdue(rfp['deadline']) && pStatus == null ? Colors.redAccent : null),
            _detailRow(Icons.calendar_today_outlined, 'Posted', _fmtDate(rfp['creationDate'])),
            const SizedBox(height: 24),
            if (pStatus == null)
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent, foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ContractorRFPDetailsScreen(rfpId: rfpId),
                    )).then((_) => _loadData());
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit Proposal', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_statusIcon(pStatus), color: _accent, size: 18),
                  const SizedBox(width: 8),
                  Text('Proposal ${_statusLabel(pStatus)}',
                      style: TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Icon(icon, color: _muted, size: 18),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: _muted, fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(
          color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  void _openFiltersSheet() async {
    final res = await showModalBottomSheet<BidFilters>(
      context: context, backgroundColor: _card2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FiltersSheet(
        initial: _filters, accent: _accent, muted: _muted, line: _line),
    );
    if (res != null) setState(() => _filters = res);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final hasFilters = !_filters.isEmpty;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        title: const Text('Bids', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          Stack(alignment: Alignment.center, children: [
            IconButton(
              icon: Icon(Icons.tune_rounded, color: hasFilters ? _accent : Colors.white),
              onPressed: _openFiltersSheet,
            ),
            if (hasFilters)
              Positioned(top: 8, right: 8,
                child: Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: _accent, shape: BoxShape.circle))),
          ]),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData, color: _accent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Search
                    Container(
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(children: [
                        Icon(Icons.search_rounded, color: _muted),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: Colors.white),
                          cursorColor: _accent,
                          decoration: InputDecoration(
                            hintText: 'Search bids...',
                            hintStyle: TextStyle(color: _muted.withOpacity(0.7)),
                            border: InputBorder.none,
                          ),
                        )),
                        if (hasFilters)
                          GestureDetector(
                            onTap: () => setState(() => _filters = const BidFilters()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: _accent.withOpacity(0.4)),
                              ),
                              child: Text('Clear', style: TextStyle(
                                color: _accent, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ]),
                    ),

                    const SizedBox(height: 12),

                    // Tags horizontal scroll
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: kTags.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final t = kTags[i];
                          final selected = (_filters.tag ?? '') == t['value'];
                          return GestureDetector(
                            onTap: () => setState(() => _filters = BidFilters(
                              tag: t['value'],
                              minBudget: _filters.minBudget,
                              maxBudget: _filters.maxBudget,
                              beforeDeadline: _filters.beforeDeadline,
                            )),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected ? _accent.withOpacity(0.18) : _card,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: selected ? _accent.withOpacity(0.7) : _line),
                              ),
                              child: Text(t['label']!, style: TextStyle(
                                color: selected ? _accent : _muted,
                                fontSize: 12, fontWeight: FontWeight.w700,
                              )),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (list.isEmpty)
                      Center(child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(children: [
                          Icon(Icons.inbox_outlined, color: _muted, size: 40),
                          const SizedBox(height: 12),
                          Text('No bids found', style: TextStyle(color: _muted, fontSize: 14)),
                        ]),
                      ))
                    else
                      ...list.map((rfp) {
                        final rfpId = rfp['rfpID'].toString();
                        final overdue = _isOverdue(rfp['deadline']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _card, borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _line),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _onTapRFP(rfp),
                              borderRadius: BorderRadius.circular(18),
                              splashColor: _accent.withOpacity(0.08),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: _accent.withOpacity(0.25)),
                                    ),
                                    child: Icon(Icons.work_outline, color: _accent, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(rfp['title'] ?? '—', style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      if (rfp['requiredTag'] != null)
                                        Text(rfp['requiredTag'],
                                            style: TextStyle(color: _accent, fontSize: 11)),
                                      const SizedBox(height: 6),
                                      Wrap(spacing: 6, runSpacing: 6, children: [
                                        _chip(Icons.payments_rounded,
                                            rfp['budget'] != null ? '${rfp['budget']} SAR' : '—'),
                                        _chip(Icons.event_rounded,
                                            'Due ${_fmtDate(rfp['deadline'])}',
                                            color: overdue ? Colors.redAccent : null),
                                      ]),
                                    ],
                                  )),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
                                ]),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _chip(IconData icon, String text, {Color? color}) {
    final c = color ?? _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: c, fontSize: 11)),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Color card, line, accent, muted;
  final int total, openCount, submittedCount, acceptedCount;

  const _SummaryCard({
    required this.card, required this.line, required this.accent, required this.muted,
    required this.total, required this.openCount,
    required this.submittedCount, required this.acceptedCount,
  });

  @override
  Widget build(BuildContext context) {
    final done = submittedCount + acceptedCount;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Icon(Icons.analytics_rounded, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Text('$done of $total bids processed',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          Text('${(progress * 100).round()}%', style: TextStyle(color: muted)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress, minHeight: 8,
            backgroundColor: line.withOpacity(0.7),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _pill('Open', openCount, const Color(0xFF41C0FF)),
          const SizedBox(width: 8),
          _pill('Submitted', submittedCount, const Color(0xFFFFA940)),
          const SizedBox(width: 8),
          _pill('Accepted', acceptedCount, const Color(0xFF52C41A)),
        ]),
      ]),
    );
  }

  Widget _pill(String label, int value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
        const SizedBox(width: 5),
        Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    ),
  );
}

class _FiltersSheet extends StatefulWidget {
  final BidFilters initial;
  final Color accent, muted, line;
  const _FiltersSheet({required this.initial, required this.accent, required this.muted, required this.line});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String _tag;
  late TextEditingController _minCtrl, _maxCtrl;
  DateTime? _before;

  @override
  void initState() {
    super.initState();
    _tag = widget.initial.tag ?? '';
    _minCtrl = TextEditingController(text: widget.initial.minBudget?.toStringAsFixed(0) ?? '');
    _maxCtrl = TextEditingController(text: widget.initial.maxBudget?.toStringAsFixed(0) ?? '');
    _before = widget.initial.beforeDeadline;
  }

  @override
  void dispose() { _minCtrl.dispose(); _maxCtrl.dispose(); super.dispose(); }

  int get _activeCount {
    int c = 0;
    if (_tag.isNotEmpty) c++;
    if (_minCtrl.text.isNotEmpty) c++;
    if (_maxCtrl.text.isNotEmpty) c++;
    if (_before != null) c++;
    return c;
  }

  double? _toDouble(String s) { final t = s.trim(); if (t.isEmpty) return null; return double.tryParse(t); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 14,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999)))),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Filters', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          if (_activeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: widget.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
              child: Text('$_activeCount active', style: TextStyle(color: widget.accent, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: () => setState(() { _tag = ''; _minCtrl.text = ''; _maxCtrl.text = ''; _before = null; }),
            child: Text('Reset all', style: TextStyle(color: widget.accent, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 16),

        _label('Specialization / Field'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
          children: kTags.map((t) {
            final selected = _tag == t['value'];
            return GestureDetector(
              onTap: () => setState(() => _tag = t['value']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? widget.accent.withOpacity(0.16) : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: selected ? widget.accent.withOpacity(0.7) : Colors.white.withOpacity(0.08)),
                ),
                child: Text(t['label']!, style: TextStyle(
                  color: selected ? widget.accent : Colors.white70,
                  fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        _label('Budget Range (SAR)'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_minCtrl, 'Min')),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('—', style: TextStyle(color: widget.muted, fontSize: 16))),
          Expanded(child: _field(_maxCtrl, 'Max')),
        ]),
        const SizedBox(height: 18),

        _label('Deadline Before'),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(context: context,
              initialDate: _before ?? now, firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 5));
            if (picked != null) setState(() => _before = picked);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: _before != null ? widget.accent.withOpacity(0.5) : widget.line),
              borderRadius: BorderRadius.circular(14),
              color: _before != null ? widget.accent.withOpacity(0.05) : Colors.white.withOpacity(0.03),
            ),
            child: Row(children: [
              Icon(Icons.event_rounded, color: _before != null ? widget.accent : widget.muted, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _before == null ? 'Any date'
                    : '${_before!.year}-${_before!.month.toString().padLeft(2,'0')}-${_before!.day.toString().padLeft(2,'0')}',
                style: TextStyle(color: _before != null ? Colors.white : widget.muted, fontSize: 14),
              )),
              if (_before != null)
                GestureDetector(onTap: () => setState(() => _before = null),
                  child: Icon(Icons.close_rounded, color: widget.muted, size: 18)),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: widget.line), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accent, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(context, BidFilters(
              tag: _tag.isEmpty ? null : _tag,
              minBudget: _toDouble(_minCtrl.text),
              maxBudget: _toDouble(_maxCtrl.text),
              beforeDeadline: _before,
            )),
            child: Text(_activeCount > 0 ? 'Apply ($_activeCount)' : 'Apply',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          )),
        ]),
      ]),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: TextStyle(color: widget.muted, fontSize: 13, fontWeight: FontWeight.w600)));

  Widget _field(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl, keyboardType: TextInputType.number,
    style: const TextStyle(color: Colors.white),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: widget.muted.withOpacity(0.6), fontSize: 13),
      filled: true, fillColor: Colors.white.withOpacity(0.03),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.line), borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.accent), borderRadius: BorderRadius.circular(14)),
    ),
  );
}