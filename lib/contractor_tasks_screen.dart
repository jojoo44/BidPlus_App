import 'package:flutter/material.dart';

class ContractorTasksScreen extends StatefulWidget {
  const ContractorTasksScreen({super.key});

  @override
  State<ContractorTasksScreen> createState() => _ContractorTasksScreenState();
}

class _ContractorTasksScreenState extends State<ContractorTasksScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _quickCtrl = TextEditingController();

  // ✅ تبدأ فاضية
  final List<_TaskItem> _allTasks = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _quickCtrl.dispose();
    super.dispose();
  }

  Color _bg() => const Color(0xFF0B1720);
  Color _card() => const Color(0xFF0F2230);
  Color _line() => const Color(0xFF1F3A4B);
  Color _accent() => const Color(0xFF41C0FF);
  Color _muted() => const Color(0xFF93A7B6);

  void _addQuickTask() {
    final text = _quickCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _allTasks.insert(
        0,
        _TaskItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: text,
          completed: false,
        ),
      );
      _quickCtrl.clear();
    });
  }

  void _toggleTask(_TaskItem t) {
    setState(() {
      t.completed = !t.completed;
    });
  }

  void _deleteTask(_TaskItem t) {
    setState(() {
      _allTasks.remove(t);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = _allTasks.where((e) => !e.completed).toList();
    final completed = _allTasks.where((e) => e.completed).toList();

    final total = _allTasks.length;
    final done = completed.length;
    final progress = total == 0 ? 0.0 : done / total;

    return Scaffold(
      backgroundColor: _bg(),
      appBar: AppBar(
        backgroundColor: _bg(),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Daily Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // ❌ ما فيه FloatingActionButton
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _searchBar(),
            const SizedBox(height: 12),
            _quickAdd(),
            const SizedBox(height: 16),
            _summary(progress, done, total),
            const SizedBox(height: 20),

            _sectionTitle('In Progress', inProgress.length),
            const SizedBox(height: 10),
            ...inProgress.map((t) => _taskCard(t)),

            const SizedBox(height: 20),
            _sectionTitle('Completed Tasks', completed.length),
            const SizedBox(height: 10),
            ...completed.map((t) => _taskCard(t)),

            if (_allTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Center(
                  child: Text(
                    'No tasks found',
                    style: TextStyle(color: _muted()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _card(),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search, color: _muted()),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for a task...',
                hintStyle: TextStyle(color: _muted()),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAdd() {
    return Container(
      decoration: BoxDecoration(
        color: _card(),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _quickCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add a quick new task...',
                hintStyle: TextStyle(color: _muted()),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, color: _accent()),
            onPressed: _addQuickTask,
          ),
        ],
      ),
    );
  }

  Widget _summary(double progress, int done, int total) {
    return Container(
      decoration: BoxDecoration(
        color: _card(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line()),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$done of $total tasks completed',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(color: _muted()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: _line(),
            valueColor: AlwaysStoppedAnimation<Color>(_accent()),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const Spacer(),
        Text('$count tasks', style: TextStyle(color: _muted())),
      ],
    );
  }

  Widget _taskCard(_TaskItem t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line()),
      ),
      child: ListTile(
        leading: Checkbox(
          value: t.completed,
          onChanged: (_) => _toggleTask(t),
          activeColor: _accent(),
        ),
        title: Text(
          t.title,
          style: TextStyle(
            color: Colors.white,
            decoration: t.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'delete') {
              _deleteTask(t);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _TaskItem {
  final String id;
  final String title;
  bool completed;

  _TaskItem({required this.id, required this.title, required this.completed});
}
