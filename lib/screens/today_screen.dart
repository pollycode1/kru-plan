import 'dart:async';

import 'package:flutter/material.dart';

import '../attachments.dart';
import '../models.dart';
import '../scope.dart';
import '../store.dart';
import '../thai_date.dart';

/// หน้าแรก: เปิดตอนเช้าแล้วรู้ทันทีว่าวันนี้สอนอะไร ห้องไหน ถึงไหนแล้ว
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime _day = dateOnly(DateTime.now());
  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _isToday => _day == dateOnly(_now);

  void _shift(int days) =>
      setState(() => _day = _day.add(Duration(days: days)));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = store.itemsFor(_day);
    final holiday = store.isHoliday(_day);
    final nowMin = _now.hour * 60 + _now.minute;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isToday ? 'วันนี้' : _relativeLabel(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(thaiFullDate(_day),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'วันก่อน',
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left)),
          if (!_isToday)
            TextButton(
                onPressed: () =>
                    setState(() => _day = dateOnly(DateTime.now())),
                child: const Text('วันนี้')),
          IconButton(
              tooltip: 'วันถัดไป',
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right)),
          PopupMenuButton<String>(
            onSelected: (_) => store.toggleHoliday(_day),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'holiday',
                child: Text(
                    holiday ? 'ยกเลิกวันหยุด' : 'ตั้งเป็นวันหยุด/งดสอนทั้งวัน'),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -300) _shift(1);
          if (v > 300) _shift(-1);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            if (holiday)
              _HolidayBanner(onUndo: () => store.toggleHoliday(_day))
            else if (items.isEmpty)
              const _EmptyDay()
            else ...[
              _SummaryCard(items: items, nowMin: nowMin, isToday: _isToday),
              const SizedBox(height: 8),
              // iPad แนวนอน/จอกว้าง: วางการ์ด 2 คอลัมน์
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 860 ? 2 : 1;
                final w = (c.maxWidth - (cols - 1) * 8) / cols;
                return Wrap(
                  spacing: 8,
                  children: [
                    for (final it in items)
                      SizedBox(
                        width: w,
                        child: _LessonCard(
                          item: it,
                          day: _day,
                          state: _isToday
                              ? _slotState(it, nowMin)
                              : _SlotState.none,
                        ),
                      ),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _relativeLabel() {
    final diff = _day.difference(dateOnly(_now)).inDays;
    if (diff == 1) return 'พรุ่งนี้';
    if (diff == -1) return 'เมื่อวาน';
    return diff > 0 ? 'อีก $diff วัน' : '${-diff} วันก่อน';
  }

  _SlotState _slotState(TodayItem it, int nowMin) {
    final t = it.time;
    if (t == null) return _SlotState.none;
    if (nowMin >= t.startMin && nowMin < t.endMin) return _SlotState.now;
    if (nowMin >= t.endMin) return _SlotState.past;
    return _SlotState.upcoming;
  }
}

enum _SlotState { none, past, now, upcoming }

class _SummaryCard extends StatelessWidget {
  final List<TodayItem> items;
  final int nowMin;
  final bool isToday;
  const _SummaryCard(
      {required this.items, required this.nowMin, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rooms = items.map((e) => e.group.id).toSet().length;
    final logged = items.where((e) => e.logToday != null).length;

    String headline = 'สอน ${items.length} คาบ · $rooms ห้อง';
    String? sub;
    if (isToday) {
      final current = items.where((e) =>
          e.time != null &&
          nowMin >= e.time!.startMin &&
          nowMin < e.time!.endMin);
      final next =
          items.where((e) => e.time != null && e.time!.startMin > nowMin);
      if (current.isNotEmpty) {
        final c = current.first;
        sub =
            'ตอนนี้: คาบ ${c.slot.period} ${c.group.name} ห้อง ${c.group.room}'
            ' (เหลือ ${c.time!.endMin - nowMin} นาที)';
      } else if (next.isNotEmpty) {
        final n = next.first;
        final mins = n.time!.startMin - nowMin;
        final wait =
            mins >= 60 ? '${mins ~/ 60} ชม. ${mins % 60} นาที' : '$mins นาที';
        sub =
            'ถัดไป: คาบ ${n.slot.period} ${n.group.name} ห้อง ${n.group.room} ในอีก $wait';
      } else {
        sub = logged < items.length
            ? 'สอนครบแล้ว · ยังไม่บันทึก ${items.length - logged} คาบ'
            : 'สอนครบและบันทึกครบแล้ว 🎉';
      }
    }

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(color: cs.onPrimaryContainer)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final TodayItem item;
  final DateTime day;
  final _SlotState state;
  const _LessonCard(
      {required this.item, required this.day, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = Color(item.group.color);
    final log = item.logToday;
    final total = item.subject.topics.length;
    final done = item.group.doneTopicIds.length;
    final finishedCourse = item.currentTopic == null;

    return Opacity(
      opacity: state == _SlotState.past && log != null ? 0.6 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: state == _SlotState.now
              ? BorderSide(color: cs.primary, width: 2.5)
              : BorderSide.none,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 8, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // แถวบน: คาบ / เวลา / สถานะ
                      Row(
                        children: [
                          Text('คาบ ${item.slot.period}',
                              style: theme.textTheme.labelLarge),
                          if (item.time != null)
                            Text('  ${item.time!.label}',
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: cs.outline)),
                          const Spacer(),
                          if (state == _SlotState.now)
                            _Chip('กำลังสอน', cs.primary, cs.onPrimary),
                          if (state == _SlotState.past && log == null)
                            _Chip('ยังไม่บันทึก', cs.errorContainer,
                                cs.onErrorContainer),
                          if (log != null)
                            _Chip(log.status.label, _statusColor(log.status),
                                Colors.white),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // ห้อง + ห้องเรียน
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(item.group.name,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          if (item.group.room.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(children: [
                                Icon(Icons.meeting_room_outlined,
                                    size: 16, color: cs.outline),
                                Text(' ${item.group.room}',
                                    style: TextStyle(color: cs.outline)),
                              ]),
                            ),
                        ],
                      ),
                      Text(item.subject.name,
                          style: TextStyle(color: cs.outline, fontSize: 13)),
                      const Divider(height: 18),
                      // สอนเรื่องอะไร
                      if (finishedCourse)
                        const Text('✅ สอนครบทุกหัวข้อแล้ว')
                      else ...[
                        Text(log == null ? 'สอนต่อ' : 'สอนเรื่อง',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: cs.outline)),
                        Text(item.currentTopic!.title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'คาบที่ ${item.periodsUsedOnTopic + (log == null ? 1 : 0)}'
                          ' จากแผน ${item.currentTopic!.plannedPeriods} คาบ'
                          '${_overText()}',
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  _isOver() ? Colors.deepOrange : cs.outline),
                        ),
                        if (item.currentTopic!.notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _NoteBox(
                              icon: Icons.lightbulb_outline,
                              text: item.currentTopic!.notes),
                        ],
                        if (item.currentTopic!.media.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                              'สื่อการสอน (${item.currentTopic!.media.length})',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: cs.outline)),
                          const SizedBox(height: 4),
                          AttachmentStrip(
                              items: item.currentTopic!.media, size: 52),
                        ],
                      ],
                      // คาบก่อนถึงไหน
                      if (item.lastLog != null && log == null) ...[
                        const SizedBox(height: 8),
                        _LastNote(log: item.lastLog!),
                      ],
                      if (log != null &&
                          (log.note.isNotEmpty || log.homework.isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        _NoteBox(
                          icon: Icons.edit_note,
                          text: [
                            if (log.note.isNotEmpty) log.note,
                            if (log.homework.isNotEmpty)
                              'การบ้าน: ${log.homework}',
                          ].join('\n'),
                        ),
                      ],
                      if (log != null && log.attachments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        AttachmentStrip(items: log.attachments, size: 52),
                      ],
                      const SizedBox(height: 8),
                      // ความคืบหน้าทั้งวิชา
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : done / total,
                              minHeight: 6,
                              color: color,
                              backgroundColor: color.withAlpha(40),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$done/$total เรื่อง',
                            style: theme.textTheme.labelSmall),
                      ]),
                      // ปุ่มบันทึก
                      if (!finishedCourse || log != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: log == null
                              ? _ActionRow(item: item, day: day)
                              : Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        showLogSheet(context, item, day),
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('แก้บันทึก'),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isOver() =>
      item.periodsUsedOnTopic + (item.logToday == null ? 1 : 0) >
      (item.currentTopic?.plannedPeriods ?? 99);

  String _overText() {
    if (!_isOver()) return '';
    final over = item.periodsUsedOnTopic +
        (item.logToday == null ? 1 : 0) -
        item.currentTopic!.plannedPeriods;
    return ' · เกินแผน $over คาบ';
  }
}

class _ActionRow extends StatelessWidget {
  final TodayItem item;
  final DateTime day;
  const _ActionRow({required this.item, required this.day});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              store.logLesson(day: day, item: item, status: LogStatus.done);
              _snack(
                  context,
                  'บันทึกแล้ว: จบเรื่อง ${item.currentTopic?.title}',
                  () => store.undoLog(
                      day,
                      store
                          .itemsFor(day)
                          .firstWhere((e) => e.slot.id == item.slot.id)));
            },
            icon: const Icon(Icons.check),
            label: const Text('จบเรื่องนี้'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                showLogSheet(context, item, day, initial: LogStatus.partial),
            icon: const Icon(Icons.more_horiz),
            label: const Text('ยังไม่จบ'),
          ),
        ),
        IconButton(
          tooltip: 'งดสอน / บันทึกอื่น',
          onPressed: () =>
              showLogSheet(context, item, day, initial: LogStatus.cancelled),
          icon: const Icon(Icons.event_busy),
        ),
      ],
    );
  }
}

void _snack(BuildContext context, String msg, VoidCallback undo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      action: SnackBarAction(label: 'เลิกทำ', onPressed: undo),
    ));
}

/// แผ่นบันทึกหลังสอน: สถานะ + ถึงตรงไหน + การบ้าน
Future<void> showLogSheet(BuildContext context, TodayItem item, DateTime day,
    {LogStatus? initial}) {
  final store = StoreScope.of(context);
  var status = initial ?? item.logToday?.status ?? LogStatus.partial;
  final note = TextEditingController(text: item.logToday?.note ?? '');
  final hw = TextEditingController(text: item.logToday?.homework ?? '');
  final atts = List<Attachment>.of(item.logToday?.attachments ?? const []);
  final originalIds = atts.map((a) => a.id).toSet();
  var saved = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${item.group.name} · คาบ ${item.slot.period}',
                style: Theme.of(ctx).textTheme.titleLarge),
            if (item.currentTopic != null)
              Text(item.currentTopic!.title,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.outline)),
            const SizedBox(height: 16),
            SegmentedButton<LogStatus>(
              segments: const [
                ButtonSegment(
                    value: LogStatus.done,
                    label: Text('จบเรื่อง'),
                    icon: Icon(Icons.check)),
                ButtonSegment(
                    value: LogStatus.partial,
                    label: Text('ยังไม่จบ'),
                    icon: Icon(Icons.more_horiz)),
                ButtonSegment(
                    value: LogStatus.cancelled,
                    label: Text('งดสอน'),
                    icon: Icon(Icons.event_busy)),
              ],
              selected: {status},
              onSelectionChanged: (s) => setSheet(() => status = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              autofocus: status == LogStatus.partial,
              decoration: InputDecoration(
                labelText: status == LogStatus.cancelled
                    ? 'เหตุผล (เช่น กิจกรรมโรงเรียน)'
                    : 'ถึงตรงไหน / หมายเหตุ',
                hintText: 'เช่น ถึงตัวอย่างที่ 3 หน้า 24',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (status != LogStatus.cancelled) ...[
              const SizedBox(height: 12),
              TextField(
                controller: hw,
                decoration: const InputDecoration(
                  labelText: 'การบ้าน / งานที่สั่ง (ถ้ามี)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('รูป / ไฟล์ของคาบนี้',
                style: Theme.of(ctx).textTheme.labelLarge),
            const SizedBox(height: 6),
            AttachmentStrip(
              items: atts,
              addLabel: 'ถ่าย/แนบ',
              onAdd: (items) => setSheet(() => atts.addAll(items)),
              onRemove: (a) => setSheet(() {
                atts.remove(a);
                if (!originalIds.contains(a.id)) AttachmentService.delete(a);
              }),
            ),
            const SizedBox(height: 16),
            Row(children: [
              if (item.logToday != null)
                TextButton(
                  onPressed: () {
                    store.undoLog(day, item);
                    saved = true;
                    Navigator.pop(ctx);
                  },
                  child: const Text('ลบบันทึก'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  store.logLesson(
                    day: day,
                    item: item,
                    status: status,
                    note: note.text.trim(),
                    homework: hw.text.trim(),
                    attachments: atts,
                  );
                  saved = true;
                  Navigator.pop(ctx);
                },
                child: const Text('บันทึก'),
              ),
            ]),
          ],
        ),
      ),
    ),
  ).whenComplete(() {
    if (!saved) {
      for (final a in atts) {
        if (!originalIds.contains(a.id)) AttachmentService.delete(a);
      }
    }
  });
}

class _LastNote extends StatelessWidget {
  final LessonLog log;
  const _LastNote({required this.log});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      'คาบก่อน (${thaiShortFromKey(log.date)}): ${log.status.label}',
      if (log.note.isNotEmpty) log.note,
      if (log.homework.isNotEmpty) '📌 ตรวจการบ้าน: ${log.homework}',
    ];
    final box = _NoteBox(icon: Icons.history, text: parts.join('\n'));
    if (log.attachments.isEmpty) return box;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      box,
      const SizedBox(height: 6),
      AttachmentStrip(items: log.attachments, size: 52),
    ]);
  }
}

class _NoteBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NoteBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Chip(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12)),
      );
}

Color _statusColor(LogStatus s) => switch (s) {
      LogStatus.done => Colors.green.shade600,
      LogStatus.partial => Colors.amber.shade800,
      LogStatus.cancelled => Colors.grey.shade600,
    };

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(children: [
          Icon(Icons.free_breakfast_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('วันนี้ไม่มีคาบสอน'),
        ]),
      );
}

class _HolidayBanner extends StatelessWidget {
  final VoidCallback onUndo;
  const _HolidayBanner({required this.onUndo});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(children: [
          const Icon(Icons.beach_access, size: 64, color: Colors.teal),
          const SizedBox(height: 12),
          const Text('วันหยุด / งดการเรียนการสอน'),
          TextButton(onPressed: onUndo, child: const Text('ไม่ใช่วันหยุด')),
        ]),
      );
}
