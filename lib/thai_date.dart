const thaiWeekdays = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
const thaiWeekdaysShort = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
const thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
];

/// "วันจันทร์ที่ 2 พ.ย. 2569"
String thaiFullDate(DateTime d) =>
    'วัน${thaiWeekdays[d.weekday - 1]}ที่ ${d.day} ${thaiMonthsShort[d.month - 1]} ${d.year + 543}';

/// "2 พ.ย." จาก yyyy-MM-dd
String thaiShortFromKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return '${p[2]} ${thaiMonthsShort[p[1] - 1]}';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
