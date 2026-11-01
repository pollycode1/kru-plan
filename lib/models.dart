// โครงข้อมูลของแอพ: วิชา > หัวข้อ, ห้องเรียน, ตารางสอน, เวลาคาบ, บันทึกการสอน

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum AttachKind { image, file, link }

/// ไฟล์/รูป/ลิงก์ที่แนบ (สื่อการสอน หรือรูปถ่ายหลังสอน)
class Attachment {
  String id;
  AttachKind kind;
  String name;
  String? path; // ไฟล์ที่คัดลอกเก็บในเครื่อง (มือถือ)
  String? url; // สำหรับลิงก์ เช่น YouTube, Google Slides
  String? dataB64; // ใช้บนเว็บ เก็บไฟล์เล็กเป็น base64

  Attachment({
    required this.id,
    required this.kind,
    required this.name,
    this.path,
    this.url,
    this.dataB64,
  });

  String get ext {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'k': kind.name,
        'n': name,
        if (path != null) 'p': path,
        if (url != null) 'u': url,
        if (dataB64 != null) 'd': dataB64,
      };
  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'],
        kind: AttachKind.values.byName(j['k']),
        name: j['n'] ?? '',
        path: j['p'],
        url: j['u'],
        dataB64: j['d'],
      );
}

List<Attachment> _atts(dynamic v) => (v as List? ?? [])
    .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e)))
    .toList();

class Topic {
  String id;
  String title;
  int plannedPeriods; // จำนวนคาบที่วางแผนไว้
  String notes; // แนวการสอน/กิจกรรม
  List<Attachment> media; // สื่อการสอนของหัวข้อนี้

  Topic(
      {required this.id,
      required this.title,
      this.plannedPeriods = 1,
      this.notes = '',
      List<Attachment>? media})
      : media = media ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'planned': plannedPeriods,
        if (notes.isNotEmpty) 'notes': notes,
        if (media.isNotEmpty) 'media': media.map((e) => e.toJson()).toList(),
      };
  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        id: j['id'],
        title: j['title'],
        plannedPeriods: j['planned'] ?? 1,
        notes: j['notes'] ?? '',
        media: _atts(j['media']),
      );
}

class Subject {
  String id;
  String name;
  List<Topic> topics;

  Subject({required this.id, required this.name, List<Topic>? topics})
      : topics = topics ?? [];

  int get totalPeriods => topics.fold(0, (s, t) => s + t.plannedPeriods);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'topics': topics.map((t) => t.toJson()).toList(),
      };
  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        id: j['id'],
        name: j['name'],
        topics: (j['topics'] as List? ?? [])
            .map((e) => Topic.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// ห้องเรียนหนึ่งห้องที่เรียนวิชาหนึ่ง เช่น ม.2/3 วิชาคณิตศาสตร์ ห้อง 305
class ClassGroup {
  String id;
  String name;
  String room;
  String subjectId;
  int color;
  Set<String> doneTopicIds; // หัวข้อที่สอนจบแล้วในห้องนี้

  ClassGroup({
    required this.id,
    required this.name,
    required this.subjectId,
    this.room = '',
    this.color = 0xFF3F51B5,
    Set<String>? doneTopicIds,
  }) : doneTopicIds = doneTopicIds ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room,
        'subjectId': subjectId,
        'color': color,
        'done': doneTopicIds.toList(),
      };
  factory ClassGroup.fromJson(Map<String, dynamic> j) => ClassGroup(
        id: j['id'],
        name: j['name'],
        room: j['room'] ?? '',
        subjectId: j['subjectId'],
        color: j['color'] ?? 0xFF3F51B5,
        doneTopicIds: Set<String>.from(j['done'] ?? const []),
      );
}

/// เวลาของคาบ เก็บเป็นนาทีนับจากเที่ยงคืน
class PeriodTime {
  int period;
  int startMin;
  int endMin;

  PeriodTime(this.period, this.startMin, this.endMin);

  String get label => '${fmtMin(startMin)}–${fmtMin(endMin)}';

  Map<String, dynamic> toJson() => {'p': period, 's': startMin, 'e': endMin};
  factory PeriodTime.fromJson(Map<String, dynamic> j) =>
      PeriodTime(j['p'], j['s'], j['e']);
}

String fmtMin(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// ช่องในตารางสอน: วัน (1=จันทร์ ... 7=อาทิตย์) + คาบ + ห้อง
class Slot {
  String id;
  int weekday;
  int period;
  String classGroupId;

  Slot(
      {required this.id,
      required this.weekday,
      required this.period,
      required this.classGroupId});

  Map<String, dynamic> toJson() =>
      {'id': id, 'w': weekday, 'p': period, 'c': classGroupId};
  factory Slot.fromJson(Map<String, dynamic> j) =>
      Slot(id: j['id'], weekday: j['w'], period: j['p'], classGroupId: j['c']);
}

enum LogStatus { done, partial, cancelled }

extension LogStatusX on LogStatus {
  String get label => switch (this) {
        LogStatus.done => 'จบเรื่องแล้ว',
        LogStatus.partial => 'ยังไม่จบ',
        LogStatus.cancelled => 'งดสอน',
      };
}

/// บันทึกหลังสอน 1 คาบ
class LessonLog {
  String id;
  String date; // yyyy-MM-dd
  String slotId; // ว่างได้ถ้าบันทึกนอกตาราง
  String classGroupId;
  String? topicId;
  LogStatus status;
  String note; // เช่น "ถึงข้อ 5 หน้า 32"
  String homework;
  List<Attachment> attachments; // รูปกระดาน งานนักเรียน ฯลฯ

  LessonLog({
    required this.id,
    required this.date,
    required this.slotId,
    required this.classGroupId,
    required this.topicId,
    required this.status,
    this.note = '',
    this.homework = '',
    List<Attachment>? attachments,
  }) : attachments = attachments ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'slot': slotId,
        'c': classGroupId,
        't': topicId,
        'st': status.name,
        'note': note,
        'hw': homework,
        if (attachments.isNotEmpty)
          'att': attachments.map((e) => e.toJson()).toList(),
      };
  factory LessonLog.fromJson(Map<String, dynamic> j) => LessonLog(
        id: j['id'],
        date: j['date'],
        slotId: j['slot'] ?? '',
        classGroupId: j['c'],
        topicId: j['t'],
        status: LogStatus.values.byName(j['st']),
        note: j['note'] ?? '',
        homework: j['hw'] ?? '',
        attachments: _atts(j['att']),
      );
}
