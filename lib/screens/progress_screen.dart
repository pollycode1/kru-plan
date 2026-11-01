import 'package:flutter/material.dart';

import '../attachments.dart';
import '../models.dart';
import '../scope.dart';
import '../thai_date.dart';

/// ภาพรวม: แต่ละห้องสอนถึงไหนแล้ว ห้องไหนช้ากว่าห้องอื่น
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ความคืบหน้า')),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final s in store.subjects) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Text('${s.name} · ${s.topics.length} เรื่อง',
                          style: theme.textTheme.titleMedium),
                    ),
                    ...() {
                      final gs = store.groups
                          .where((g) => g.subjectId == s.id)
                          .toList();
                      final idxs = {
                        for (final g in gs) g.id: store.currentTopicIndex(g)
                      };
                      final maxIdx =
                          idxs.values.fold(0, (a, b) => a > b ? a : b);
                      return gs.map((g) {
                        final idx = idxs[g.id]!;
                        final behind = maxIdx - idx;
                        final cur = idx < s.topics.length
                            ? s.topics[idx].title
                            : 'สอนครบแล้ว';
                        final color = Color(g.color);
                        return Card(
                          child: ListTile(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ClassDetailScreen(groupId: g.id))),
                            leading: CircleAvatar(
                              backgroundColor: color,
                              child: Text(g.name.split('/').last,
                                  style: const TextStyle(color: Colors.white)),
                            ),
                            title: Row(children: [
                              Text(g.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              if (gs.length > 1 && behind > 0)
                                Text('ช้ากว่า $behind เรื่อง',
                                    style: const TextStyle(
                                        color: Colors.deepOrange,
                                        fontSize: 12)),
                              if (gs.length > 1 && behind == 0)
                                const Text('นำ',
                                    style: TextStyle(
                                        color: Colors.green, fontSize: 12)),
                            ]),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ตอนนี้: $cur'),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: s.topics.isEmpty
                                      ? 0
                                      : idx / s.topics.length,
                                  color: color,
                                  backgroundColor: color.withAlpha(40),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                            trailing: Text(
                                '${s.topics.isEmpty ? 0 : (idx * 100 ~/ s.topics.length)}%'),
                          ),
                        );
                      });
                    }(),
                  ],
                  if (store.subjects.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                          child: Text('ยังไม่มีวิชา ไปเพิ่มที่แท็บ "ตั้งค่า"')),
                    ),
                ],
              ))),
    );
  }
}

/// รายละเอียดห้อง: เช็กลิสต์หัวข้อ + ประวัติการสอน
class ClassDetailScreen extends StatelessWidget {
  final String groupId;
  const ClassDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = store.groupById(groupId);
    if (g == null) return const Scaffold();
    final s = store.subjectById(g.subjectId)!;
    final curIdx = store.currentTopicIndex(g);
    final history = store.logsOf(g.id);
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${g.name} · ${s.name}'),
          bottom:
              const TabBar(tabs: [Tab(text: 'หัวข้อ'), Tab(text: 'ประวัติ')]),
        ),
        body: TabBarView(children: [
          ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'แตะเพื่อติ๊กจบ/ไม่จบ · กดค้างเพื่อตั้งว่า "สอนถึงเรื่องนี้แล้ว"',
                  style: TextStyle(color: cs.outline, fontSize: 12),
                ),
              ),
              for (var i = 0; i < s.topics.length; i++)
                () {
                  final t = s.topics[i];
                  final done = g.doneTopicIds.contains(t.id);
                  final used = history
                      .where((l) =>
                          l.topicId == t.id && l.status != LogStatus.cancelled)
                      .length;
                  return ListTile(
                    tileColor: i == curIdx ? cs.primaryContainer : null,
                    leading: Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done ? Colors.green : cs.outline,
                    ),
                    title: Text(t.title),
                    subtitle:
                        Text('แผน ${t.plannedPeriods} คาบ · สอนไป $used คาบ'
                            '${i == curIdx ? ' · ← สอนต่อเรื่องนี้' : ''}'),
                    onTap: () => store.toggleTopicDone(g, t),
                    onLongPress: () {
                      store.setProgressUpTo(g, i);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'ตั้งให้ ${g.name} สอนต่อที่ "${t.title}"')));
                    },
                  );
                }(),
            ],
          ),
          history.isEmpty
              ? const Center(child: Text('ยังไม่มีบันทึก'))
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final l = history[i];
                    final t =
                        s.topics.where((x) => x.id == l.topicId).firstOrNull;
                    return ListTile(
                      leading: Text(thaiShortFromKey(l.date)),
                      title: Text(t?.title ?? l.status.label),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text([
                            l.status.label,
                            if (l.note.isNotEmpty) l.note,
                            if (l.homework.isNotEmpty) 'การบ้าน: ${l.homework}',
                          ].join(' · ')),
                          const SizedBox(height: 6),
                          AttachmentStrip(
                            items: l.attachments,
                            size: 56,
                            addLabel: 'แนบรูป',
                            onAdd: (items) => store.addLogAttachments(l, items),
                            onRemove: (a) => store.removeLogAttachment(l, a),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ]),
      ),
    );
  }
}
