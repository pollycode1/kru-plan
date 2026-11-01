import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../attachments.dart';
import '../models.dart';
import '../scope.dart';
import '../thai_date.dart';

const _palette = [
  0xFF1E88E5,
  0xFF43A047,
  0xFFFB8C00,
  0xFF8E24AA,
  0xFFE53935,
  0xFF00897B,
  0xFF6D4C41,
  0xFF3949AB,
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    void go(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(children: [
                const _Header('ข้อมูลการสอน'),
                ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: const Text('วิชาและหัวข้อที่ต้องสอน'),
                  subtitle: Text('${store.subjects.length} วิชา'),
                  onTap: () => go(const SubjectsScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.groups),
                  title: const Text('ห้องเรียน'),
                  subtitle: Text('${store.groups.length} ห้อง'),
                  onTap: () => go(const GroupsScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_on),
                  title: const Text('ตารางสอน'),
                  subtitle: Text('${store.slots.length} คาบ/สัปดาห์'),
                  onTap: () => go(const TimetableScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('เวลาแต่ละคาบ'),
                  subtitle: Text('${store.periods.length} คาบ/วัน'),
                  onTap: () => go(const PeriodsScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.beach_access),
                  title: const Text('วันหยุด / งดสอน'),
                  subtitle: Text('${store.holidays.length} วัน'),
                  onTap: () => go(const HolidaysScreen()),
                ),
                const _Header('ข้อมูล'),
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('สำรองข้อมูล (คัดลอก)'),
                  subtitle: const Text(
                      'คัดลอกข้อมูลทั้งหมดไปวางเก็บไว้ เช่น LINE Keep'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: store.exportJson()));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('คัดลอกข้อมูลแล้ว')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('กู้คืนข้อมูล (วาง)'),
                  subtitle: const Text(
                      'วางข้อมูลที่สำรองไว้ ข้อมูลปัจจุบันจะถูกแทนที่'),
                  onTap: () => _restore(context),
                ),
              ]))),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final store = StoreScope.of(context);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('กู้คืนข้อมูล'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
              hintText: 'วางข้อมูลสำรองที่นี่', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('กู้คืน')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      store.importJson(ctrl.text.trim());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กู้คืนเรียบร้อย')));
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ข้อมูลไม่ถูกต้อง')));
    }
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );
}

Future<String?> _ask(BuildContext context, String title,
    {String initial = '', String? hint, int maxLines = 1}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLines: maxLines,
        decoration:
            InputDecoration(hintText: hint, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('ตกลง')),
      ],
    ),
  );
}

Future<bool> _confirm(BuildContext context, String msg) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ')),
        ],
      ),
    ) ??
    false;

// ---------------- วิชา ----------------

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('วิชาและหัวข้อ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final n =
              await _ask(context, 'ชื่อวิชา', hint: 'เช่น คณิตศาสตร์ ม.2');
          if (n != null && n.isNotEmpty) store.addSubject(n);
        },
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มวิชา'),
      ),
      body: ListView(children: [
        for (final s in store.subjects)
          ListTile(
            title: Text(s.name),
            subtitle:
                Text('${s.topics.length} หัวข้อ · ${s.totalPeriods} คาบตามแผน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => TopicsScreen(subjectId: s.id))),
          ),
      ]),
    );
  }
}

class TopicsScreen extends StatelessWidget {
  final String subjectId;
  const TopicsScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.subjectById(subjectId);
    if (s == null) return const Scaffold();
    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
        actions: [
          IconButton(
            tooltip: 'เปลี่ยนชื่อ',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final n = await _ask(context, 'ชื่อวิชา', initial: s.name);
              if (n != null && n.isNotEmpty) store.renameSubject(s, n);
            },
          ),
          IconButton(
            tooltip: 'ลบวิชา',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await _confirm(context,
                  'ลบวิชา "${s.name}" พร้อมห้องเรียน ตารางสอน และบันทึกของวิชานี้?')) {
                store.deleteSubject(s);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final text = await _ask(
            context,
            'เพิ่มหัวข้อ (บรรทัดละเรื่อง)',
            hint:
                '1.1 ทฤษฎีบทพีทาโกรัส | 2\n1.2 บทกลับ | 2\n\n"| 2" = ใช้ 2 คาบ',
            maxLines: 8,
          );
          if (text != null && text.isNotEmpty) store.addTopicsFromText(s, text);
        },
        icon: const Icon(Icons.playlist_add),
        label: const Text('เพิ่มหัวข้อ'),
      ),
      body: s.topics.isEmpty
          ? const Center(
              child: Text('ยังไม่มีหัวข้อ\nคัดลอกสารบัญจากแผนการสอนมาวางได้เลย',
                  textAlign: TextAlign.center))
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: s.topics.length,
              onReorder: (a, b) => store.reorderTopic(s, a, b),
              itemBuilder: (_, i) {
                final t = s.topics[i];
                return ListTile(
                  key: ValueKey(t.id),
                  leading: CircleAvatar(
                      radius: 14,
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 12))),
                  title: Text(t.title),
                  subtitle: Text('${t.plannedPeriods} คาบ'),
                  onTap: () => _editTopic(context, s, t),
                );
              },
            ),
    );
  }

  void _editTopic(BuildContext context, Subject s, Topic t) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TopicEditScreen(subjectId: s.id, topicId: t.id)));
}

/// แก้หัวข้อ: ชื่อ จำนวนคาบ แนวการสอน และสื่อการสอน (ไฟล์ รูป ลิงก์)
class TopicEditScreen extends StatefulWidget {
  final String subjectId;
  final String topicId;
  const TopicEditScreen(
      {super.key, required this.subjectId, required this.topicId});

  @override
  State<TopicEditScreen> createState() => _TopicEditScreenState();
}

class _TopicEditScreenState extends State<TopicEditScreen> {
  TextEditingController? _title;
  TextEditingController? _notes;
  int _n = 1;

  @override
  void dispose() {
    _title?.dispose();
    _notes?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.subjectById(widget.subjectId);
    final t = s?.topics.where((x) => x.id == widget.topicId).firstOrNull;
    if (s == null || t == null) return const Scaffold();
    if (_title == null) {
      _title = TextEditingController(text: t.title);
      _notes = TextEditingController(text: t.notes);
      _n = t.plannedPeriods;
    }
    void save() => _title == null
        ? null
        : store.updateTopic(
            t,
            _title!.text.trim().isEmpty ? t.title : _title!.text.trim(),
            _n,
            _notes!.text.trim());

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('แก้หัวข้อ'),
          actions: [
            IconButton(
              tooltip: 'ลบหัวข้อ',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await _confirm(
                    context, 'ลบหัวข้อ "${t.title}" และสื่อที่แนบไว้?')) {
                  store.deleteTopic(s, t);
                  _title = null;
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'ชื่อหัวข้อ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('จำนวนคาบตามแผน'),
              const Spacer(),
              IconButton(
                  onPressed: _n > 1 ? () => setState(() => _n--) : null,
                  icon: const Icon(Icons.remove)),
              Text('$_n', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                  onPressed: () => setState(() => _n++),
                  icon: const Icon(Icons.add)),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'แนวการสอน / กิจกรรม / สิ่งที่ต้องเตรียม',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text('สื่อการสอน', style: Theme.of(context).textTheme.titleMedium),
            Text(
                'แตะเพื่อเปิด · กดค้างเพื่อลบ · จะขึ้นบนการ์ดหน้า "วันนี้" ด้วย',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 10),
            AttachmentStrip(
              items: t.media,
              size: 84,
              addLabel: 'เพิ่มสื่อ',
              onAdd: (items) => store.addTopicMedia(t, items),
              onRemove: (a) => store.removeTopicMedia(t, a),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- ห้องเรียน ----------------

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ห้องเรียน')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            store.subjects.isEmpty ? null : () => _editGroup(context, null),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มห้อง'),
      ),
      body: store.subjects.isEmpty
          ? const Center(child: Text('เพิ่มวิชาก่อน แล้วค่อยเพิ่มห้อง'))
          : ListView(children: [
              for (final g in store.groups)
                ListTile(
                  leading: CircleAvatar(backgroundColor: Color(g.color)),
                  title: Text(g.name),
                  subtitle: Text(
                      '${store.subjectById(g.subjectId)?.name ?? '-'} · ห้อง ${g.room}'),
                  onTap: () => _editGroup(context, g),
                ),
            ]),
    );
  }

  Future<void> _editGroup(BuildContext context, ClassGroup? g) async {
    final store = StoreScope.of(context);
    final name = TextEditingController(text: g?.name ?? '');
    final room = TextEditingController(text: g?.room ?? '');
    var subjectId = g?.subjectId ?? store.subjects.first.id;
    var color = g?.color ?? _palette[store.groups.length % _palette.length];

    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(g == null ? 'เพิ่มห้องเรียน' : 'แก้ห้องเรียน'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(
                      labelText: 'ชั้น/ห้อง', hintText: 'ม.2/3')),
              TextField(
                  controller: room,
                  decoration: const InputDecoration(
                      labelText: 'ห้องที่สอน', hintText: '305')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: subjectId,
                decoration: const InputDecoration(labelText: 'วิชา'),
                items: [
                  for (final s in store.subjects)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setD(() => subjectId = v!),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () => setD(() => color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(c),
                      child: c == color
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            if (g != null)
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                  child: const Text('ลบ')),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('บันทึก')),
          ],
        ),
      ),
    );
    if (res == 'delete' && g != null && context.mounted) {
      if (await _confirm(
          context, 'ลบห้อง ${g.name} และบันทึกทั้งหมดของห้องนี้?')) {
        store.deleteGroup(g);
      }
    }
    if (res == 'save' && name.text.trim().isNotEmpty) {
      final target =
          g ?? ClassGroup(id: newId(), name: '', subjectId: subjectId);
      if (target.subjectId != subjectId) target.doneTopicIds.clear();
      target
        ..name = name.text.trim()
        ..room = room.text.trim()
        ..subjectId = subjectId
        ..color = color;
      store.upsertGroup(target);
    }
  }
}

// ---------------- ตารางสอน ----------------

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final days = [1, 2, 3, 4, 5];
    final hasWeekend = store.slots.any((s) => s.weekday > 5);
    if (hasWeekend) days.addAll([6, 7]);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('ตารางสอน')),
      body: store.periods.isEmpty
          ? const Center(child: Text('ตั้งเวลาแต่ละคาบก่อน'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                Text('แตะช่องเพื่อเลือกห้องที่สอน',
                    style: TextStyle(color: cs.outline, fontSize: 12)),
                const SizedBox(height: 8),
                Table(
                  border: TableBorder.all(color: cs.outlineVariant),
                  columnWidths: const {0: FixedColumnWidth(40)},
                  children: [
                    TableRow(children: [
                      const SizedBox(),
                      for (final p in store.periods)
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text('${p.period}\n${fmtMin(p.startMin)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11)),
                        ),
                    ]),
                    for (final w in days)
                      TableRow(children: [
                        SizedBox(
                          height: 56,
                          child: Center(child: Text(thaiWeekdaysShort[w - 1])),
                        ),
                        for (final p in store.periods)
                          () {
                            final slot = store.slotAt(w, p.period);
                            final g = slot == null
                                ? null
                                : store.groupById(slot.classGroupId);
                            return InkWell(
                              onTap: () => _pick(context, w, p.period),
                              child: Container(
                                height: 56,
                                color: g == null
                                    ? null
                                    : Color(g.color).withAlpha(60),
                                alignment: Alignment.center,
                                child: Text(g?.name ?? '',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11)),
                              ),
                            );
                          }(),
                      ]),
                  ],
                ),
                const SizedBox(height: 8),
                if (!hasWeekend)
                  TextButton(
                    onPressed: () =>
                        _pick(context, 6, store.periods.first.period),
                    child: const Text('มีสอนวันเสาร์/อาทิตย์?'),
                  ),
              ]),
            ),
    );
  }

  Future<void> _pick(BuildContext context, int weekday, int period) async {
    final store = StoreScope.of(context);
    final res = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(shrinkWrap: true, children: [
        ListTile(
            title: Text('วัน${thaiWeekdays[weekday - 1]} คาบ $period',
                style: Theme.of(ctx).textTheme.titleMedium)),
        for (final g in store.groups)
          ListTile(
            leading: CircleAvatar(backgroundColor: Color(g.color), radius: 10),
            title: Text(g.name),
            subtitle: Text(store.subjectById(g.subjectId)?.name ?? ''),
            onTap: () => Navigator.pop(ctx, g.id),
          ),
        ListTile(
          leading: const Icon(Icons.clear),
          title: const Text('ว่าง (ไม่มีสอน)'),
          onTap: () => Navigator.pop(ctx, ''),
        ),
      ]),
    );
    if (res == null) return;
    store.setSlot(weekday, period, res.isEmpty ? null : res);
  }
}

// ---------------- เวลาคาบ ----------------

class PeriodsScreen extends StatelessWidget {
  const PeriodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.periods;

    Future<void> editTime(PeriodTime p, bool start) async {
      final m = start ? p.startMin : p.endMin;
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
        builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
            child: child!),
      );
      if (t == null) return;
      final v = t.hour * 60 + t.minute;
      if (start) {
        p.startMin = v;
      } else {
        p.endMin = v;
      }
      store.setPeriods(list);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('เวลาแต่ละคาบ')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final last = list.isEmpty ? null : list.last;
          final start = last?.endMin ?? 8 * 60 + 30;
          store.setPeriods([
            ...list,
            PeriodTime((last?.period ?? 0) + 1, start, start + 50),
          ]);
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(children: [
        for (final p in list)
          ListTile(
            leading: CircleAvatar(child: Text('${p.period}')),
            title: Row(children: [
              TextButton(
                  onPressed: () => editTime(p, true),
                  child: Text(fmtMin(p.startMin))),
              const Text('–'),
              TextButton(
                  onPressed: () => editTime(p, false),
                  child: Text(fmtMin(p.endMin))),
            ]),
            trailing: p == list.last
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => store.setPeriods(list..remove(p)),
                  )
                : null,
          ),
      ]),
    );
  }
}

// ---------------- วันหยุด ----------------

class HolidaysScreen extends StatelessWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.holidays.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('วันหยุด / งดสอน')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 2),
            initialDate: now,
          );
          if (d != null && !store.isHoliday(d)) store.toggleHoliday(d);
        },
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มวันหยุด'),
      ),
      body: list.isEmpty
          ? const Center(child: Text('ยังไม่มีวันหยุด'))
          : ListView(children: [
              for (final k in list)
                ListTile(
                  leading: const Icon(Icons.event_busy),
                  title: Text(thaiFullDate(DateTime.parse(k))),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => store.toggleHoliday(DateTime.parse(k)),
                  ),
                ),
            ]),
    );
  }
}
