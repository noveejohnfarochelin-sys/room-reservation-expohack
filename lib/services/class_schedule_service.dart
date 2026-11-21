import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:room_reservation_expohack/models/class_schedule_model.dart';

/// Firestore access for the recurring `class_schedules` collection.
class ClassScheduleService {
  ClassScheduleService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col => _db.collection('class_schedules');

  static List<ClassScheduleModel> _map(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => ClassScheduleModel.fromMap(d.data(), d.id)).toList();

  static Future<List<ClassScheduleModel>> all() async {
    final list = _map(await _col.get());
    list.sort((a, b) {
      var c = a.collegeCode.compareTo(b.collegeCode);
      if (c != 0) return c;
      c = a.roomName.compareTo(b.roomName);
      if (c != 0) return c;
      c = a.dayOfWeek.compareTo(b.dayOfWeek);
      return c != 0 ? c : a.startMin.compareTo(b.startMin);
    });
    return list;
  }

  static Future<List<ClassScheduleModel>> forRoom(String roomId) async =>
      _map(await _col.where('room_id', isEqualTo: roomId).get());

  static Future<List<ClassScheduleModel>> forWeekday(int weekday) async =>
      _map(await _col.where('day_of_week', isEqualTo: weekday).get());

  static Future<List<ClassScheduleModel>> forRoomWeekday(String roomId, int weekday) async {
    final list = await forRoom(roomId);
    return list.where((c) => c.dayOfWeek == weekday).toList();
  }

  /// First class block that overlaps [start, end), or null.
  static ClassScheduleModel? firstOverlap(List<ClassScheduleModel> blocks, int start, int end) {
    for (final c in blocks) {
      if (start < c.endMin && end > c.startMin) return c;
    }
    return null;
  }

  /// Saves parsed entries. With [replace], every existing block of [collegeCode] is deleted first.
  /// Without it, blocks identical to existing ones are skipped. Returns how many were written.
  static Future<int> save(
    List<ClassScheduleModel> entries, {
    required String collegeCode,
    required bool replace,
  }) async {
    var toWrite = entries;
    if (replace) {
      await clear(collegeCode: collegeCode);
    } else {
      final existing = _map(await _col.where('college_code', isEqualTo: collegeCode).get())
          .map((c) => c.key)
          .toSet();
      toWrite = entries.where((e) => !existing.contains(e.key)).toList();
    }
    var written = 0;
    for (var i = 0; i < toWrite.length; i += 400) {
      final chunk = toWrite.sublist(i, math.min(i + 400, toWrite.length));
      final batch = _db.batch();
      for (final e in chunk) {
        final ref = _col.doc();
        batch.set(ref, e.withId(ref.id).toMap());
      }
      await batch.commit();
      written += chunk.length;
    }
    return written;
  }

  /// Deletes all class blocks (or only those of [collegeCode]). Returns how many were deleted.
  static Future<int> clear({String? collegeCode}) async {
    final snap = collegeCode == null
        ? await _col.get()
        : await _col.where('college_code', isEqualTo: collegeCode).get();
    final docs = snap.docs;
    for (var i = 0; i < docs.length; i += 400) {
      final batch = _db.batch();
      for (final d in docs.sublist(i, math.min(i + 400, docs.length))) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    return docs.length;
  }
}