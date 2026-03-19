// contractor_bids_screen.dart
import 'package:flutter/material.dart';
import 'contractor_rfp_details_screen.dart';

enum BidStatus { open, submitted, awarded }

class BidItem {
  final String id;
  final String title;
  final String project;
  final String location;
  final double budget;
  final DateTime deadline;
  final BidStatus status;

  const BidItem({
    required this.id,
    required this.title,
    required this.project,
    required this.location,
    required this.budget,
    required this.deadline,
    required this.status,
  });
}

class BidFilters {
  final BidStatus? status;
  final double? minBudget;
  final double? maxBudget;
  final DateTime? beforeDeadline;

  const BidFilters({
    this.status,
    this.minBudget,
    this.maxBudget,
    this.beforeDeadline,
  });

  BidFilters copyWith({
    BidStatus? status,
    double? minBudget,
    double? maxBudget,
    DateTime? beforeDeadline,
    bool clearStatus = false,
    bool clearMinBudget = false,
    bool clearMaxBudget = false,
    bool clearBeforeDeadline = false,
  }) {
    return BidFilters(
      status: clearStatus ? null : (status ?? this.status),
      minBudget: clearMinBudget ? null : (minBudget ?? this.minBudget),
      maxBudget: clearMaxBudget ? null : (maxBudget ?? this.maxBudget),
      beforeDeadline:
          clearBeforeDeadline ? null : (beforeDeadline ?? this.beforeDeadline),
    );
  }

  bool get isEmpty =>
      status == null &&
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

  final List<BidItem> _allBids = [
    BidItem(
      id: 'B-1001',
      title: 'Downtown Office Renovation',
      project: 'Phase 1 - Interior',
      location: 'Riyadh',
      budget: 250000,
      deadline: DateTime(2026, 3, 20),
      status: BidStatus.open,
    ),
    BidItem(
      id: 'B-1002',
      title: 'Villa 402 Electrical Upgrade',
      project: 'East Wing',
      location: 'Jeddah',
      budget: 85000,
      deadline: DateTime(2026, 3, 10),
      status: BidStatus.open,
    ),
    BidItem(
      id: 'B-1003',
      title: 'Warehouse Roofing Repair',
      project: 'Section C',
      location: 'Dammam',
      budget: 120000,
      deadline: DateTime(2026, 3, 5),
      status: BidStatus.submitted,
    ),
    BidItem(
      id: 'B-1004',
      title: 'Lobby Marble Finishing',
      project: 'Downtown Tower',
      location: 'Riyadh',
      budget: 60000,
      deadline: DateTime(2026, 2, 28),
      status: BidStatus.submitted,
    ),
    BidItem(
      id: 'B-1005',
      title: 'Burj Site Quality Inspection',
      project: 'Phase 1',
      location: 'Dubai',
      budget: 30000,
      deadline: DateTime(2026, 2, 25),
      status: BidStatus.awarded,
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Colors
  Color get _bg => const Color(0xFF0B1720);
  Color get _card => const Color(0xFF0F2230);
  Color get _card2 => const Color(0xFF0C1C27);
  Color get _line => const Color(0xFF1F3A4B);
  Color get _accent => const Color(0xFF41C0FF);
  Color get _muted => const Color(0xFF93A7B6);

  // ── Status colors
  Color _statusColor(BidStatus s) {
    switch (s) {
      case BidStatus.open:
        return const Color(0xFF41C0FF);
      case BidStatus.submitted:
        return const Color(0xFFFFA940);
      case BidStatus.awarded:
        return const Color(0xFF52C41A);
    }
  }

  String _statusLabel(BidStatus s) {
    switch (s) {
      case BidStatus.open:
        return 'Open';
      case BidStatus.submitted:
        return 'Submitted';
      case BidStatus.awarded:
        return 'Awarded';
    }
  }

  IconData _statusIcon(BidStatus s) {
    switch (s) {
      case BidStatus.open:
        return Icons.radio_button_unchecked;
      case BidStatus.submitted:
        return Icons.send_rounded;
      case BidStatus.awarded:
        return Icons.verified_rounded;
    }
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  bool _isOverdue(DateTime d) => d.isBefore(DateTime.now());

  List<BidItem> get _filteredBids {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allBids.where((b) {
      final matchSearch = q.isEmpty ||
          b.title.toLowerCase().contains(q) ||
          b.project.toLowerCase().contains(q) ||
          b.location.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q);
      final matchStatus =
          _filters.status == null || b.status == _filters.status;
      final matchMin =
          _filters.minBudget == null || b.budget >= _filters.minBudget!;
      final matchMax =
          _filters.maxBudget == null || b.budget <= _filters.maxBudget!;
      final matchDate = _filters.beforeDeadline == null ||
          !b.deadline.isAfter(_filters.beforeDeadline!);
      return matchSearch && matchStatus && matchMin && matchMax && matchDate;
    }).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
  }

  int _countByStatus(List<BidItem> list, BidStatus s) =>
      list.where((e) => e.status == s).length;

  // ── Tap on bid → bottom sheet details
  void _onTapBid(BidItem bid) {
    final sc = _statusColor(bid.status);
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
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    bid.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: sc.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(bid.status), color: sc, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        _statusLabel(bid.status),
                        style: TextStyle(
                          color: sc,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${bid.project} • ${bid.location}',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Details grid
            _detailRow(Icons.tag_rounded, 'Bid ID', bid.id),
            _detailRow(
              Icons.payments_rounded,
              'Budget',
              '${bid.budget.toStringAsFixed(0)} SAR',
            ),
            _detailRow(
              Icons.event_rounded,
              'Deadline',
              _fmtDate(bid.deadline),
              valueColor: _isOverdue(bid.deadline) && bid.status == BidStatus.open
                  ? Colors.redAccent
                  : null,
            ),
            _detailRow(
              Icons.location_on_outlined,
              'Location',
              bid.location,
            ),

            const SizedBox(height: 24),

            // Action button
            if (bid.status == BidStatus.open)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContractorRFPDetailsScreen(
                          rfpId: bid.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'Submit Proposal',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: _muted, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: _muted, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filters sheet
  void _openFiltersSheet() async {
    final res = await showModalBottomSheet<BidFilters>(
      context: context,
      backgroundColor: _card2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FiltersSheet(
        initial: _filters,
        accent: _accent,
        muted: _muted,
        line: _line,
      ),
    );
    if (res != null) setState(() => _filters = res);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredBids;
    final openCount = _countByStatus(list, BidStatus.open);
    final submittedCount = _countByStatus(list, BidStatus.submitted);
    final awardedCount = _countByStatus(list, BidStatus.awarded);
    final hasFilters = !_filters.isEmpty;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Bids', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: hasFilters ? _accent : Colors.white,
                ),
                onPressed: _openFiltersSheet,
                tooltip: 'Filter',
              ),
              if (hasFilters)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Search
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: _muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white),
                      cursorColor: _accent,
                      decoration: InputDecoration(
                        hintText: 'Search for a bid...',
                        hintStyle:
                            TextStyle(color: _muted.withOpacity(0.7)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (hasFilters)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _filters = const BidFilters()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: _accent.withOpacity(0.4)),
                        ),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.tune_rounded, color: _muted),
                    onPressed: _openFiltersSheet,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Summary
            _SummaryCard(
              card: _card,
              line: _line,
              accent: _accent,
              muted: _muted,
              total: list.length,
              openCount: openCount,
              submittedCount: submittedCount,
              awardedCount: awardedCount,
              statusColors: {
                BidStatus.open: _statusColor(BidStatus.open),
                BidStatus.submitted: _statusColor(BidStatus.submitted),
                BidStatus.awarded: _statusColor(BidStatus.awarded),
              },
            ),

            const SizedBox(height: 18),

            // Open
            if (openCount > 0) ...[
              _SectionHeader(
                title: 'Open Bids',
                count: openCount,
                muted: _muted,
                color: _statusColor(BidStatus.open),
              ),
              const SizedBox(height: 10),
              ...list
                  .where((b) => b.status == BidStatus.open)
                  .map((b) => _BidCard(
                        bid: b,
                        card: _card,
                        line: _line,
                        statusColor: _statusColor(b.status),
                        muted: _muted,
                        statusLabel: _statusLabel(b.status),
                        statusIcon: _statusIcon(b.status),
                        fmtDate: _fmtDate,
                        isOverdue: _isOverdue(b.deadline),
                        onTap: () => _onTapBid(b),
                      )),
              const SizedBox(height: 18),
            ],

            // Submitted
            if (submittedCount > 0) ...[
              _SectionHeader(
                title: 'Submitted',
                count: submittedCount,
                muted: _muted,
                color: _statusColor(BidStatus.submitted),
              ),
              const SizedBox(height: 10),
              ...list
                  .where((b) => b.status == BidStatus.submitted)
                  .map((b) => _BidCard(
                        bid: b,
                        card: _card,
                        line: _line,
                        statusColor: _statusColor(b.status),
                        muted: _muted,
                        statusLabel: _statusLabel(b.status),
                        statusIcon: _statusIcon(b.status),
                        fmtDate: _fmtDate,
                        isOverdue: false,
                        onTap: () => _onTapBid(b),
                      )),
              const SizedBox(height: 18),
            ],

            // Awarded
            if (awardedCount > 0) ...[
              _SectionHeader(
                title: 'Awarded',
                count: awardedCount,
                muted: _muted,
                color: _statusColor(BidStatus.awarded),
              ),
              const SizedBox(height: 10),
              ...list
                  .where((b) => b.status == BidStatus.awarded)
                  .map((b) => _BidCard(
                        bid: b,
                        card: _card,
                        line: _line,
                        statusColor: _statusColor(b.status),
                        muted: _muted,
                        statusLabel: _statusLabel(b.status),
                        statusIcon: _statusIcon(b.status),
                        fmtDate: _fmtDate,
                        isOverdue: false,
                        onTap: () => _onTapBid(b),
                      )),
            ],

            if (list.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded,
                          color: _muted, size: 40),
                      const SizedBox(height: 12),
                      Text('No bids found',
                          style: TextStyle(color: _muted, fontSize: 14)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Card
class _SummaryCard extends StatelessWidget {
  final Color card, line, accent, muted;
  final int total, openCount, submittedCount, awardedCount;
  final Map<BidStatus, Color> statusColors;

  const _SummaryCard({
    required this.card,
    required this.line,
    required this.accent,
    required this.muted,
    required this.total,
    required this.openCount,
    required this.submittedCount,
    required this.awardedCount,
    required this.statusColors,
  });

  @override
  Widget build(BuildContext context) {
    final done = submittedCount + awardedCount;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$done of $total bids processed',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              Text('${(progress * 100).round()}%',
                  style: TextStyle(color: muted)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: line.withOpacity(0.7),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniPill(
                  label: 'Open',
                  value: openCount,
                  color: statusColors[BidStatus.open]!),
              const SizedBox(width: 8),
              _MiniPill(
                  label: 'Submitted',
                  value: submittedCount,
                  color: statusColors[BidStatus.submitted]!),
              const SizedBox(width: 8),
              _MiniPill(
                  label: 'Awarded',
                  value: awardedCount,
                  color: statusColors[BidStatus.awarded]!),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
            const SizedBox(width: 5),
            Text('$value',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color muted;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.muted,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Text(
            '$count bids',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ── Bid Card
class _BidCard extends StatelessWidget {
  final BidItem bid;
  final Color card, line, statusColor, muted;
  final String statusLabel;
  final IconData statusIcon;
  final String Function(DateTime) fmtDate;
  final bool isOverdue;
  final VoidCallback onTap;

  const _BidCard({
    required this.bid,
    required this.card,
    required this.line,
    required this.statusColor,
    required this.muted,
    required this.statusLabel,
    required this.statusIcon,
    required this.fmtDate,
    required this.isOverdue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: statusColor.withOpacity(0.08),
          highlightColor: statusColor.withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bid.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bid.project} • ${bid.location}',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(
                            Icons.payments_rounded,
                            '${bid.budget.toStringAsFixed(0)} SAR',
                          ),
                          _chip(
                            Icons.event_rounded,
                            'Due ${fmtDate(bid.deadline)}',
                            color: isOverdue ? Colors.redAccent : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Icon(Icons.chevron_right_rounded,
                        color: muted, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, {Color? color}) {
    final c = color ?? muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: c, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Filters Sheet
class _FiltersSheet extends StatefulWidget {
  final BidFilters initial;
  final Color accent, muted, line;

  const _FiltersSheet({
    required this.initial,
    required this.accent,
    required this.muted,
    required this.line,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late BidStatus? _status;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;
  DateTime? _before;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _minCtrl = TextEditingController(
        text: widget.initial.minBudget?.toStringAsFixed(0) ?? '');
    _maxCtrl = TextEditingController(
        text: widget.initial.maxBudget?.toStringAsFixed(0) ?? '');
    _before = widget.initial.beforeDeadline;
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  int get _activeCount {
    int c = 0;
    if (_status != null) c++;
    if (_minCtrl.text.isNotEmpty) c++;
    if (_maxCtrl.text.isNotEmpty) c++;
    if (_before != null) c++;
    return c;
  }

  double? _toDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              if (_activeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$_activeCount active',
                    style: TextStyle(
                        color: widget.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _status = null;
                  _minCtrl.text = '';
                  _maxCtrl.text = '';
                  _before = null;
                }),
                child: Text('Reset all',
                    style: TextStyle(
                        color: widget.accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status
          _label('Status'),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip('Any', _status == null,
                  () => setState(() => _status = null)),
              const SizedBox(width: 8),
              _chip('Open', _status == BidStatus.open,
                  () => setState(() => _status = BidStatus.open)),
              const SizedBox(width: 8),
              _chip('Submitted', _status == BidStatus.submitted,
                  () => setState(() => _status = BidStatus.submitted)),
              const SizedBox(width: 8),
              _chip('Awarded', _status == BidStatus.awarded,
                  () => setState(() => _status = BidStatus.awarded)),
            ],
          ),
          const SizedBox(height: 18),

          // Budget
          _label('Budget Range (SAR)'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_minCtrl, 'Min budget')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('—',
                    style: TextStyle(color: widget.muted, fontSize: 16)),
              ),
              Expanded(child: _field(_maxCtrl, 'Max budget')),
            ],
          ),
          const SizedBox(height: 18),

          // Deadline
          _label('Deadline Before'),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _before ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) setState(() => _before = picked);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _before != null
                        ? widget.accent.withOpacity(0.5)
                        : widget.line),
                borderRadius: BorderRadius.circular(14),
                color: _before != null
                    ? widget.accent.withOpacity(0.05)
                    : Colors.white.withOpacity(0.03),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_rounded,
                      color: _before != null ? widget.accent : widget.muted,
                      size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _before == null
                          ? 'Any date'
                          : '${_before!.year}-${_before!.month.toString().padLeft(2, '0')}-${_before!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color:
                            _before != null ? Colors.white : widget.muted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (_before != null)
                    GestureDetector(
                      onTap: () => setState(() => _before = null),
                      child: Icon(Icons.close_rounded,
                          color: widget.muted, size: 18),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: widget.line),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(
                    context,
                    BidFilters(
                      status: _status,
                      minBudget: _toDouble(_minCtrl.text),
                      maxBudget: _toDouble(_maxCtrl.text),
                      beforeDeadline: _before,
                    ),
                  ),
                  child: Text(
                    _activeCount > 0 ? 'Apply ($_activeCount)' : 'Apply',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(
                color: widget.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? widget.accent.withOpacity(0.16)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? widget.accent.withOpacity(0.7)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? widget.accent : Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );

  Widget _field(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: widget.muted.withOpacity(0.6), fontSize: 13),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: widget.line),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: widget.accent),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
}