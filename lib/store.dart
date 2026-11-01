import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attachments.dart';
import 'models.dart';

/// ข้อมูลที่การ์ดหนึ่งใบในหน้า "วันนี้" ต้องใช้
class TodayItem {
  final Slot slot;
  final PeriodTime? time;
  final ClassGroup group;
  final Subject subject;
  final Topic? currentTopic; // เรื่องที่ต้องสอนต่อ
  final int currentIndex; // ลำดับของ currentTopic (0-based)
  final LessonLog? lastLog; // บันทึกล่าสุดก่อนวันนี้ของห้องนี้
  final LessonLog? logToday; // บันทึกของคาบนี้ในวันที่เลือก
  final int periodsUsedOnTopic; // ใช้ไปกี่คาบแล้วกับเรื่องนี้

  TodayItem({
    required this.slot,
    required this.time,
    required this.group,
    required this.subject,
    required this.currentTopic,
    required this.currentIndex,
    required this.lastLog,
    required this.logToday,
    required this.periodsUsedOnTopic,
  });

  int get overPlan =>
      currentTopic == null ? 0 : periodsUsedOnTopic - currentTopic!.plannedPeriods;
}

class AppStore extends ChangeNotifier {
  static const _key = 'kru_plan_v1';

  List<Subject> subjects = [];
  List<ClassGroup> groups = [];
  List<Slot> slots = [];
  List<PeriodTime> periods = [];
  List<LessonLog> logs = [];
  Set<String> holidays = {}; // yyyy-MM-dd

  // ---------- โหลด / บันทึก ----------

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      _seedDemo();
      await save();
    } else {
      importJson(raw, notify: false);
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, exportJson());
  }

  void _changed() {
    notifyListeners();
    save();
  }

  String exportJson() => jsonEncode({
        'v': 1,
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'groups': groups.map((e) => e.toJson()).toList(),
        'slots': slots.map((e) => e.toJson()).toList(),
        'periods': periods.map((e) => e.toJson()).toList(),
        'logs': logs.map((e) => e.toJson()).toList(),
        'holidays': holidays.toList(),
      });

  void importJson(String raw, {bool notify = true}) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    List<Map<String, dynamic>> list(String k) => (j[k] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    subjects = list('subjects').map(Subject.fromJson).toList();
    groups = list('groups').map(ClassGroup.fromJson).toList();
    slots = list('slots').map(Slot.fromJson).toList();
    periods = list('periods').map(PeriodTime.fromJson).toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    logs = list('logs').map(LessonLog.fromJson).toList();
    holidays = Set<String>.from(j['holidays'] ?? const []);
    if (notify) _changed();
  }

  // ---------- ค้นหา ----------

  Subject? subjectById(String id) =>
      subjects.where((s) => s.id == id).firstOrNull;
  ClassGroup? groupById(String id) => groups.where((g) => g.id == id).firstOrNull;
  PeriodTime? periodTime(int p) => periods.where((t) => t.period == p).firstOrNull;

  /// เรื่องถัดไปที่ยังไม่จบของห้องนี้ (เรียงตามลำดับในหลักสูตร)
  int currentTopicIndex(ClassGroup g) {
    final s = subjectById(g.subjectId);
    if (s == null) return -1;
    for (var i = 0; i < s.topics.length; i++) {
      if (!g.doneTopicIds.contains(s.topics[i].id)) return i;
    }
    return s.topics.length; // จบหลักสูตรแล้ว
  }

  List<LessonLog> logsOf(String groupId) =>
      logs.where((l) => l.classGroupId == groupId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  bool isHoliday(DateTime d) => holidays.contains(dateKey(d));

  List<TodayItem> itemsFor(DateTime day) {
    final key = dateKey(day);
    final daySlots = slots.where((s) => s.weekday == day.weekday).toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    final out = <TodayItem>[];
    for (final slot in daySlots) {
      final g = groupById(slot.classGroupId);
      if (g == null) continue;
      final s = subjectById(g.subjectId);
      if (s == null) continue;
      final groupLogs = logsOf(g.id);
      final logToday = groupLogs
          .where((l) => l.date == key && l.slotId == slot.id)
          .firstOrNull;

      // ถ้าคาบนี้บันทึกแล้ว ให้แสดงเรื่องที่สอนไปในคาบนั้น
      Topic? topic;
      int idx;
      if (logToday?.topicId != null) {
        idx = s.topics.indexWhere((t) => t.id == logToday!.topicId);
        topic = idx >= 0 ? s.topics[idx] : null;
      } else {
        idx = currentTopicIndex(g);
        topic = (idx >= 0 && idx < s.topics.length) ? s.topics[idx] : null;
      }
      final before = groupLogs
          .where((l) =>
              l.status != LogStatus.cancelled &&
              (l.date.compareTo(key) < 0 || (l.date == key && l.slotId != slot.id)))
          .toList();
      final used = topic == null
          ? 0
          : before.where((l) => l.topicId == topic!.id).length +
              (logToday != null && logToday.status != LogStatus.cancelled ? 1 : 0);
      out.add(TodayItem(
        slot: slot,
        time: periodTime(slot.period),
        group: g,
        subject: s,
        currentTopic: topic,
        currentIndex: idx,
        lastLog: before.firstOrNull,
        logToday: logToday,
        periodsUsedOnTopic: used,
      ));
    }
    return out;
  }

  // ---------- บันทึกการสอน ----------

  void logLesson({
    required DateTime day,
    required TodayItem item,
    required LogStatus status,
    String note = '',
    String homework = '',
    List<Attachment> attachments = const [],
  }) {
    final key = dateKey(day);
    // แก้ไขบันทึกเดิมของคาบนี้ (ถ้ามี) — ย้อนสถานะ done เดิมก่อน
    final old = logs
        .where((l) => l.date == key && l.slotId == item.slot.id)
        .firstOrNull;
    if (old != null) {
      if (old.status == LogStatus.done && old.topicId != null) {
        item.group.doneTopicIds.remove(old.topicId);
      }
      // ไฟล์ที่ถูกเอาออกจากบันทึกเดิม ให้ลบทิ้ง
      final keep = attachments.map((a) => a.id).toSet();
      for (final a in old.attachments) {
        if (!keep.contains(a.id)) AttachmentService.delete(a);
      }
      logs.remove(old);
    }
    final topicId = item.currentTopic?.id;
    logs.add(LessonLog(
      id: newId(),
      date: key,
      slotId: item.slot.id,
      classGroupId: item.group.id,
      topicId: status == LogStatus.cancelled ? null : topicId,
      status: status,
      note: note,
      homework: homework,
      attachments: List.of(attachments),
    ));
    if (status == LogStatus.done && topicId != null) {
      item.group.doneTopicIds.add(topicId);
    }
    _changed();
  }

  void undoLog(DateTime day, TodayItem item) {
    final log = item.logToday;
    if (log == null) return;
    if (log.status == LogStatus.done && log.topicId != null) {
      item.group.doneTopicIds.remove(log.topicId);
    }
    for (final a in log.attachments) {
      AttachmentService.delete(a);
    }
    logs.remove(log);
    _changed();
  }

  /// ตั้งค่าเองว่าห้องนี้สอนถึงไหนแล้ว (ใช้ตอนเริ่มใช้แอพกลางเทอม)
  void setProgressUpTo(ClassGroup g, int indexExclusive) {
    final s = subjectById(g.subjectId);
    if (s == null) return;
    g.doneTopicIds = s.topics.take(indexExclusive).map((t) => t.id).toSet();
    _changed();
  }

  void toggleTopicDone(ClassGroup g, Topic t) {
    if (!g.doneTopicIds.remove(t.id)) g.doneTopicIds.add(t.id);
    _changed();
  }

  // ---------- แก้ไขข้อมูลตั้งต้น ----------

  void addSubject(String name) {
    subjects.add(Subject(id: newId(), name: name));
    _changed();
  }

  void renameSubject(Subject s, String name) {
    s.name = name;
    _changed();
  }

  void deleteSubject(Subject s) {
    final gIds = groups.where((g) => g.subjectId == s.id).map((g) => g.id).toSet();
    groups.removeWhere((g) => gIds.contains(g.id));
    slots.removeWhere((x) => gIds.contains(x.classGroupId));
    logs.removeWhere((l) => gIds.contains(l.classGroupId));
    subjects.remove(s);
    _changed();
  }

  /// วางรายการหัวข้อทีละบรรทัด ใส่ "| 3" ท้ายบรรทัดเพื่อกำหนดจำนวนคาบ
  void addTopicsFromText(Subject s, String text) {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final parts = t.split('|');
      final title = parts.first.trim();
      final n = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 1 : 1;
      s.topics.add(Topic(id: newId(), title: title, plannedPeriods: n));
    }
    _changed();
  }

  void updateTopic(Topic t, String title, int planned, String notes) {
    t.title = title;
    t.plannedPeriods = planned < 1 ? 1 : planned;
    t.notes = notes;
    _changed();
  }

  void addTopicMedia(Topic t, List<Attachment> items) {
    t.media.addAll(items);
    _changed();
  }

  void removeTopicMedia(Topic t, Attachment a) {
    t.media.remove(a);
    AttachmentService.delete(a);
    _changed();
  }

  void addLogAttachments(LessonLog l, List<Attachment> items) {
    l.attachments.addAll(items);
    _changed();
  }

  void removeLogAttachment(LessonLog l, Attachment a) {
    l.attachments.remove(a);
    AttachmentService.delete(a);
    _changed();
  }

  Topic? topicById(String? id) {
    if (id == null) return null;
    for (final s in subjects) {
      for (final t in s.topics) {
        if (t.id == id) return t;
      }
    }
    return null;
  }

  void deleteTopic(Subject s, Topic t) {
    for (final a in t.media) {
      AttachmentService.delete(a);
    }
    s.topics.remove(t);
    for (final g in groups) {
      g.doneTopicIds.remove(t.id);
    }
    _changed();
  }

  void reorderTopic(Subject s, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final t = s.topics.removeAt(oldIndex);
    s.topics.insert(newIndex, t);
    _changed();
  }

  void upsertGroup(ClassGroup g) {
    if (!groups.contains(g)) groups.add(g);
    _changed();
  }

  void deleteGroup(ClassGroup g) {
    groups.remove(g);
    slots.removeWhere((s) => s.classGroupId == g.id);
    logs.removeWhere((l) => l.classGroupId == g.id);
    _changed();
  }

  Slot? slotAt(int weekday, int period) => slots
      .where((s) => s.weekday == weekday && s.period == period)
      .firstOrNull;

  void setSlot(int weekday, int period, String? groupId) {
    slots.removeWhere((s) => s.weekday == weekday && s.period == period);
    if (groupId != null) {
      slots.add(Slot(
          id: newId(), weekday: weekday, period: period, classGroupId: groupId));
    }
    _changed();
  }

  void setPeriods(List<PeriodTime> list) {
    periods = list..sort((a, b) => a.period.compareTo(b.period));
    _changed();
  }

  void toggleHoliday(DateTime d) {
    final k = dateKey(d);
    if (!holidays.remove(k)) holidays.add(k);
    _changed();
  }

  // ---------- ข้อมูลตัวอย่างตอนเปิดครั้งแรก ----------

  void _seedDemo() {
    int t(int h, int m) => h * 60 + m;
    periods = [
      PeriodTime(1, t(8, 30), t(9, 20)),
      PeriodTime(2, t(9, 20), t(10, 10)),
      PeriodTime(3, t(10, 20), t(11, 10)),
      PeriodTime(4, t(11, 10), t(12, 0)),
      PeriodTime(5, t(13, 0), t(13, 50)),
      PeriodTime(6, t(13, 50), t(14, 40)),
      PeriodTime(7, t(14, 50), t(15, 40)),
    ];
    final math = Subject(id: 'math2', name: 'คณิตศาสตร์ ม.2');
    for (final (title, n) in [
      ('1.1 ทฤษฎีบทพีทาโกรัส', 2),
      ('1.2 บทกลับของทฤษฎีบทพีทาโกรัส', 2),
      ('1.3 การนำไปใช้', 3),
      ('2.1 จำนวนตรรกยะ', 2),
      ('2.2 รากที่สอง', 3),
      ('2.3 รากที่สาม', 2),
      ('3.1 ปริซึม', 3),
      ('3.2 ทรงกระบอก', 3),
    ]) {
      math.topics.add(Topic(id: newId() + title.hashCode.toString(), title: title, plannedPeriods: n));
    }
    math.topics[3]
      ..notes = 'เริ่มด้วยเกมทายเศษส่วน แล้วให้แปลงทศนิยมซ้ำเป็นเศษส่วน'
      ..media.add(Attachment(
          id: 'demo-link',
          kind: AttachKind.link,
          name: 'วิดีโอ YouTube',
          url: 'https://www.youtube.com/results?search_query=จำนวนตรรกยะ+ม.2'));
    final sci = Subject(id: 'sci1', name: 'วิทยาศาสตร์ ม.1');
    for (final (title, n) in [
      ('1.1 สารบริสุทธิ์', 2),
      ('1.2 สารผสม', 2),
      ('1.3 การแยกสาร', 3),
      ('2.1 เซลล์', 3),
      ('2.2 การลำเลียงสาร', 2),
    ]) {
      sci.topics.add(Topic(id: newId() + title.hashCode.toString(), title: title, plannedPeriods: n));
    }
    subjects = [math, sci];
    groups = [
      ClassGroup(id: 'g21', name: 'ม.2/1', room: '305', subjectId: math.id, color: 0xFF1E88E5)
        ..doneTopicIds = math.topics.take(3).map((e) => e.id).toSet(),
      ClassGroup(id: 'g23', name: 'ม.2/3', room: '307', subjectId: math.id, color: 0xFF43A047)
        ..doneTopicIds = math.topics.take(2).map((e) => e.id).toSet(),
      ClassGroup(id: 'g12', name: 'ม.1/2', room: 'Lab 2', subjectId: sci.id, color: 0xFFFB8C00)
        ..doneTopicIds = sci.topics.take(1).map((e) => e.id).toSet(),
    ];
    var n = 0;
    void put(int w, int p, String g) =>
        slots.add(Slot(id: 's${n++}', weekday: w, period: p, classGroupId: g));
    for (var w = 1; w <= 5; w++) {
      put(w, 1 + (w % 3), 'g21');
      put(w, 4, 'g23');
      if (w != 3) put(w, 6, 'g12');
    }
  }
}
