import 'dart:math';
import '../models/domain.dart';

class ParsedScheduleItem {
  String semester;
  String subjectCode;
  String subjectName;
  String classCode;
  int dayOfWeek;
  int slot;
  String startTime;
  String endTime;
  String room;
  String sourceType;
  String? rawText;

  ParsedScheduleItem({
    this.semester = '',
    this.subjectCode = '',
    this.subjectName = '',
    this.classCode = '',
    this.dayOfWeek = 1,
    this.slot = 1,
    this.startTime = '07:30',
    this.endTime = '09:00',
    this.room = '',
    this.sourceType = 'IMAGE',
    this.rawText,
  });

  Schedule toSchedule({required String lecturerId, String? scheduleId}) {
    return Schedule(
      scheduleId: scheduleId ?? _generateUuid(),
      lecturerId: lecturerId,
      semester: semester.trim().toUpperCase(),
      subjectCode: subjectCode.trim().toUpperCase(),
      subjectName: subjectName.trim().isEmpty ? subjectCode.trim().toUpperCase() : subjectName.trim(),
      classCode: classCode.trim().toUpperCase(),
      dayOfWeek: dayOfWeek.clamp(1, 7),
      slot: slot.clamp(1, 12),
      startTime: startTime.trim(),
      endTime: endTime.trim(),
      room: room.trim().isEmpty ? 'TBA' : room.trim(),
      sourceType: sourceType,
    );
  }

  static String _generateUuid() {
    final random = Random();
    return 'sched_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(999999)}';
  }
}

class ScheduleParser {
  static const Map<int, (String, String)> fptSlotTimes = {
    1: ('07:30', '09:00'),
    2: ('09:15', '10:45'),
    3: ('11:00', '12:30'),
    4: ('12:45', '14:15'),
    5: ('14:30', '16:00'),
    6: ('16:15', '17:45'),
    7: ('18:00', '19:30'),
    8: ('19:45', '21:15'),
  };

  /// Fix typical OCR character misrecognitions in Class Codes:
  /// Examples: 'SE17O1' -> 'SE1701', 'SEl801' -> 'SE1801', 'SEI801' -> 'SE1801'
  static String fixClassCodeOcr(String raw) {
    final trimmed = raw.trim().toUpperCase();
    if (trimmed.isEmpty) return trimmed;

    final prefixMatch = RegExp(
      r'^(SE|AI|IA|IS|HE|SS|MC|GD|DS|IT|CS|BA|IB|MKT|FIN|HM|KS)([A-Z0-9]+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (prefixMatch != null) {
      final prefix = prefixMatch.group(1)!.toUpperCase();
      var digitsPart = prefixMatch.group(2)!;
      // In the alphanumeric part: replace 'O' (letter) with '0' (number), 'I' or 'L' with '1'
      digitsPart = digitsPart
          .replaceAll('O', '0')
          .replaceAll('I', '1')
          .replaceAll('L', '1')
          .replaceAll('|', '1');
      return '$prefix$digitsPart';
    }

    return trimmed;
  }

  /// Map FPT Block / Loc (A/P/B/C) to days of week.
  /// A: Mon (1) + Thu (4)
  /// P or B: Tue (2) + Fri (5)
  /// C: Wed (3) + Sat (6)
  static List<int> getDaysForBlock(String blockLetter) {
    switch (blockLetter.toUpperCase()) {
      case 'A':
        return [1, 4];
      case 'P':
      case 'B':
        return [2, 5];
      case 'C':
        return [3, 6];
      default:
        return [1];
    }
  }

  /// Parse Day of Week from human string (Vietnamese / English)
  static int? parseDayOfWeek(String text) {
    final lower = text.toLowerCase().trim();
    if (RegExp(r'(thứ\s*2|t2|mon|monday|^2$)').hasMatch(lower)) return 1;
    if (RegExp(r'(thứ\s*3|t3|tue|tuesday|^3$)').hasMatch(lower)) return 2;
    if (RegExp(r'(thứ\s*4|t4|wed|wednesday|^4$)').hasMatch(lower)) return 3;
    if (RegExp(r'(thứ\s*5|t5|thu|thursday|^5$)').hasMatch(lower)) return 4;
    if (RegExp(r'(thứ\s*6|t6|fri|friday|^6$)').hasMatch(lower)) return 5;
    if (RegExp(r'(thứ\s*7|t7|sat|saturday|^7$)').hasMatch(lower)) return 6;
    if (RegExp(r'(chủ\s*nhật|cn|sun|sunday|^8$)').hasMatch(lower)) return 7;
    return null;
  }

  /// Extract semester from text (e.g. FA24, SP25, SU24, Fall 2024...)
  static String? extractSemester(String text) {
    final match = RegExp(r'\b(SP|SU|FA)\s*(\d{2,4})\b', caseSensitive: false).firstMatch(text);
    if (match != null) {
      final term = match.group(1)!.toUpperCase();
      var year = match.group(2)!;
      if (year.length == 4) year = year.substring(2);
      return '$term$year';
    }
    return null;
  }

  /// Extract slot number (1-12)
  static int? extractSlot(String text) {
    final match = RegExp(r'(?:slot|tiết|ca)\s*(\d{1,2})', caseSensitive: false).firstMatch(text);
    if (match != null) {
      final val = int.tryParse(match.group(1)!);
      if (val != null && val >= 1 && val <= 12) return val;
    }
    return null;
  }

  /// Extract Room code (e.g. NVH 102, BE-301, DE-204, P301, AL-402...)
  static String? extractRoom(String text) {
    final match = RegExp(
      r'\b(NVH\s*[\w\d]+|[A-Z]{1,3}[-_]\d{2,4}|P\.?\s*\d{3}|Phòng\s*[\w\d]+)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return null;
  }

  /// Extract Subject Code (e.g. PRM393, SWE201c, LAB211, PRN231...)
  static String? extractSubjectCode(String text) {
    final match = RegExp(r'(?:^|[^A-Za-z0-9])([A-Za-z]{2,6}\d{3}[A-Za-z0-9]*)(?:$|[^A-Za-z0-9])')
        .firstMatch(text);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }
    return null;
  }

  /// Extract Class Code (e.g. SE1701, AI1802, IA1601...)
  static String? extractClassCode(String text) {
    final match = RegExp(
      r'\b((?:SE|AI|IA|IS|HE|SS|MC|GD|DS|IT|CS|BA|IB|MKT|FIN|HM|KS)[A-Z0-9]{3,})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return fixClassCodeOcr(match.group(1)!);
    }
    return null;
  }

  /// Main method: Parse raw text from OCR into a list of ParsedScheduleItems.
  /// Handles both line-by-line timetable rows and FPT A/P block formats.
  static List<ParsedScheduleItem> parseOcrText(String ocrText, {String defaultSemester = ''}) {
    final lines = ocrText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final results = <ParsedScheduleItem>[];

    var currentSemester = extractSemester(ocrText) ?? defaultSemester;
    if (currentSemester.isEmpty) {
      currentSemester = _currentDefaultSemester();
    }

    // Pass 1: Check for FPT block/pattern (e.g. "A1: PRM393 SE1701 NVH201")
    final blockRegex = RegExp(
      r'\b([APBC])\s*(\d{1,2})\b(?:\s*[:-]?\s*)?' // Group 1: Block, Group 2: Slot
      r'(?:.*?\b([A-Z]{2,6}\d{3}[A-Z0-9]*)\b)?' // Group 3: Subject
      r'(?:.*?\b((?:SE|AI|IA|IS|HE|SS|MC|GD|DS|IT|CS|BA|IB|MKT|FIN|HM|KS)[A-Z0-9]{3,})\b)?' // Group 4: Class
      r'(?:.*?\b(NVH\s*[\w\d]+|[A-Z]{1,3}[-_]\d{2,4}|P\.?\s*\d{3})\b)?', // Group 5: Room
      caseSensitive: false,
    );

    for (final line in lines) {
      final blockMatch = blockRegex.firstMatch(line);
      if (blockMatch != null) {
        final block = blockMatch.group(1)!.toUpperCase();
        final slotNum = int.tryParse(blockMatch.group(2) ?? '1') ?? 1;
        final subject = blockMatch.group(3)?.toUpperCase() ?? extractSubjectCode(line) ?? '';
        final classCode = blockMatch.group(4) != null
            ? fixClassCodeOcr(blockMatch.group(4)!)
            : (extractClassCode(line) ?? '');
        final room = blockMatch.group(5) ?? extractRoom(line) ?? 'TBA';

        if (subject.isNotEmpty || classCode.isNotEmpty) {
          final days = getDaysForBlock(block);
          final (startTime, endTime) = fptSlotTimes[slotNum] ?? ('07:30', '09:00');

          for (final day in days) {
            results.add(ParsedScheduleItem(
              semester: currentSemester,
              subjectCode: subject,
              classCode: classCode,
              dayOfWeek: day,
              slot: slotNum,
              startTime: startTime,
              endTime: endTime,
              room: room,
              sourceType: 'IMAGE',
              rawText: line,
            ));
          }
          continue;
        }
      }

      // Pass 2: Line contains explicit Day + Slot + Subject + Class
      final day = parseDayOfWeek(line);
      final slot = extractSlot(line);
      final subject = extractSubjectCode(line);
      final classCode = extractClassCode(line);
      final room = extractRoom(line) ?? 'TBA';

      if (subject != null || classCode != null) {
        final slotNum = slot ?? 1;
        final (startTime, endTime) = fptSlotTimes[slotNum] ?? ('07:30', '09:00');

        results.add(ParsedScheduleItem(
          semester: currentSemester,
          subjectCode: subject ?? '',
          classCode: classCode ?? '',
          dayOfWeek: day ?? 1,
          slot: slotNum,
          startTime: startTime,
          endTime: endTime,
          room: room,
          sourceType: 'IMAGE',
          rawText: line,
        ));
      }
    }

    return results;
  }

  static String _currentDefaultSemester() {
    final now = DateTime.now();
    final year = (now.year % 100).toString().padLeft(2, '0');
    final month = now.month;
    if (month >= 1 && month <= 4) return 'SP$year';
    if (month >= 5 && month <= 8) return 'SU$year';
    return 'FA$year';
  }
}
