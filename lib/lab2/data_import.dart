import 'dart:typed_data';
import 'package:excel/excel.dart' hide Data;
import 'domain.dart';

String importHeader(String value) {
  const accents = {
    'àáạảãâầấậẩẫăằắặẳẵ': 'a',
    'èéẹẻẽêềếệểễ': 'e',
    'ìíịỉĩ': 'i',
    'òóọỏõôồốộổỗơờớợởỡ': 'o',
    'ùúụủũưừứựửữ': 'u',
    'ỳýỵỷỹ': 'y',
    'đ': 'd',
  };
  var text = value.replaceAll('\uFEFF', '').trim().toLowerCase();
  for (final e in accents.entries) {
    for (final c in e.key.split('')) {
      text = text.replaceAll(c, e.value);
    }
  }
  return text.replaceAll(RegExp('[^a-z0-9]'), '');
}

List<List<String>> parseImportText(String text) {
  text = text.replaceAll('\uFEFF', '');
  final first = text.split(RegExp(r'[\r\n]')).first;
  final delimiter = first.contains('\t')
      ? '\t'
      : first.contains(';')
      ? ';'
      : ',';
  final rows = <List<String>>[], row = <String>[];
  var cell = StringBuffer(), quoted = false;
  void field() {
    row.add(cell.toString().trim());
    cell = StringBuffer();
  }

  void line() {
    field();
    if (row.any((v) => v.isNotEmpty)) rows.add(List.of(row));
    row.clear();
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && c == delimiter) {
      field();
    } else if (!quoted && (c == '\n' || c == '\r')) {
      line();
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
    } else {
      cell.write(c);
    }
  }
  if (quoted) throw const FormatException('Dấu ngoặc kép trong CSV chưa đóng.');
  if (cell.isNotEmpty || row.isNotEmpty) line();
  return rows;
}

Map<String, List<List<String>>> decodeImportWorkbook(
  Uint8List bytes, {
  bool roster = false,
}) {
  final book = Excel.decodeBytes(bytes);
  String value(CellValue? cell) => switch (cell) {
    null => '',
    TimeCellValue() =>
      '${cell.hour.toString().padLeft(2, '0')}:${cell.minute.toString().padLeft(2, '0')}',
    FormulaCellValue() =>
      roster
          ? ''
          : throw const FormatException(
              'File nhập không được chứa công thức. Hãy dán giá trị trước khi lưu.',
            ),
    _ => cell.toString(),
  };
  return {
    for (final sheet in book.tables.entries)
      sheet.key: sheet.value.rows
          .map((r) => r.map((c) => value(c?.value)).toList())
          .where((r) => r.any((v) => v.trim().isNotEmpty))
          .toList(),
  };
}

Map<String, List<List<String>>> decodeRosterWorkbook(Uint8List bytes) =>
    decodeImportWorkbook(bytes, roster: true);

ImportPreview reviewRosterAssignment(List<List<String>> table, Data cls) {
  final index = table.indexWhere(
    (row) => row
        .map(importHeader)
        .any(
          [
            'studentcode',
            'rollnumber',
            'rollno',
            'mssv',
            'masinhvien',
          ].contains,
        ),
  );
  if (index < 0) {
    return const ImportPreview([], [
      'Không tìm thấy hàng tiêu đề MSSV/RollNumber và Họ tên/FullName.',
    ]);
  }
  final headers = table[index].map(importHeader).toList();
  final ci = headers.indexWhere(
    ['class', 'classcode', 'lop', 'malop'].contains,
  );
  final si = headers.indexWhere(
    ['studentcode', 'rollnumber', 'rollno', 'mssv', 'masinhvien'].contains,
  );
  final ni = headers.indexWhere(
    ['fullname', 'studentname', 'name', 'hoten', 'tensinhvien'].contains,
  );
  final ei = headers.indexWhere(['schoolemail', 'email'].contains);
  if (ni < 0) return const ImportPreview([], ['Thiếu cột Họ tên/FullName.']);
  final selected = <List<String>>[
    ['studentCode', 'fullName', 'schoolEmail'],
  ];
  final seen = <String, List<String>>{};
  final errors = <String>[];
  for (var i = index + 1; i < table.length; i++) {
    String cell(int n) =>
        n < 0 || n >= table[i].length ? '' : table[i][n].trim();
    if (ci >= 0 &&
        cell(ci).toUpperCase() != '${cls['classCode']}'.trim().toUpperCase()) {
      continue;
    }
    final code = cell(si).toUpperCase();
    if (code.isEmpty && cell(ni).isEmpty || importHeader(code) == headers[si]) {
      continue;
    }
    final row = [code, cell(ni), cell(ei).toLowerCase()];
    final previous = seen[code];
    if (previous != null) {
      if (previous[1] != row[1] || previous[2] != row[2]) {
        errors.add('Dòng ${i + 1}: MSSV $code trùng nhưng khác thông tin.');
      }
      continue;
    }
    seen[code] = row;
    selected.add(row);
  }
  final result = reviewImport(selected, timetable: false, cls: cls);
  return ImportPreview(result.rows, [...errors, ...result.errors]);
}

String importTableText(List<List<String>> rows) => rows
    .map((r) => r.map((v) => '"${v.replaceAll('"', '""')}"').join(','))
    .join('\n');

class ImportPreview {
  final List<Data> rows;
  final List<String> errors;
  const ImportPreview(this.rows, this.errors);
}

ImportPreview reviewImport(
  List<List<String>> table, {
  required bool timetable,
  Data cls = const {},
}) {
  if (table.isEmpty) return const ImportPreview([], ['Chưa có dữ liệu.']);
  const aliases = {
    'semester': ['semester', 'term', 'hocky'],
    'subjectCode': ['subjectcode', 'subjectid', 'coursecode', 'mamon', 'mon'],
    'subjectName': ['subjectname', 'coursename', 'tenmon'],
    'classCode': ['classcode', 'class', 'lop', 'malop'],
    'dayOfWeek': ['dayofweek', 'day', 'thu'],
    'slot': ['slot', 'ca', 'tiet'],
    'startTime': ['starttime', 'start', 'giobatdau'],
    'endTime': ['endtime', 'end', 'gioketthuc'],
    'room': ['room', 'phong', 'phonghoc'],
    'studentCode': [
      'studentcode',
      'rollnumber',
      'rollno',
      'mssv',
      'masinhvien',
    ],
    'fullName': ['fullname', 'studentname', 'name', 'hoten', 'tensinhvien'],
    'schoolEmail': ['schoolemail', 'email'],
  };
  final headers = table.first.map(importHeader).toList();
  final indexes = <String, int>{};
  for (final e in aliases.entries) {
    final index = headers.indexWhere(e.value.contains);
    if (index >= 0) indexes[e.key] = index;
  }
  final hasHeader = timetable
      ? indexes.containsKey('subjectCode')
      : indexes.containsKey('studentCode');
  if (timetable && !hasHeader) {
    return const ImportPreview([], [
      'Cần hàng tiêu đề: semester,subjectCode,subjectName,classCode,dayOfWeek,slot,startTime,endTime,room',
    ]);
  }
  if (!hasHeader) {
    indexes.addAll({'studentCode': 0, 'fullName': 1, 'schoolEmail': 2});
  }
  final rows = <Data>[], errors = <String>[], seen = <String>{};
  final dataRows = table.skip(hasHeader ? 1 : 0).toList();
  if (dataRows.length > (timetable ? 100 : 400)) {
    return ImportPreview([], ['Tối đa ${timetable ? 100 : 400} dòng mỗi lần.']);
  }
  for (var i = 0; i < dataRows.length; i++) {
    final row = dataRows[i];
    String field(String name) {
      final j = indexes[name];
      return j == null || j >= row.length ? '' : row[j].trim();
    }

    final d = <String, dynamic>{};
    if (timetable) {
      for (final key in [
        'semester',
        'subjectCode',
        'subjectName',
        'classCode',
        'dayOfWeek',
        'slot',
        'startTime',
        'endTime',
        'room',
      ]) {
        d[key] = field(key);
      }
      for (final key in ['semester', 'subjectCode', 'classCode']) {
        d[key] = (d[key] as String).toUpperCase();
      }
      final rawDay = '${d['dayOfWeek']}';
      final vn = RegExp(
        r'^(?:Thứ|Thu|T)\s*([2-7])$',
        caseSensitive: false,
      ).firstMatch(rawDay);
      d['dayOfWeek'] = vn != null
          ? int.parse(vn[1]!) - 1
          : importHeader(rawDay) == 'cn' || importHeader(rawDay) == 'chunhat'
          ? 7
          : int.tryParse(rawDay);
      d['slot'] = int.tryParse('${d['slot']}');
      for (final key in ['startTime', 'endTime']) {
        final match = RegExp(
          r'^(\d{1,2}):(\d{2})(?::\d{2})?$',
        ).firstMatch('${d[key]}');
        if (match != null) d[key] = '${match[1]!.padLeft(2, '0')}:${match[2]}';
      }
      final time = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
      if ([
            'semester',
            'subjectCode',
            'classCode',
          ].any((k) => '${d[k]}'.isEmpty || '${d[k]}'.length > 100) ||
          d['dayOfWeek'] == null ||
          d['dayOfWeek'] < 1 ||
          d['dayOfWeek'] > 7 ||
          d['slot'] == null ||
          d['slot'] < 1 ||
          d['slot'] > 12 ||
          !time.hasMatch(d['startTime']) ||
          !time.hasMatch(d['endTime']) ||
          d['startTime'] == d['endTime']) {
        errors.add(
          'Dòng ${i + (hasHeader ? 2 : 1)}: kiểm tra học kỳ, môn, lớp, thứ (1–7), slot và giờ HH:mm.',
        );
        continue;
      }
    } else {
      d.addAll({
        'studentCode': field('studentCode').toUpperCase(),
        'fullName': field('fullName'),
        'schoolEmail': field('schoolEmail').toLowerCase(),
        'classCode': '${cls['classCode'] ?? field('classCode')}'.toUpperCase(),
      });
      if (field('classCode').isNotEmpty &&
          field('classCode').toUpperCase() != d['classCode']) {
        errors.add(
          'Dòng ${i + (hasHeader ? 2 : 1)}: mã lớp không khớp lớp đang nhập.',
        );
        continue;
      }
      if (!RegExp(r'^[A-Z0-9][A-Z0-9._-]{1,39}$').hasMatch(d['studentCode']) ||
          (d['fullName'] as String).isEmpty ||
          (d['fullName'] as String).length > 200 ||
          ((d['schoolEmail'] as String).isNotEmpty &&
              !RegExp(
                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
              ).hasMatch(d['schoolEmail']))) {
        errors.add(
          'Dòng ${i + (hasHeader ? 2 : 1)}: kiểm tra MSSV, họ tên và email.',
        );
        continue;
      }
    }
    final key = timetable
        ? '${d['semester']}_${d['subjectCode']}_${d['classCode']}_${d['dayOfWeek']}_${d['slot']}'
        : d['studentCode'] as String;
    if (!seen.add(key)) {
      errors.add(
        'Dòng ${i + (hasHeader ? 2 : 1)}: trùng ${timetable ? 'buổi học' : 'MSSV'} trong file.',
      );
      continue;
    }
    rows.add(d);
  }
  return ImportPreview(rows, errors);
}
