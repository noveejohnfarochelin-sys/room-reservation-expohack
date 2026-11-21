import 'dart:typed_data';

import 'package:room_reservation_expohack/models/class_schedule_model.dart';
import 'package:room_reservation_expohack/models/room_model.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ScheduleParseResult {
  final String? collegeCode;
  final List<ClassScheduleModel> entries;
  final List<String> skipped;
  final String? error;
  const ScheduleParseResult({
    this.collegeCode,
    this.entries = const <ClassScheduleModel>[],
    this.skipped = const <String>[],
    this.error,
  });

  Map<String, int> get perRoom {
    final out = <String, int>{};
    for (final e in entries) {
      out[e.roomName] = (out[e.roomName] ?? 0) + 1;
    }
    return out;
  }
}

class _Pat {
  final RoomModel room;
  final RegExp re;
  const _Pat(this.room, this.re);
}

class _Hit {
  final RoomModel room;
  final int start;
  final int end;
  const _Hit(this.room, this.start, this.end);
}

class _Time {
  final int s;
  final int e;
  final int start;
  final int end;
  const _Time(this.s, this.e, this.start, this.end);
}

class _Row {
  RoomModel? room;
  bool unknownRoom = false;
  List<int> days = <int>[];
  _Time? time;
  String desc = '';
  String instructor = '';
}

/// Extracts text from a schedule PDF and turns it into [ClassScheduleModel] blocks.
///
/// Accepted line shapes (one class per line, pipes optional):
///   Room 101 | Monday | 08:00 AM - 10:00 AM | CS 101 - Intro to Computing (BSCS 1A) | Prof. M. Santos
///   Computer Lab 1 M, W, F 8:00-10:00 CS 101 (BSCS 1A) Prof. M. Santos
/// A line holding only a room name sets the room for the following lines.
/// Room names are matched ignoring case, spaces and punctuation ("Room101" == "Room 101").
class SchedulePdfParser {
  SchedulePdfParser._();

  static const List<String> buildingCodes = ['CEA', 'CCI', 'COE', 'CIT', 'CGBE', 'LIB'];

  /// Lines of the downloadable sample PDF (first 3 are header lines).
  static const List<String> sampleCciLines = [
    'ILOILO SCIENCE AND TECHNOLOGY UNIVERSITY',
    'COLLEGE OF COMPUTING AND INFORMATICS (CCI)',
    'OFFICIAL CLASSROOM & LABORATORY SCHEDULE - 1ST SEMESTER',
    '',
    'Room 101 | Monday | 08:00 AM - 10:00 AM | CS 101 - Introduction to Computing (BSCS 1A) | Prof. M. Santos',
    'Room 101 | Monday | 10:00 AM - 12:00 PM | IT 102 - Discrete Structures (BSIT 1B) | Prof. R. Villanueva',
    'Room 101 | Wednesday | 08:00 AM - 10:00 AM | CS 101 - Introduction to Computing (BSCS 1A) | Prof. M. Santos',
    'Room 101 | Friday | 01:00 PM - 03:00 PM | IS 201 - Fundamentals of Information Systems (BSIS 2A) | Prof. L. Gomez',
    '',
    'Room 102 | Tuesday | 09:00 AM - 11:00 AM | CS 204 - Algorithms and Complexity (BSCS 2A) | Dr. A. Reyes',
    'Room 102 | Thursday | 09:00 AM - 11:00 AM | CS 204 - Algorithms and Complexity (BSCS 2A) | Dr. A. Reyes',
    'Room 102 | Saturday | 08:00 AM - 11:00 AM | CS 401 - Thesis Writing & Research Methods (BSCS 4A) | Dr. A. Reyes',
    '',
    'Computer Lab 1 | Monday | 08:00 AM - 11:00 AM | ICT 109 - Database Management Systems (BSCS 2B) | Prof. J. Dela Cruz',
    'Computer Lab 1 | Tuesday | 01:00 PM - 04:00 PM | IT 205 - Web Systems and Technologies (BSIT 2A) | Prof. K. Navarro',
    'Computer Lab 1 | Thursday | 01:00 PM - 04:00 PM | IT 205 - Web Systems and Technologies (BSIT 2A) | Prof. K. Navarro',
    '',
    'Computer Lab 2 | Monday | 01:00 PM - 04:00 PM | CS 305 - Mobile Application Development (BSCS 3A) | Prof. N. Bautista',
    'Computer Lab 2 | Wednesday | 01:00 PM - 04:00 PM | CS 305 - Mobile Application Development (BSCS 3A) | Prof. N. Bautista',
    'Computer Lab 2 | Friday | 08:00 AM - 11:00 AM | IT 302 - Human Computer Interaction (BSIT 3B) | Prof. E. Soriano',
    '',
    'Networking Lab | Tuesday | 08:00 AM - 11:00 AM | IT 202 - Networking 1 (BSIT 2B) | Engr. P. Mendoza',
    'Networking Lab | Thursday | 08:00 AM - 11:00 AM | IT 202 - Networking 1 (BSIT 2B) | Engr. P. Mendoza',
    'Networking Lab | Friday | 01:00 PM - 04:00 PM | IT 308 - Information Assurance and Security (BSIT 3A) | Engr. P. Mendoza',
    '',
    'Programming Lab | Monday | 10:00 AM - 01:00 PM | CS 102 - Object-Oriented Programming (BSCS 1B) | Prof. C. Lim',
    'Programming Lab | Wednesday | 10:00 AM - 01:00 PM | CS 102 - Object-Oriented Programming (BSCS 1B) | Prof. C. Lim',
    'Programming Lab | Saturday | 01:00 PM - 04:00 PM | CS 310 - Data Science and Pipelines (BSCS 3B) | Prof. C. Lim',
    '',
    'Multimedia Lab | Tuesday | 01:00 PM - 04:00 PM | EMC 201 - Digital Illustration & UI Prototyping (BSEMC 2A) | Prof. D. Torres',
    'Multimedia Lab | Thursday | 01:00 PM - 04:00 PM | EMC 201 - Digital Illustration & UI Prototyping (BSEMC 2A) | Prof. D. Torres',
    '',
    'Seminar Room | Wednesday | 02:00 PM - 05:00 PM | CS 402 - Software Engineering Colloquium (BSCS 4A) | CCI Faculty',
    'Conference Room | Friday | 03:00 PM - 05:00 PM | CCI Department Curriculum & Accreditation Meeting | Office of the Dean',
    'AVR / Function Hall | Saturday | 08:00 AM - 12:00 PM | ISATech Society & CCI General Assembly | Student Affairs',
  ];

  static const Map<String, int> _dayMap = {
    'monday': 1, 'mon': 1,
    'tuesday': 2, 'tues': 2, 'tue': 2,
    'wednesday': 3, 'wed': 3,
    'thursday': 4, 'thurs': 4, 'thur': 4, 'thu': 4,
    'friday': 5, 'fri': 5,
    'saturday': 6, 'sat': 6,
    'sunday': 7, 'sun': 7,
  };

  static final RegExp _dayRe = RegExp(
      r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|thurs|thur|tues|mon|tue|wed|thu|fri|sat|sun)\b',
      caseSensitive: false);
  static final RegExp _compactCell =
      RegExp(r'^(?:th|sa|su|[mtwfs])(?:\s*[,/&]?\s*(?:th|sa|su|[mtwfs]))*$', caseSensitive: false);
  static final RegExp _compactInline = RegExp(
      r'(?<![A-Za-z.])((?:th|sa|su|[mtwfs])(?:\s*[,/&]?\s*(?:th|sa|su|[mtwfs]))*)(?![A-Za-z.])(?=\s*\d)',
      caseSensitive: false);
  static final RegExp _timeRe = RegExp(
      r'(?<![\d:.])(\d{1,2})(?:[:.](\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?\s*(?:-|–|—|to)\s*(\d{1,2})(?:[:.](\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?(?!\d)',
      caseSensitive: false);
  static final RegExp _instructorRe = RegExp(
      r'(?<![A-Za-z])(?:Prof\.|Dr\.|Engr\.|Mr\.|Ms\.|Mrs\.|Atty\.)\s*.*$',
      caseSensitive: false);

  /// Reads all text from a PDF with Syncfusion.
  static String extractText(Uint8List bytes) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(doc).extractText();
    } finally {
      doc.dispose();
    }
  }

  /// Normalises characters PDF extractors like to swap in (odd dashes, pipes, invisible spaces).
  static String _clean(String s) {
    return s
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'[\u00A0\u2007\u202F]'), ' ')
        .replaceAll(RegExp(r'[\u00AD\u2010-\u2015\u2212]'), '-')
        .replaceAll(RegExp(r'[\u00A6\u2502\u2503\uFF5C\u2223]'), '|');
  }

  static ScheduleParseResult parse(String text, List<RoomModel> rooms, {String? collegeOverride}) {
    final lines = _clean(text)
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const ScheduleParseResult(error: 'The PDF has no readable text (is it a scanned image?).');
    }

    final code = collegeOverride ?? _detectCollege(lines);
    if (code == null) {
      return const ScheduleParseResult(
          error: 'Could not detect the building in the PDF. Choose it in the Building dropdown and try again.');
    }
    final cands = rooms.where((r) => !r.isStandalone && r.code == code).toList();
    if (cands.isEmpty) {
      return ScheduleParseResult(collegeCode: code, error: 'No rooms for $code were found in Firestore.');
    }
    final pats = <_Pat>[for (final r in cands) _Pat(r, _roomPattern(r.name))];

    final entries = <ClassScheduleModel>[];
    final seen = <String>{};
    final skipped = <String>[];
    RoomModel? current;

    for (final line in lines) {
      var row = _parseLine(line, pats);
      if (line.contains('|') && (row.time == null || row.days.isEmpty || row.unknownRoom)) {
        // Second chance: treat the pipes as plain spaces.
        final alt = _parseFlat(line.replaceAll('|', ' '), pats);
        if (alt.time != null && alt.days.isNotEmpty && alt.room != null) row = alt;
      }

      if (row.time == null) {
        if (row.room != null) current = row.room;
        continue;
      }
      if (row.unknownRoom) {
        skipped.add(line);
        continue;
      }
      final room = row.room ?? current;
      if (room == null || row.days.isEmpty) {
        skipped.add(line);
        continue;
      }
      if (row.room != null) current = row.room;

      var desc = row.desc;
      var section = '';
      final sm = RegExp(r'\(([^()]*)\)\s*$').firstMatch(desc);
      if (sm != null) {
        section = sm.group(1)!.trim();
        desc = desc.substring(0, sm.start).trim();
      }
      var course = desc;
      final cm = RegExp(r'^([A-Za-z]{2,6})\s*(\d{2,4}[A-Za-z]?)(?:\s*[-–—:]\s*|\s+|$)').firstMatch(desc);
      if (cm != null) course = '${cm.group(1)!.toUpperCase()} ${cm.group(2)!.toUpperCase()}';
      if (course.isEmpty) course = 'Class';

      for (final day in row.days) {
        final entry = ClassScheduleModel(
          id: '',
          collegeCode: code,
          roomId: room.id,
          roomName: room.name,
          dayOfWeek: day,
          startMin: row.time!.s,
          endMin: row.time!.e,
          courseCode: course,
          section: section,
          instructor: row.instructor,
        );
        if (seen.add(entry.key)) entries.add(entry);
      }
    }

    if (entries.isEmpty) {
      return ScheduleParseResult(
        collegeCode: code,
        skipped: skipped,
        error: 'No class blocks were recognised. Check that each line has a room, a weekday and a time range.'
            '${_diagnostic(lines, cands, skipped.length)}',
      );
    }
    return ScheduleParseResult(collegeCode: code, entries: entries, skipped: skipped);
  }

  /* ───────────── internals ───────────── */

  static String _clip(String s, [int n = 90]) => s.length <= n ? s : '${s.substring(0, n)}…';

  /// Shown when nothing was recognised, so the real cause is visible.
  static String _diagnostic(List<String> lines, List<RoomModel> cands, int skipped) {
    final data = lines.where((l) => RegExp(r'\d').hasMatch(l) && l.length > 25).take(2).toList();
    final shown = data.isNotEmpty ? data : lines.take(3).toList();
    final b = StringBuffer();
    b.write('\n\nRooms in Firestore for this building: ${cands.map((r) => r.name).join(', ')}.');
    b.write('\nText read from the PDF (${lines.length} lines, $skipped skipped):');
    for (final l in shown) {
      b.write('\n• ${_clip(l)}');
    }
    return b.toString();
  }

  static String? _detectCollege(List<String> lines) {
    final head = lines.take(25).toList();
    final paren = RegExp(r'\((CEA|CCI|COE|CIT|CGBE|LIB)\)');
    final bare = RegExp(r'\b(CEA|CCI|COE|CIT|CGBE|LIB)\b');
    for (final l in head) {
      final m = paren.firstMatch(l);
      if (m != null) return m.group(1);
    }
    for (final l in head) {
      final m = bare.firstMatch(l);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// Matches a room name ignoring case, spaces and punctuation between its characters.
  static RegExp _roomPattern(String name) {
    final chars = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').split('');
    if (chars.isEmpty || chars.first.isEmpty) return RegExp(r'(?!)');
    final body = chars.map(RegExp.escape).join(r'[^A-Za-z0-9]*');
    return RegExp('(?<![A-Za-z0-9])$body(?![A-Za-z0-9])', caseSensitive: false);
  }

  static _Hit? _matchRoom(String text, List<_Pat> pats) {
    _Hit? best;
    for (final p in pats) {
      final m = p.re.firstMatch(text);
      if (m == null) continue;
      if (best == null ||
          m.start < best.start ||
          (m.start == best.start && (m.end - m.start) > (best.end - best.start))) {
        best = _Hit(p.room, m.start, m.end);
      }
    }
    return best;
  }

  static List<int> _fullDays(String s) {
    final out = <int>{for (final m in _dayRe.allMatches(s)) _dayMap[m.group(1)!.toLowerCase()]!};
    return out.toList()..sort();
  }

  static List<int> _compactDays(String s) {
    final t = s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final out = <int>{};
    var i = 0;
    while (i < t.length) {
      if (t.startsWith('th', i)) {
        out.add(4);
        i += 2;
      } else if (t.startsWith('sa', i)) {
        out.add(6);
        i += 2;
      } else if (t.startsWith('su', i)) {
        out.add(7);
        i += 2;
      } else {
        switch (t[i]) {
          case 'm':
            out.add(1);
          case 't':
            out.add(2);
          case 'w':
            out.add(3);
          case 'f':
            out.add(5);
          case 's':
            out.add(6);
        }
        i++;
      }
    }
    return out.toList()..sort();
  }

  static List<int> _daysOfCell(String cell) {
    final full = _fullDays(cell);
    if (full.isNotEmpty) return full;
    if (_compactCell.hasMatch(cell.trim())) return _compactDays(cell);
    return <int>[];
  }

  static String? _mer(String? s) => (s == null || s.isEmpty) ? null : s.toLowerCase()[0];

  static int _h24(int h, String? mer) {
    if (mer == 'a') return h % 12;
    if (mer == 'p') return h % 12 + 12;
    return h;
  }

  static int _guess(int h) => (h >= 1 && h <= 6) ? h + 12 : h;

  static List<int>? _resolve(int h1, int m1, String? a, int h2, int m2, String? b) {
    if (h1 > 24 || h2 > 24 || m1 > 59 || m2 > 59) return null;
    int s;
    int e;
    if (a == null && b == null) {
      s = _guess(h1) * 60 + m1;
      e = _guess(h2) * 60 + m2;
      if (e <= s && e < 12 * 60) e += 12 * 60;
    } else {
      final ma = a ?? b;
      final mb = b ?? a;
      s = _h24(h1, ma) * 60 + m1;
      e = _h24(h2, mb) * 60 + m2;
      if (a == null && s >= e) {
        s = _h24(h1, ma == 'p' ? 'a' : 'p') * 60 + m1;
      }
    }
    if (s < 0 || e > 1440 || s >= e) return null;
    return <int>[s, e];
  }

  static _Time? _findTime(String text) {
    for (final m in _timeRe.allMatches(text)) {
      final r = _resolve(
        int.parse(m.group(1)!),
        int.tryParse(m.group(2) ?? '0') ?? 0,
        _mer(m.group(3)),
        int.parse(m.group(4)!),
        int.tryParse(m.group(5) ?? '0') ?? 0,
        _mer(m.group(6)),
      );
      if (r != null) return _Time(r[0], r[1], m.start, m.end);
    }
    return null;
  }

  static _Row _parseLine(String line, List<_Pat> pats) =>
      line.contains('|') ? _parsePiped(line, pats) : _parseFlat(line, pats);

  static _Row _parsePiped(String line, List<_Pat> pats) {
    final row = _Row();
    final cells = line.split('|').map((c) => c.trim()).toList();
    var roomIdx = -1;
    for (var i = 0; i < cells.length && i < 2; i++) {
      final h = _matchRoom(cells[i], pats);
      if (h != null) {
        row.room = h.room;
        roomIdx = i;
        break;
      }
    }
    var timeIdx = -1;
    for (var i = 0; i < cells.length; i++) {
      if (i == roomIdx) continue;
      final t = _findTime(cells[i]);
      if (t != null) {
        row.time = t;
        timeIdx = i;
        break;
      }
    }
    if (row.time == null) return row;

    var dayIdx = -1;
    for (var i = 0; i < cells.length; i++) {
      if (i == roomIdx || i == timeIdx) continue;
      final d = _daysOfCell(cells[i]);
      if (d.isNotEmpty) {
        row.days = d;
        dayIdx = i;
        break;
      }
    }
    if (row.days.isEmpty) row.days = _fullDays(cells[timeIdx]);

    if (row.room == null && cells.isNotEmpty && cells[0].isNotEmpty && dayIdx != 0 && timeIdx != 0) {
      row.unknownRoom = true;
    }
    final rest = <String>[
      for (var i = 0; i < cells.length; i++)
        if (i != roomIdx && i != timeIdx && i != dayIdx && cells[i].isNotEmpty) cells[i]
    ];
    row.desc = rest.isNotEmpty ? rest[0] : '';
    row.instructor = rest.length > 1 ? rest[1] : '';
    return row;
  }

  static _Row _parseFlat(String line, List<_Pat> pats) {
    final row = _Row();
    var w = line;
    final hit = _matchRoom(w, pats);
    if (hit != null) {
      row.room = hit.room;
      w = w.replaceRange(hit.start, hit.end, ' ');
    }
    final full = _fullDays(w);
    if (full.isNotEmpty) {
      row.days = full;
      w = w.replaceAll(_dayRe, ' ');
    } else {
      final cm = _compactInline.firstMatch(w);
      if (cm != null) {
        row.days = _compactDays(cm.group(1)!);
        w = w.replaceRange(cm.start, cm.end, ' ');
      }
    }
    final t = _findTime(w);
    if (t == null) return row;
    row.time = t;
    w = w.replaceRange(t.start, t.end, ' ');
    final im = _instructorRe.firstMatch(w);
    if (im != null) {
      row.instructor = im.group(0)!.trim();
      w = w.substring(0, im.start);
    }
    row.desc = w.replaceAll(RegExp(r'^[\s\-–—:,;]+|[\s\-–—:,;]+$'), '').trim();
    return row;
  }
}