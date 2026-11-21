import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';
import 'package:room_reservation_expohack/models/class_schedule_model.dart';
import 'package:room_reservation_expohack/models/room_model.dart';
import 'package:room_reservation_expohack/services/class_schedule_service.dart';

class BookingConflictException implements Exception {
  final String message;
  final BookingModel conflictingBooking;
  BookingConflictException(this.message, this.conflictingBooking);

  @override
  String toString() => message;
}

/// Thrown when a request overlaps a recurring class from `class_schedules`.
class ClassBlockedException extends BookingConflictException {
  final ClassScheduleModel schedule;
  ClassBlockedException(this.schedule, BookingModel placeholder)
      : super(schedule.blockReason, placeholder);
}

class TimeSlotOption {
  final int startTime;
  final int endTime;
  final String label;
  const TimeSlotOption(this.startTime, this.endTime, this.label);
}

class AlternativeRecommendation {
  final List<RoomModel> bestFitRooms;
  final List<TimeSlotOption> nearestFreeSlots;
  const AlternativeRecommendation(this.bestFitRooms, this.nearestFreeSlots);
}

class BatchBenchmarkResult {
  final int totalProcessed;
  final int confirmedCount;
  final int blockedCount;
  final int doubleBookings;
  final int elapsedMs;
  const BatchBenchmarkResult(
    this.totalProcessed,
    this.confirmedCount,
    this.blockedCount,
    this.doubleBookings,
    this.elapsedMs,
  );
}

class BookingAlgorithmService {
  static const int operatingStart = 480; // 8:00 AM (UniSpace booking hours)
  static const int operatingEnd = 1020; // 5:00 PM
  static const int slotStep = 30; // minutes

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');
  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');

  static bool isActive(String status) =>
      status == 'pending' || status == 'approved';

  static bool overlaps(int aStart, int aEnd, int bStart, int bEnd) =>
      aStart < bEnd && aEnd > bStart;

  /// Describes a class block as a booking-shaped object (status "class") for conflict reporting.
  static BookingModel classAsBooking(ClassScheduleModel c, String date) {
    return BookingModel(
      id: '',
      roomId: c.roomId,
      roomName: c.roomName,
      departmentName: c.collegeCode,
      eventName: c.label,
      requesterName: c.instructor,
      organization: 'Class schedule',
      requesterRole: 'Instructor',
      bookingDate: date,
      startTime: c.startMin,
      endTime: c.endMin,
      attendeeCount: 0,
      includedEquipment: const <String>[],
      status: 'class',
      requiredSignatories: const <String>[],
      approvedBy: const <String>[],
      createdAt: DateTime.now(),
    );
  }

  /// Adds "University President" when more than 100 attendees are expected.
  static List<String> effectiveSignatories(
      List<String> base, int attendeeCount) {
    final list = List<String>.from(base);
    if (attendeeCount > 100 && !list.contains('University President')) {
      list.add('University President');
    }
    return list;
  }

  // ---------------------------------------------------------------- Streams

  Stream<List<RoomModel>> streamRooms() {
    return _rooms.snapshots().map((snap) {
      final list =
          snap.docs.map((d) => RoomModel.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) {
        final c = a.departmentName.compareTo(b.departmentName);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
      return list;
    });
  }

  Stream<List<BookingModel>> streamBookingsForRoom(String roomId) {
    return _bookings.where('roomId', isEqualTo: roomId).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => BookingModel.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) {
        final c = a.bookingDate.compareTo(b.bookingDate);
        return c != 0 ? c : a.startTime.compareTo(b.startTime);
      });
      return list;
    });
  }

  Stream<List<BookingModel>> streamAllBookings() {
    return _bookings.snapshots().map((snap) {
      final list =
          snap.docs.map((d) => BookingModel.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ---------------------------------------------------------- Atomic create

  Future<void> createBookingAtomic(BookingModel newBooking) async {
    if (newBooking.endTime <= newBooking.startTime) {
      throw ArgumentError('End time must be after start time.');
    }

    // Recurring classes are hard-blocked intervals (they never change inside the transaction).
    final day = DateTime.tryParse(newBooking.bookingDate);
    if (day != null) {
      final classes =
          await ClassScheduleService.forRoomWeekday(newBooking.roomId, day.weekday);
      final hit = ClassScheduleService.firstOverlap(
          classes, newBooking.startTime, newBooking.endTime);
      if (hit != null) {
        throw ClassBlockedException(
            hit, classAsBooking(hit, newBooking.bookingDate));
      }
    }

    // Queries are not allowed inside transactions, so find candidates first.
    final existingSnap = await _bookings
        .where('roomId', isEqualTo: newBooking.roomId)
        .where('bookingDate', isEqualTo: newBooking.bookingDate)
        .get();

    final newRef = _bookings.doc();
    BookingConflictException? conflict;

    await _db.runTransaction((tx) async {
      conflict = null;

      // Re-read every candidate document inside the transaction.
      for (final doc in existingSnap.docs) {
        final fresh = await tx.get(doc.reference);
        if (!fresh.exists) continue;
        final existing = BookingModel.fromMap(fresh.data()!, fresh.id);
        if (!isActive(existing.status)) continue;
        if (existing.startTime < newBooking.endTime &&
            existing.endTime > newBooking.startTime) {
          conflict = BookingConflictException(
            '${newBooking.roomName} is already ${existing.status} for '
            '"${existing.eventName}" (${existing.formattedTimeRange}).',
            existing,
          );
          return;
        }
      }

      final toSave = newBooking.copyWith(
        id: newRef.id,
        status: 'pending',
        approvedBy: <String>[],
        requiredSignatories: effectiveSignatories(
            newBooking.requiredSignatories, newBooking.attendeeCount),
        createdAt: DateTime.now(),
      );
      tx.set(newRef, toSave.toMap());
    });

    final c = conflict;
    if (c != null) throw c;
  }

  // ------------------------------------------------------ Smart alternatives

  Future<AlternativeRecommendation> getSmartAlternatives({
    required RoomModel targetRoom,
    required String bookingDate,
    required int startTime,
    required int endTime,
    required int attendeeCount,
    required List<String> requiredEquipment,
  }) async {
    final roomsSnap = await _rooms.get();
    final bookingsSnap =
        await _bookings.where('bookingDate', isEqualTo: bookingDate).get();

    final weekday = DateTime.tryParse(bookingDate)?.weekday;
    final classes = weekday == null
        ? <ClassScheduleModel>[]
        : await ClassScheduleService.forWeekday(weekday);

    final rooms =
        roomsSnap.docs.map((d) => RoomModel.fromMap(d.data(), d.id)).toList();
    final active = bookingsSnap.docs
        .map((d) => BookingModel.fromMap(d.data(), d.id))
        .where((b) => isActive(b.status))
        .toList();

    bool isFree(String roomId, int s, int e) =>
        !active.any(
            (b) => b.roomId == roomId && overlaps(b.startTime, b.endTime, s, e)) &&
        !classes.any(
            (c) => c.roomId == roomId && overlaps(c.startMin, c.endMin, s, e));

    final bestFit = rooms.where((r) {
      return r.id != targetRoom.id &&
          r.capacity >= attendeeCount &&
          requiredEquipment.every(r.equipment.contains) &&
          isFree(r.id, startTime, endTime);
    }).toList()
      ..sort((a, b) => (a.capacity - attendeeCount)
          .compareTo(b.capacity - attendeeCount));

    final duration = endTime - startTime;
    final candidates = <int>[];
    for (var s = operatingStart; s + duration <= operatingEnd; s += 30) {
      if (isFree(targetRoom.id, s, s + duration)) candidates.add(s);
    }
    candidates.sort((a, b) {
      final c = (a - startTime).abs().compareTo((b - startTime).abs());
      return c != 0 ? c : a.compareTo(b);
    });

    final slots = candidates
        .take(3)
        .map((s) => TimeSlotOption(s, s + duration,
            '${formatMinutes(s)} - ${formatMinutes(s + duration)}'))
        .toList();

    return AlternativeRecommendation(bestFit, slots);
  }

  // ------------------------------------------------------------ Status ops

  Future<void> approveBooking({
    required String bookingId,
    required String signatoryName,
  }) async {
    final docRef = _bookings.doc(bookingId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw StateError('Booking no longer exists.');
      final booking = BookingModel.fromMap(snap.data()!, snap.id);
      if (booking.status != 'pending') return;

      final approvedBy = List<String>.from(booking.approvedBy);
      if (!approvedBy.contains(signatoryName)) approvedBy.add(signatoryName);

      final allDone =
          booking.requiredSignatories.every((s) => approvedBy.contains(s));
      tx.update(docRef, <String, dynamic>{
        'approvedBy': approvedBy,
        if (allDone) 'status': 'approved',
      });
    });
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String newStatus,
  }) async {
    await _bookings.doc(bookingId).update(<String, dynamic>{'status': newStatus});
  }

  // ------------------------------------------------------------- Benchmark

  Future<BatchBenchmarkResult> runBatchBaselineTest() async {
    const testDate = '2099-12-31';
    const testRoomId = 'benchmark_test_room';

    Future<void> cleanup() async {
      final snap = await _bookings
          .where('roomId', isEqualTo: testRoomId)
          .where('bookingDate', isEqualTo: testDate)
          .get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }

    BookingModel make(int index, int start, int end) {
      return BookingModel(
        id: '',
        roomId: testRoomId,
        roomName: 'Benchmark Room',
        departmentName: 'General Facilities',
        eventName: 'Benchmark Event $index',
        requesterName: 'Benchmark Bot',
        organization: 'Load Test',
        requesterRole: 'Officer',
        bookingDate: testDate,
        startTime: start,
        endTime: end,
        attendeeCount: 20,
        includedEquipment: const <String>[],
        status: 'pending',
        requiredSignatories: const ['GSO Head'],
        approvedBy: const <String>[],
        createdAt: DateTime.now(),
      );
    }

    // 10 valid hourly requests + 5 intentional overlaps, interleaved.
    const overlapRanges = <List<int>>[
      [450, 510],
      [570, 630],
      [690, 780],
      [840, 900],
      [960, 1020],
    ];
    final requests = <BookingModel>[];
    var o = 0;
    for (var i = 0; i < 10; i++) {
      requests.add(make(requests.length + 1, 420 + i * 60, 480 + i * 60));
      if (i.isOdd) {
        requests.add(
            make(requests.length + 1, overlapRanges[o][0], overlapRanges[o][1]));
        o++;
      }
    }

    await cleanup(); // remove leftovers from a previous interrupted run

    var confirmed = 0;
    var blocked = 0;
    var doubleBookings = 0;
    int elapsedMs;

    try {
      final stopwatch = Stopwatch()..start();
      for (final request in requests) {
        try {
          await createBookingAtomic(request);
          confirmed++;
        } on BookingConflictException {
          blocked++;
        }
      }
      stopwatch.stop();
      elapsedMs = stopwatch.elapsedMilliseconds;

      final verify = await _bookings
          .where('roomId', isEqualTo: testRoomId)
          .where('bookingDate', isEqualTo: testDate)
          .get();
      final saved = verify.docs
          .map((d) => BookingModel.fromMap(d.data(), d.id))
          .where((b) => isActive(b.status))
          .toList();
      for (var i = 0; i < saved.length; i++) {
        for (var j = i + 1; j < saved.length; j++) {
          if (overlaps(saved[i].startTime, saved[i].endTime, saved[j].startTime,
              saved[j].endTime)) {
            doubleBookings++;
          }
        }
      }
    } finally {
      await cleanup();
    }

    return BatchBenchmarkResult(
        requests.length, confirmed, blocked, doubleBookings, elapsedMs);
  }
}