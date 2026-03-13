import 'package:flutter/material.dart';
import 'project_details_screen.dart';

class ContractorProjectsScreen extends StatelessWidget {
  const ContractorProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B1220);
    const card = Color(0xFF111A2A);
    const stroke = Color(0xFF22314A);
    const hint = Color(0xFF7F8EA3);
    const primary = Color(0xFF0E8BFF);

    final projects = [
      {'title': 'Yasmin Villa', 'deadline': 'Dec 25', 'rfpId': ''},
      {'title': 'Commerce', 'deadline': 'Dec 18', 'rfpId': ''},
      {'title': 'Build a shopping mall', 'deadline': 'Dec 25', 'rfpId': ''},
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Projects',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: projects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = projects[i];
          return Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: stroke),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1727),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: stroke),
                  ),
                  child: const Icon(Icons.folder_open, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Deadline: ${p['deadline']!}',
                        style: const TextStyle(
                          color: hint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectDetailsScreen(
                          projectTitle: p['title']!,
                          deadline: p['deadline']!,
                          rfpId: p['rfpId']!,
                        ),
                      ),
                    );
                  },
                  child: const Text('View'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
