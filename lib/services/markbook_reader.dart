import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import '../models/domain.dart';

class MarkbookParseResult {
  final String sheetName;
  final String suggestedSubjectCode;
  final String? detectedClassCode;
  final List<RosterStudent> students;
  final List<String> warnings;

  MarkbookParseResult({
    required this.sheetName,
    required this.suggestedSubjectCode,
    this.detectedClassCode,
    required this.students,
    this.warnings = const [],
  });
}

class MarkbookReader {
  /// Entry point to parse spreadsheet bytes in a background isolate
  static Future<MarkbookParseResult> parseBytesInBackground({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return compute(_parseIsolateEntry, {
      'bytes': bytes,
      'fileName': fileName,
    });
  }

  static MarkbookParseResult _parseIsolateEntry(Map<String, dynamic> params) {
    final bytes = params['bytes'] as Uint8List;
    final fileName = params['fileName'] as String;
    return parseBytes(bytes: bytes, fileName: fileName);
  }

  /// Synchronous parse method (used in Isolate or directly in tests)
  static MarkbookParseResult parseBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx')) {
      return _parseXlsx(bytes);
    } else if (lower.endsWith('.ods')) {
      return _parseOds(bytes);
    } else if (lower.endsWith('.csv')) {
      return _parseCsv(bytes, fileName);
    } else {
      throw const FormatException('Định dạng file không được hỗ trợ. Chỉ hỗ trợ .xlsx, .ods, .csv');
    }
  }

  /// Extract suggested subject code from sheet name or file name (e.g. 23_PRM393 -> PRM393)
  static String extractSubjectCode(String text) {
    final match = RegExp(r'(?:^|[^A-Za-z0-9])([A-Za-z]{2,6}\d{3}[A-Za-z0-9]*)(?:$|[^A-Za-z0-9])')
        .firstMatch(text);
    return match?.group(1)?.toUpperCase() ?? '';
  }

  static MarkbookParseResult _parseCsv(Uint8List bytes, String fileName) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final rows = csv
        .decode(content)
        .map((r) => r.map((c) => '$c'.trim()).toList())
        .toList();

    final sheetName = fileName.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.[^.]+$'), '');
    return _processExtractedTable(
      sheetName: sheetName,
      rows: rows,
    );
  }

  static MarkbookParseResult _parseXlsx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Shared Strings
    final sharedStrings = <String>[];
    final ssFile = archive.findFile('xl/sharedStrings.xml');
    if (ssFile != null) {
      final doc = XmlDocument.parse(utf8.decode(ssFile.content as List<int>));
      for (final si in doc.findAllElements('si')) {
        final buffer = StringBuffer();
        for (final t in si.findAllElements('t')) {
          buffer.write(t.innerText);
        }
        sharedStrings.add(buffer.toString());
      }
    }

    // 2. Workbook to get first sheet name
    var sheetName = 'Sheet1';
    var sheetFileName = 'xl/worksheets/sheet1.xml';
    final wbFile = archive.findFile('xl/workbook.xml');
    if (wbFile != null) {
      final wbDoc = XmlDocument.parse(utf8.decode(wbFile.content as List<int>));
      final firstSheet = wbDoc.findAllElements('sheet').firstOrNull;
      if (firstSheet != null) {
        sheetName = firstSheet.getAttribute('name') ?? 'Sheet1';
      }
    }

    // 3. Worksheet
    var wsFile = archive.findFile(sheetFileName);
    if (wsFile == null) {
      // Find any sheet file
      final candidate = archive.files.firstWhere(
        (f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'),
        orElse: () => throw const FormatException('Không tìm thấy dữ liệu bảng tính trong file .xlsx'),
      );
      wsFile = candidate;
    }

    final wsDoc = XmlDocument.parse(utf8.decode(wsFile.content as List<int>));
    final rows = <List<String>>[];

    for (final rowElem in wsDoc.findAllElements('row')) {
      final rowData = <String>[];
      for (final cElem in rowElem.findAllElements('c')) {
        final type = cElem.getAttribute('t');
        final vElem = cElem.findElements('v').firstOrNull;
        var cellVal = '';

        if (type == 's' && vElem != null) {
          final idx = int.tryParse(vElem.innerText);
          if (idx != null && idx >= 0 && idx < sharedStrings.length) {
            cellVal = sharedStrings[idx];
          }
        } else if (type == 'inlineStr') {
          final tElem = cElem.findAllElements('t').firstOrNull;
          cellVal = tElem?.innerText ?? '';
        } else if (vElem != null) {
          cellVal = vElem.innerText;
        }

        rowData.add(cellVal.trim());
      }
      if (rowData.any((cell) => cell.isNotEmpty)) {
        rows.add(rowData);
      }
    }

    return _processExtractedTable(sheetName: sheetName, rows: rows);
  }

  static MarkbookParseResult _parseOds(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final contentFile = archive.findFile('content.xml');
    if (contentFile == null) {
      throw const FormatException('Không tìm thấy content.xml trong file .ods');
    }

    final doc = XmlDocument.parse(utf8.decode(contentFile.content as List<int>));
    final table = doc.findAllElements('table:table').firstOrNull ??
        doc.findAllElements('table').firstOrNull;

    final sheetName = table?.getAttribute('table:name') ?? 'Sheet1';
    final rows = <List<String>>[];

    final rowElems = doc.findAllElements('table:table-row');
    for (final rowElem in rowElems) {
      final rowData = <String>[];
      for (final cellElem in rowElem.findAllElements('table:table-cell')) {
        final textP = cellElem.findAllElements('text:p').map((e) => e.innerText).join(' ').trim();
        rowData.add(textP);
      }
      if (rowData.any((c) => c.isNotEmpty)) {
        rows.add(rowData);
      }
    }

    return _processExtractedTable(sheetName: sheetName, rows: rows);
  }

  /// Process row matrix, find headers, validate columns and deduplicate students
  static MarkbookParseResult _processExtractedTable({
    required String sheetName,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) {
      throw const FormatException('File bảng tính không có dữ liệu.');
    }

    // Find header row: contains Class/Lớp, RollNumber/MSSV, FullName/Họ tên
    int headerIndex = -1;
    int classCol = -1;
    int rollCol = -1;
    int nameCol = -1;
    int emailCol = -1;

    for (var i = 0; i < rows.length && i < 15; i++) {
      final row = rows[i].map((s) => s.toLowerCase().trim()).toList();

      var foundClass = -1;
      var foundRoll = -1;
      var foundName = -1;
      var foundEmail = -1;

      for (var col = 0; col < row.length; col++) {
        final header = row[col];
        if (RegExp(r'^(class|lớp|mã\s*lớp|class\s*code)$').hasMatch(header)) {
          foundClass = col;
        } else if (RegExp(r'^(rollnumber|mssv|mã\s*sv|student\s*code|mã\s*sinh\s*viên|roll\s*no|roll\s*number)$').hasMatch(header)) {
          foundRoll = col;
        } else if (RegExp(r'^(fullname|họ\s*và\s*tên|họ\s*tên|tên\s*sinh\s*viên|student\s*name|họ\s*tên\s*sinh\s*viên)$').hasMatch(header)) {
          foundName = col;
        } else if (RegExp(r'^(email|school\s*email|hòm\s*thư)$').hasMatch(header)) {
          foundEmail = col;
        }
      }

      if (foundRoll != -1 && foundName != -1) {
        headerIndex = i;
        classCol = foundClass;
        rollCol = foundRoll;
        nameCol = foundName;
        emailCol = foundEmail;
        break;
      }
    }

    if (headerIndex == -1 || rollCol == -1 || nameCol == -1) {
      throw const FormatException(
        'Không tìm thấy các cột tiêu đề bắt buộc (Cần có cột MSSV / RollNumber và Họ tên / FullName).',
      );
    }

    final warnings = <String>[];
    final students = <RosterStudent>[];
    final seen = <String, String>{}; // studentCode -> fullName
    final codes = <String>{};
    String? commonClassCode;

    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (rollCol >= row.length || nameCol >= row.length) continue;

      final rollNumber = row[rollCol].trim().toUpperCase();
      final fullName = row[nameCol].trim();
      var classCode = classCol != -1 && classCol < row.length ? row[classCol].trim().toUpperCase() : '';
      final email = emailCol != -1 && emailCol < row.length ? row[emailCol].trim().toLowerCase() : '';

      if (rollNumber.isEmpty || fullName.isEmpty) continue;

      // Skip header repetitions if any
      if (rollNumber == 'ROLLNUMBER' || rollNumber == 'MSSV') continue;

      // Basic regex check for RollNumber (e.g. SE170123, HE160456, QE150789...)
      if (!RegExp(r'^[A-Z0-9][A-Z0-9._-]{1,39}$').hasMatch(rollNumber)) {
        warnings.add('Dòng ${i + 1}: MSSV "$rollNumber" có ký tự không chuẩn.');
      }

      // Check conflict: Same RollNumber but different FullName
      if (seen.containsKey(rollNumber)) {
        final existingName = seen[rollNumber]!;
        if (existingName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ') !=
            fullName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')) {
          throw FormatException(
            'Phát hiện trùng MSSV "$rollNumber" nhưng khác họ tên: "$existingName" và "$fullName"!',
          );
        }
        // Duplicate row with identical name -> skip to deduplicate
        continue;
      }

      seen[rollNumber] = fullName;
      codes.add(rollNumber);

      if (classCode.isNotEmpty && commonClassCode == null) {
        commonClassCode = classCode;
      }

      students.add(RosterStudent(
        classCode: classCode,
        studentCode: rollNumber,
        fullName: fullName,
        schoolEmail: email,
      ));
    }

    if (students.isEmpty) {
      throw const FormatException('Không tìm thấy sinh viên nào trong danh sách dữ liệu.');
    }

    final suggestedSubject = extractSubjectCode(sheetName);

    return MarkbookParseResult(
      sheetName: sheetName,
      suggestedSubjectCode: suggestedSubject,
      detectedClassCode: commonClassCode,
      students: students,
      warnings: warnings,
    );
  }
}
