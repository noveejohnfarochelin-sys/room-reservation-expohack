import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';
import 'package:room_reservation_expohack/models/room_model.dart';
import 'package:room_reservation_expohack/services/booking_algorithm_service.dart';
import 'package:room_reservation_expohack/services/seed_service.dart';

class Resp {
  final int status;
  final dynamic data;
  Resp(this.status, this.data);
  bool get ok => status >= 200 && status < 300;
  String get error =>
      (data is Map && data['error'] != null) ? data['error'].toString() : 'Something went wrong.';
}

/// Firestore-backed replacement for the UI's in-memory MockServer.
///
/// It answers the same method + path requests with the same JSON shapes, so the
/// UI keeps calling `Api.call(...)` unchanged. All booking rules live in
/// [BookingAlgorithmService] (atomic create, smart alternatives).
class FirestoreServer {
  FirestoreServer._();

  static const List<String> buildings = ['CEA', 'CCI', 'COE', 'CIT', 'CGBE', 'LIB'];

  static const int _open = BookingAlgorithmService.operatingStart;
  static const int _close = BookingAlgorithmService.operatingEnd;
  static const int _step = BookingAlgorithmService.slotStep;

  // Demo accounts (client-side only – this is NOT real authentication).
  static const Map<String, Map<String, String>> _users = {
    'student': {'pw': 'student', 'id': 'student', 'name': 'Demo Student', 'role': 'requester'},
    'student2': {'pw': 'student2', 'id': 'student2', 'name': 'Second Student', 'role': 'requester'},
    'admin': {'pw': 'admin', 'id': 'admin', 'name': 'Room Admin', 'role': 'admin'},
  };

  static final BookingAlgorithmService _service = BookingAlgorithmService();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _bookings => _db.collection('bookings');

  // ----------------------------------------------------------------- helpers

  static String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static List<RoomModel>? _roomsCache;

  /// Rooms rarely change, so they are read once per app session.
  static Future<List<RoomModel>> _allRooms() async {
    final cached = _roomsCache;
    if (cached != null) return cached;
    final snap = await _db.collection('rooms').get();
    final list = snap.docs.map((d) => RoomModel.fromMap(d.data(), d.id)).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _roomsCache = list;
    return list;
  }

  static Future<RoomModel?> _roomById(String id) async {
    for (final r in await _allRooms()) {
      if (r.id == id) return r;
    }
    return null;
  }

  static String _label(RoomModel r) {
    if (r.isStandalone) return 'Campus Facility';
    return r.code == 'LIB' ? 'Library' : r.code;
  }

  static String _addressee(RoomModel r) {
    if (r.isStandalone) return 'The Director, Campus Facilities Office';
    if (r.code == 'LIB') return 'The University Librarian';
    return 'The Dean, College of ${r.code}';
  }

  static Map<String, dynamic> _roomOut(RoomModel r) => <String, dynamic>{
        'id': r.id,
        'name': r.name,
        'kind': r.kind,
        'capacity': r.capacity,
        'code': r.code,
        'blurb': r.blurb,
        'college': _label(r),
        'addressee': _addressee(r),
      };

  static Map<String, dynamic> _bookingOut(BookingModel b, RoomModel? r) => <String, dynamic>{
        'id': b.id,
        'room_id': b.roomId,
        'user_id': b.userId,
        'date': b.bookingDate,
        'start_min': b.startTime,
        'end_min': b.endTime,
        'status': b.status,
        'requester_name': b.requesterName,
        'organization': b.organization,
        'purpose': b.eventName,
        'attendees': b.attendeeCount,
        'room_name': r?.name ?? b.roomName,
        'college': r == null ? b.departmentName : _label(r),
        'code': r?.code ?? '',
        'addressee': r == null ? 'The Dean' : _addressee(r),
      };

  static List<BookingModel> _toBookings(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => BookingModel.fromMap(d.data(), d.id)).toList();

  /// Pending + approved bookings of one date (all rooms).
  static Future<List<BookingModel>> _activeOnDate(String date) async {
    final snap = await _bookings.where('bookingDate', isEqualTo: date).get();
    return _toBookings(snap).where((b) => BookingAlgorithmService.isActive(b.status)).toList();
  }

  /// Pending + approved bookings of one room on one date, earliest first.
  static Future<List<BookingModel>> _activeForRoomDay(String roomId, String date) async {
    final snap = await _bookings
        .where('roomId', isEqualTo: roomId)
        .where('bookingDate', isEqualTo: date)
        .get();
    return _toBookings(snap).where((b) => BookingAlgorithmService.isActive(b.status)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  static List<List<int>> _freeWindows(List<BookingModel> busy) {
    final sorted = [...busy]..sort((a, b) => a.startTime.compareTo(b.startTime));
    final free = <List<int>>[];
    var cursor = _open;
    for (final b in sorted) {
      if (b.startTime > cursor) {
        free.add([cursor, b.startTime < _close ? b.startTime : _close]);
      }
      if (b.endTime > cursor) cursor = b.endTime;
    }
    if (cursor < _close) free.add([cursor, _close]);
    return free;
  }

  static String? _validate(Map<String, dynamic> b) {
    final date = (b['date'] ?? '').toString();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) || DateTime.tryParse(date) == null) {
      return 'Pick a date.';
    }
    if (date.compareTo(_today()) < 0) return 'That date has already passed.';
    final s = b['start_min'];
    final e = b['end_min'];
    if (s is! int || e is! int) return 'Pick a start and end time.';
    if (s >= e) return 'End time must be after start time.';
    if (s < _open || e > _close) return 'Rooms can be booked from 8:00 AM to 5:00 PM only.';
    if (s % _step != 0 || e % _step != 0) return 'Times must be in 30-minute steps.';
    for (final f in ['requester_name', 'organization', 'purpose']) {
      if ((b[f] ?? '').toString().trim().isEmpty) return 'Please fill in all required fields.';
    }
    final a = b['attendees'];
    if (a is! int || a <= 0) return 'Enter the number of attendees.';
    return null;
  }

  /// Used by the UI's "Letter" button.
  static Future<Map<String, dynamic>?> bookingById(String id) async {
    final doc = await _bookings.doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    final b = BookingModel.fromMap(data, doc.id);
    return _bookingOut(b, await _roomById(b.roomId));
  }

  // ----------------------------------------------------------------- router

  static Future<Resp> handle(
      String method, String path, Map<String, dynamic> body, String? token) async {
    final uri = Uri.parse(path);
    final seg = uri.pathSegments;
    final q = uri.queryParameters;

    // POST /login
    if (method == 'POST' && path == '/login') {
      final u = _users[(body['username'] ?? '').toString()];
      if (u == null || u['pw'] != body['password']) {
        return Resp(401, {'error': 'Wrong username or password.'});
      }
      return Resp(200, {
        'token': 'tok-${u['id']}',
        'user': {'id': u['id'], 'name': u['name'], 'role': u['role']},
      });
    }

    final uname = (token ?? '').startsWith('tok-') ? token!.substring(4) : null;
    final me = uname == null ? null : _users[uname];
    if (me == null) return Resp(401, {'error': 'Please sign in.'});
    final isAdmin = me['role'] == 'admin';

    // GET /colleges  (5 colleges + library)
    if (method == 'GET' && path == '/colleges') {
      final rooms = await _allRooms();
      return Resp(200, <Map<String, dynamic>>[
        for (final code in buildings)
          <String, dynamic>{
            'id': code,
            'code': code,
            'rooms': rooms.where((r) => !r.isStandalone && r.code == code).length,
          }
      ]);
    }

    // GET /facilities  (gym + grandstand)
    if (method == 'GET' && path == '/facilities') {
      final rooms = await _allRooms();
      return Resp(200, <Map<String, dynamic>>[
        for (final r in rooms.where((r) => r.isStandalone)) _roomOut(r)
      ]);
    }

    // GET /stats
    if (method == 'GET' && path == '/stats') {
      final rooms = await _allRooms();
      final groupOf = <String, String>{
        for (final r in rooms) r.id: r.isStandalone ? 'FAC' : r.code
      };
      final all = _toBookings(await _bookings.get());
      final today = _today();
      var total = 0, pend = 0, appr = 0, rej = 0, tod = 0;
      final groups = <String, List<int>>{
        for (final g in [...buildings, 'FAC']) g: [0, 0]
      };
      for (final b in all) {
        final group = groupOf[b.roomId];
        if (group == null || b.status == 'cancelled') continue; // unknown room / cancelled
        total++;
        if (b.status == 'pending') pend++;
        if (b.status == 'approved') appr++;
        if (b.status == 'rejected') rej++;
        if (BookingAlgorithmService.isActive(b.status)) {
          final g = groups[group];
          if (g != null) {
            g[0]++;
            if (b.status == 'pending') g[1]++;
          }
          if (b.bookingDate == today) tod++;
        }
      }
      return Resp(200, <String, dynamic>{
        'total': total,
        'pending': pend,
        'approved': appr,
        'rejected': rej,
        'today': tod,
        'groups': <Map<String, dynamic>>[
          for (final e in groups.entries)
            <String, dynamic>{'code': e.key, 'total': e.value[0], 'pending': e.value[1]}
        ],
      });
    }

    // GET /colleges/:code/rooms?date=
    if (method == 'GET' && seg.length == 3 && seg[0] == 'colleges' && seg[2] == 'rooms') {
      final code = seg[1];
      final date = q['date'] ?? _today();
      final rooms =
          (await _allRooms()).where((r) => !r.isStandalone && r.code == code).toList();
      final day = await _activeOnDate(date);
      return Resp(200, <Map<String, dynamic>>[
        for (final r in rooms)
          () {
            final busy = day.where((b) => b.roomId == r.id).toList();
            final freeMin =
                _freeWindows(busy).fold<int>(0, (sum, w) => sum + (w[1] - w[0]));
            return <String, dynamic>{
              ..._roomOut(r),
              'freeMinutes': freeMin,
              'status': freeMin == 0 ? 'full' : (freeMin < _close - _open ? 'partial' : 'free'),
            };
          }()
      ]);
    }

    // GET /rooms/:id, /rooms/:id/calendar?month=, /rooms/:id/day?date=
    if (method == 'GET' && seg.length >= 2 && seg[0] == 'rooms') {
      final rid = seg[1];
      final room = await _roomById(rid);
      if (room == null) return Resp(404, {'error': 'Room not found.'});
      if (seg.length == 2) return Resp(200, _roomOut(room));

      if (seg[2] == 'calendar') {
        final month = q['month'] ?? _today().substring(0, 7);
        final snap = await _bookings.where('roomId', isEqualTo: rid).get();
        final minutes = <String, int>{};
        final pending = <String, bool>{};
        for (final b in _toBookings(snap)) {
          if (!BookingAlgorithmService.isActive(b.status)) continue;
          if (!b.bookingDate.startsWith('$month-')) continue;
          minutes[b.bookingDate] = (minutes[b.bookingDate] ?? 0) + (b.endTime - b.startTime);
          if (b.status == 'pending') pending[b.bookingDate] = true;
        }
        final out = <String, dynamic>{};
        minutes.forEach((date, m) {
          out[date] = <String, dynamic>{
            'state': m >= _close - _open ? 'full' : 'partial',
            'pending': pending[date] ?? false,
          };
        });
        return Resp(200, out);
      }

      if (seg[2] == 'day') {
        final date = q['date'] ?? _today();
        final busy = await _activeForRoomDay(rid, date);
        return Resp(200, <String, dynamic>{
          'open': _open,
          'close': _close,
          'step': _step,
          'busy': <Map<String, dynamic>>[
            for (final b in busy)
              <String, dynamic>{
                'start_min': b.startTime,
                'end_min': b.endTime,
                'status': b.status,
              }
          ],
          'free': _freeWindows(busy),
        });
      }
    }

    // POST /bookings
    if (method == 'POST' && path == '/bookings') {
      final room = await _roomById((body['room_id'] ?? '').toString());
      if (room == null) return Resp(404, {'error': 'Room not found.'});

      final err = _validate(body);
      if (err != null) return Resp(400, {'error': err});

      final attendees = body['attendees'] as int;
      if (attendees > room.capacity) {
        return Resp(400, {'error': '${room.name} holds ${room.capacity} people at most.'});
      }

      final draft = BookingModel(
        id: '',
        roomId: room.id,
        roomName: room.name,
        departmentName: room.departmentName,
        eventName: (body['purpose'] ?? '').toString().trim(),
        requesterName: (body['requester_name'] ?? '').toString().trim(),
        organization: (body['organization'] ?? '').toString().trim(),
        requesterRole: 'Requester',
        bookingDate: body['date'].toString(),
        startTime: body['start_min'] as int,
        endTime: body['end_min'] as int,
        attendeeCount: attendees,
        includedEquipment: const <String>[],
        status: 'pending',
        requiredSignatories: room.requiredSignatories,
        approvedBy: const <String>[],
        createdAt: DateTime.now(),
        userId: me['id'] ?? '',
      );

      try {
        await _service.createBookingAtomic(draft);
        return Resp(201, {'status': 'pending'});
      } on BookingConflictException {
        final rec = await _service.getSmartAlternatives(
          targetRoom: room,
          bookingDate: draft.bookingDate,
          startTime: draft.startTime,
          endTime: draft.endTime,
          attendeeCount: attendees,
          requiredEquipment: const <String>[],
        );
        final nearest = rec.nearestFreeSlots.isEmpty ? null : rec.nearestFreeSlots.first;
        // Other rooms: same building only, big enough, best fit first.
        final others = room.isStandalone
            ? const <RoomModel>[]
            : rec.bestFitRooms
                .where((r) => !r.isStandalone && r.code == room.code)
                .take(5)
                .toList();
        return Resp(409, <String, dynamic>{
          'error': 'That time is already taken.',
          'suggestions': <String, dynamic>{
            'sameRoom': nearest == null
                ? null
                : <String, dynamic>{
                    'start_min': nearest.startTime,
                    'end_min': nearest.endTime,
                  },
            'otherRooms': <Map<String, dynamic>>[
              for (final r in others)
                <String, dynamic>{'id': r.id, 'name': r.name, 'capacity': r.capacity}
            ],
          },
        });
      }
    }

    // GET /bookings/mine
    if (method == 'GET' && path == '/bookings/mine') {
      final snap = await _bookings.where('userId', isEqualTo: me['id']).get();
      final list = _toBookings(snap)..sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
      final rooms = {for (final r in await _allRooms()) r.id: r};
      return Resp(200, <Map<String, dynamic>>[
        for (final b in list) _bookingOut(b, rooms[b.roomId])
      ]);
    }

    // GET /bookings  (admin)
    if (method == 'GET' && path == '/bookings') {
      if (!isAdmin) return Resp(403, {'error': 'Not allowed.'});
      final list = _toBookings(await _bookings.get());
      list.sort((a, b) {
        final pa = a.status == 'pending' ? 0 : 1;
        final pb = b.status == 'pending' ? 0 : 1;
        if (pa != pb) return pa.compareTo(pb);
        final c = a.bookingDate.compareTo(b.bookingDate);
        return c != 0 ? c : a.startTime.compareTo(b.startTime);
      });
      final rooms = {for (final r in await _allRooms()) r.id: r};
      return Resp(200, <Map<String, dynamic>>[
        for (final b in list) _bookingOut(b, rooms[b.roomId])
      ]);
    }

    // PATCH /bookings/:id   admin: approved | rejected | cancelled
    //                       requester: cancelled (own bookings only)
    if (method == 'PATCH' && seg.length == 2 && seg[0] == 'bookings') {
      final next = (body['status'] ?? '').toString();
      if (!const ['approved', 'rejected', 'cancelled'].contains(next)) {
        return Resp(400, {'error': 'Bad status.'});
      }
      if (!isAdmin && next != 'cancelled') return Resp(403, {'error': 'Not allowed.'});

      final ref = _bookings.doc(seg[1]);
      String? failure;
      await _db.runTransaction((tx) async {
        failure = null;
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) {
          failure = 'missing';
          return;
        }
        final b = BookingModel.fromMap(data, snap.id);
        if (!isAdmin && b.userId != me['id']) {
          failure = 'forbidden';
          return;
        }
        // Only pending requests can be approved/rejected; only active ones cancelled.
        final allowed = next == 'cancelled'
            ? BookingAlgorithmService.isActive(b.status)
            : b.status == 'pending';
        if (!allowed) {
          failure = 'state';
          return;
        }
        tx.update(ref, <String, dynamic>{
          'status': next,
          // Admin approval counts as every required signatory approving.
          if (next == 'approved') 'approvedBy': b.requiredSignatories,
        });
      });

      if (failure == 'missing') return Resp(404, {'error': 'Request not found.'});
      if (failure == 'forbidden') return Resp(403, {'error': 'Not allowed.'});
      if (failure == 'state') {
        return Resp(400, {'error': 'That request can no longer be changed.'});
      }
      return Resp(200, {'ok': true});
    }

    // POST /demo/reset  (admin) – deletes all bookings
    if (method == 'POST' && path == '/demo/reset') {
      if (!isAdmin) return Resp(403, {'error': 'Not allowed.'});
      await SeedService.deleteCollection('bookings');
      return Resp(200, {'ok': true});
    }

    // POST /demo/benchmark  (admin) – 15 requests, 10 valid + 5 overlaps
    if (method == 'POST' && path == '/demo/benchmark') {
      if (!isAdmin) return Resp(403, {'error': 'Not allowed.'});
      final r = await _service.runBatchBaselineTest();
      return Resp(200, <String, dynamic>{
        'total': r.totalProcessed,
        'confirmed': r.confirmedCount,
        'blocked': r.blockedCount,
        'doubleBookings': r.doubleBookings,
        'elapsedMs': r.elapsedMs,
      });
    }

    return Resp(404, {'error': 'Not found.'});
  }
}
