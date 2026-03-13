import 'package:flutter/material.dart';

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
      beforeDeadline: clearBeforeDeadline
          ? null
          : (beforeDeadline ?? this.beforeDeadline),
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

  // ✅ بيانات تجريبية (بدّليها لاحقًا ببيانات من الباك-إند)
  // ✅ IMPORTANT: ليست const لأن داخلها DateTime(...)
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

  Color _bg() => const Color(0xFF0B1720);
  Color _card() => const Color(0xFF0F2230);
  Color _card2() => const Color(0xFF0C1C27);
  Color _line() => const Color(0xFF1F3A4B);
  Color _accent() => const Color(0xFF41C0FF);
  Color _muted() => const Color(0xFF93A7B6);

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  List<BidItem> get _filteredBids {
    final q = _searchCtrl.text.trim().toLowerCase();

    bool matchesSearch(BidItem b) {
      if (q.isEmpty) return true;
      return b.title.toLowerCase().contains(q) ||
          b.project.toLowerCase().contains(q) ||
          b.location.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q);
    }

    bool matchesFilters(BidItem b) {
      if (_filters.status != null && b.status != _filters.status) return false;
      if (_filters.minBudget != null && b.budget < _filters.minBudget!) {
        return false;
      }
      if (_filters.maxBudget != null && b.budget > _filters.maxBudget!) {
        return false;
      }
      if (_filters.beforeDeadline != null &&
          b.deadline.isAfter(_filters.beforeDeadline!)) {
        return false;
      }
      return true;
    }

    final out = _allBids
        .where((b) => matchesSearch(b) && matchesFilters(b))
        .toList();

    out.sort((a, b) => a.deadline.compareTo(b.deadline));
    return out;
  }

  int _countByStatus(List<BidItem> list, BidStatus s) =>
      list.where((e) => e.status == s).length;

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

  void _openFiltersSheet() async {
    final res = await showModalBottomSheet<BidFilters>(
      context: context,
      backgroundColor: _card2(),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FiltersSheet(
        initial: _filters,
        accent: _accent(),
        muted: _muted(),
        line: _line(),
      ),
    );

    if (res != null) {
      setState(() => _filters = res);
    }
  }

  void _clearFilters() {
    setState(() => _filters = const BidFilters());
  }

  void _onTapBid(BidItem bid) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open bid details: ${bid.title}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredBids;

    final openCount = _countByStatus(list, BidStatus.open);
    final submittedCount = _countByStatus(list, BidStatus.submitted);
    final awardedCount = _countByStatus(list, BidStatus.awarded);

    return Scaffold(
      backgroundColor: _bg(),
      appBar: AppBar(
        backgroundColor: _bg(),
        elevation: 0,
        title: const Text(
          'Bids',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Menu'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openFiltersSheet,
            tooltip: 'Filter',
          ),
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SearchBar(
              controller: _searchCtrl,
              hint: 'Search for a bid...',
              card: _card(),
              muted: _muted(),
              accent: _accent(),
              onChanged: (_) => setState(() {}),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_filters.isEmpty)
                    InkWell(
                      onTap: _clearFilters,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: _accent(),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    color: _muted(),
                    onPressed: _openFiltersSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              card: _card(),
              line: _line(),
              accent: _accent(),
              muted: _muted(),
              total: list.length,
              openCount: openCount,
              submittedCount: submittedCount,
              awardedCount: awardedCount,
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              title: 'Open Bids',
              count: openCount,
              muted: _muted(),
            ),
            const SizedBox(height: 10),
            ...list
                .where((b) => b.status == BidStatus.open)
                .map(
                  (b) => _BidCard(
                    bid: b,
                    card: _card(),
                    line: _line(),
                    accent: _accent(),
                    muted: _muted(),
                    statusLabel: _statusLabel(b.status),
                    statusIcon: _statusIcon(b.status),
                    fmtDate: _fmtDate,
                    onTap: () => _onTapBid(b),
                  ),
                ),
            const SizedBox(height: 18),
            _SectionHeader(
              title: 'Submitted',
              count: submittedCount,
              muted: _muted(),
            ),
            const SizedBox(height: 10),
            ...list
                .where((b) => b.status == BidStatus.submitted)
                .map(
                  (b) => _BidCard(
                    bid: b,
                    card: _card(),
                    line: _line(),
                    accent: _accent(),
                    muted: _muted(),
                    statusLabel: _statusLabel(b.status),
                    statusIcon: _statusIcon(b.status),
                    fmtDate: _fmtDate,
                    onTap: () => _onTapBid(b),
                  ),
                ),
            const SizedBox(height: 18),
            _SectionHeader(
              title: 'Awarded',
              count: awardedCount,
              muted: _muted(),
            ),
            const SizedBox(height: 10),
            ...list
                .where((b) => b.status == BidStatus.awarded)
                .map(
                  (b) => _BidCard(
                    bid: b,
                    card: _card(),
                    line: _line(),
                    accent: _accent(),
                    muted: _muted(),
                    statusLabel: _statusLabel(b.status),
                    statusIcon: _statusIcon(b.status),
                    fmtDate: _fmtDate,
                    onTap: () => _onTapBid(b),
                  ),
                ),
            if (list.isEmpty) ...[
              const SizedBox(height: 30),
              Center(
                child: Text(
                  'No bids found',
                  style: TextStyle(color: _muted(), fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color card;
  final Color muted;
  final Color accent;
  final void Function(String) onChanged;
  final Widget? trailing;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.card,
    required this.muted,
    required this.accent,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white),
              cursorColor: accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: muted.withOpacity(0.7)),
                border: InputBorder.none,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Color card;
  final Color line;
  final Color accent;
  final Color muted;
  final int total;
  final int openCount;
  final int submittedCount;
  final int awardedCount;

  const _SummaryCard({
    required this.card,
    required this.line,
    required this.accent,
    required this.muted,
    required this.total,
    required this.openCount,
    required this.submittedCount,
    required this.awardedCount,
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
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(color: muted),
              ),
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
                accent: accent,
                muted: muted,
              ),
              const SizedBox(width: 8),
              _MiniPill(
                label: 'Submitted',
                value: submittedCount,
                accent: accent,
                muted: muted,
              ),
              const SizedBox(width: 8),
              _MiniPill(
                label: 'Awarded',
                value: awardedCount,
                accent: accent,
                muted: muted,
              ),
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
  final Color accent;
  final Color muted;

  const _MiniPill({
    required this.label,
    required this.value,
    required this.accent,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              '$value',
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color muted;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count bids',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _BidCard extends StatelessWidget {
  final BidItem bid;
  final Color card;
  final Color line;
  final Color accent;
  final Color muted;
  final String statusLabel;
  final IconData statusIcon;
  final String Function(DateTime) fmtDate;
  final VoidCallback onTap;

  const _BidCard({
    required this.bid,
    required this.card,
    required this.line,
    required this.accent,
    required this.muted,
    required this.statusLabel,
    required this.statusIcon,
    required this.fmtDate,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(statusIcon, color: accent),
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
                    const SizedBox(height: 6),
                    Text(
                      '${bid.project} • ${bid.location}',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.payments_rounded,
                          text: '${bid.budget.toStringAsFixed(0)} SAR',
                          muted: muted,
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.event_rounded,
                          text: 'Due ${fmtDate(bid.deadline)}',
                          muted: muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Icon(Icons.chevron_right_rounded, color: muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color muted;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  final BidFilters initial;
  final Color accent;
  final Color muted;
  final Color line;

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
      text: widget.initial.minBudget?.toStringAsFixed(0) ?? '',
    );
    _maxCtrl = TextEditingController(
      text: widget.initial.maxBudget?.toStringAsFixed(0) ?? '',
    );
    _before = widget.initial.beforeDeadline;
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
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
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _status = null;
                    _minCtrl.text = '';
                    _maxCtrl.text = '';
                    _before = null;
                  });
                },
                child: Text(
                  'Reset',
                  style: TextStyle(
                    color: widget.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerLeft,
            child: Text('Status', style: TextStyle(color: widget.muted)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ChoiceChip(
                label: 'Open',
                selected: _status == BidStatus.open,
                onTap: () => setState(() => _status = BidStatus.open),
                accent: widget.accent,
              ),
              _ChoiceChip(
                label: 'Submitted',
                selected: _status == BidStatus.submitted,
                onTap: () => setState(() => _status = BidStatus.submitted),
                accent: widget.accent,
              ),
              _ChoiceChip(
                label: 'Awarded',
                selected: _status == BidStatus.awarded,
                onTap: () => setState(() => _status = BidStatus.awarded),
                accent: widget.accent,
              ),
              _ChoiceChip(
                label: 'Any',
                selected: _status == null,
                onTap: () => setState(() => _status = null),
                accent: widget.accent,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Budget range (SAR)',
              style: TextStyle(color: widget.muted),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: _minCtrl,
                  hint: 'Min',
                  line: widget.line,
                  muted: widget.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  controller: _maxCtrl,
                  hint: 'Max',
                  line: widget.line,
                  muted: widget.muted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Deadline before',
              style: TextStyle(color: widget.muted),
            ),
          ),
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
              if (picked != null) {
                setState(() => _before = picked);
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: widget.line),
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.03),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, color: widget.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _before == null
                          ? 'Any date'
                          : '${_before!.year}-${_before!.month}-${_before!.day}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (_before != null)
                    IconButton(
                      onPressed: () => setState(() => _before = null),
                      icon: Icon(Icons.close_rounded, color: widget.muted),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: widget.line),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final minB = _toDouble(_minCtrl.text);
                    final maxB = _toDouble(_maxCtrl.text);

                    final filters = BidFilters(
                      status: _status,
                      minBudget: minB,
                      maxBudget: maxB,
                      beforeDeadline: _before,
                    );
                    Navigator.pop(context, filters);
                  },
                  child: const Text(
                    'Apply',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(0.16)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withOpacity(0.7)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color line;
  final Color muted;

  const _Field({
    required this.controller,
    required this.hint,
    required this.line,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: muted.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: line),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: line),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
