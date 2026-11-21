import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';
import 'package:room_reservation_expohack/models/room_model.dart';

/// Seeds the same rooms and sample bookings as the UniSpace demo server.
///
/// Safe to call on every app start:
///  * data already in the new format  -> does nothing
///  * empty database                  -> seeds
///  * data from the OLD seed (rooms without a `code` field) -> deletes the old
///    `rooms` and `bookings` collections once, then seeds the new data.
class SeedService {
  static const List<String> _buildings = ['CEA', 'CCI', 'COE', 'CIT', 'CGBE', 'LIB'];

  static const Map<String, String> _departmentNames = {
    'CEA': 'College of Engineering and Architecture',
    'CCI': 'College of Computing and Informatics',
    'COE': 'College of Education',
    'CIT': 'College of Industrial Technology',
    'CGBE': 'College of Governance and Business Economics',
    'LIB': 'University Library',
  };

  static const Map<String, List<String>> _signatories = {
    'CEA': ['CEA Dean'],
    'CCI': ['CCI Dean'],
    'COE': ['COE Dean'],
    'CIT': ['CIT Dean'],
    'CGBE': ['CGBE Dean'],
    'LIB': ['University Librarian'],
  };

  static const List<String> _venueSignatories = ['GSO Head', 'University President'];

  // [name, kind, capacity]
  static final Map<String, List<List<Object>>> _spec = {
    'CEA': [
      ['Room 101', 'Lecture room', 40], ['Room 102', 'Lecture room', 40], ['Room 201', 'Lecture room', 45],
      ['Design Studio 1', 'Studio', 30], ['Design Studio 2', 'Studio', 30], ['Drafting Room', 'Studio', 35],
      ['Materials Testing Lab', 'Laboratory', 25], ['Computer Lab 1', 'Laboratory', 30],
      ['Model-Making Workshop', 'Workshop', 20], ['Seminar Room', 'Meeting room', 50],
      ['AVR / Function Hall', 'Facility', 150],
    ],
    'CCI': [
      ['Room 101', 'Lecture room', 40], ['Room 102', 'Lecture room', 40],
      ['Computer Lab 1', 'Laboratory', 30], ['Computer Lab 2', 'Laboratory', 30],
      ['Networking Lab', 'Laboratory', 25], ['Programming Lab', 'Laboratory', 35],
      ['Multimedia Lab', 'Laboratory', 28], ['Seminar Room', 'Meeting room', 50],
      ['Conference Room', 'Meeting room', 20], ['AVR / Function Hall', 'Facility', 150],
    ],
    'COE': [
      ['Room 101', 'Lecture room', 40], ['Room 102', 'Lecture room', 40],
      ['Demo Teaching Room', 'Lecture room', 35], ['Microteaching Lab', 'Laboratory', 20],
      ['Speech Laboratory', 'Laboratory', 25], ['Seminar Room', 'Meeting room', 50],
      ['Conference Room', 'Meeting room', 20], ['AVR / Function Hall', 'Facility', 150],
    ],
    'CIT': [
      ['Room 101', 'Lecture room', 40], ['Room 102', 'Lecture room', 40],
      ['Machine Shop', 'Workshop', 25], ['Welding Shop', 'Workshop', 20],
      ['Electronics Lab', 'Laboratory', 30], ['Automotive Bay', 'Workshop', 20],
      ['Drafting Room', 'Studio', 35], ['Seminar Room', 'Meeting room', 50],
      ['AVR / Function Hall', 'Facility', 150],
    ],
    'CGBE': [
      ['Room 101', 'Lecture room', 40], ['Room 102', 'Lecture room', 40],
      ['Moot Court', 'Facility', 60], ['Accounting Lab', 'Laboratory', 30],
      ['Business Simulation Room', 'Laboratory', 30], ['Conference Room', 'Meeting room', 20],
      ['Seminar Room', 'Meeting room', 50], ['AVR / Function Hall', 'Facility', 150],
    ],
    'LIB': [
      ['Reading Hall', 'Facility', 80], ['Group Study Room 1', 'Study room', 8],
      ['Group Study Room 2', 'Study room', 8], ['Group Study Room 3', 'Study room', 8],
      ['Discussion Room', 'Study room', 12], ['Media Room', 'Facility', 25],
      ['Research Commons', 'Study room', 30], ['Conference Room', 'Meeting room', 20],
    ],
  };

  static const Map<String, String> _userNames = {
    'student': 'Demo Student',
    'student2': 'Second Student',
  };

  static String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  /// Deterministic id of a college/library room, e.g. cci_room_101.
  static String roomId(String code, String name) =>
      '${code.toLowerCase()}_${_slug(name)}';

  /// Deletes every document of a collection (in batches of 400).
  static Future<void> deleteCollection(String name) async {
    final db = FirebaseFirestore.instance;
    while (true) {
      final snap = await db.collection(name).limit(400).get();
      if (snap.docs.isEmpty) return;
      final batch = db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<String> seedInitialData() async {
    final db = FirebaseFirestore.instance;

    final probe = await db.collection('rooms').limit(1).get();
    var migrated = false;
    if (probe.docs.isNotEmpty) {
      if (probe.docs.first.data().containsKey('code')) {
        return 'Rooms already exist. Seeding skipped.';
      }
      // Old schema from the first version of the app: clear it once.
      await deleteCollection('bookings');
      await deleteCollection('rooms');
      migrated = true;
    }

    // ------------------------------------------------------------- rooms
    final rooms = <RoomModel>[];
    var order = 0;
    for (final code in _buildings) {
      for (final s in _spec[code]!) {
        final name = s[0] as String;
        rooms.add(RoomModel(
          id: roomId(code, name),
          name: name,
          categoryType: 'Department',
          departmentName: _departmentNames[code]!,
          capacity: s[2] as int,
          equipment: const <String>[],
          requiredSignatories: _signatories[code]!,
          code: code,
          kind: s[1] as String,
          sortOrder: order++,
        ));
      }
    }
    rooms.add(RoomModel(
      id: 'mec',
      name: 'Multipurpose Educational Center',
      categoryType: 'General',
      departmentName: 'General Facilities',
      capacity: 1500,
      equipment: const <String>[],
      requiredSignatories: _venueSignatories,
      code: 'MEC',
      kind: 'Gym',
      blurb: 'The campus gym – sports events, assemblies and big gatherings.',
      sortOrder: order++,
    ));
    rooms.add(RoomModel(
      id: 'grandstand',
      name: 'Grandstand',
      categoryType: 'General',
      departmentName: 'General Facilities',
      capacity: 2000,
      equipment: const <String>[],
      requiredSignatories: _venueSignatories,
      code: 'GRAND',
      kind: 'Outdoor stage',
      blurb: 'The stage on the field – programs, ceremonies and concerts.',
      sortOrder: order++,
    ));
    final byId = {for (final r in rooms) r.id: r};

    // ---------------------------------------------------- sample bookings
    final dateFmt = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();
    final bookings = <BookingModel>[];

    void add(String rid, int dayOffset, int startHour, int endHour, String status,
        String purpose,
        {String user = 'student2', String org = 'Student Council'}) {
      final room = byId[rid]!;
      final attendees = room.capacity < 20 ? room.capacity : 20;
      bookings.add(BookingModel(
        id: '',
        roomId: room.id,
        roomName: room.name,
        departmentName: room.departmentName,
        eventName: purpose,
        requesterName: _userNames[user]!,
        organization: org,
        requesterRole: 'Requester',
        bookingDate: dateFmt.format(now.add(Duration(days: dayOffset))),
        startTime: startHour * 60,
        endTime: endHour * 60,
        attendeeCount: attendees,
        includedEquipment: const <String>[],
        status: status,
        requiredSignatories: room.requiredSignatories,
        approvedBy: status == 'approved' ? room.requiredSignatories : const <String>[],
        createdAt: now,
        userId: user,
      ));
    }

    add(roomId('CCI', 'Room 101'), 0, 10, 12, 'approved', 'Org meeting');
    add(roomId('CCI', 'Room 101'), 0, 14, 15, 'pending', 'Review session');
    add(roomId('CCI', 'Room 101'), 1, 8, 17, 'approved', 'Seminar');
    add(roomId('CCI', 'Computer Lab 1'), 0, 8, 10, 'approved', 'Hackathon prep');
    add(roomId('CCI', 'Seminar Room'), 0, 13, 14, 'approved', 'Thesis defense',
        user: 'student', org: 'CCI Dept.');
    add(roomId('CEA', 'Room 101'), 0, 13, 15, 'pending', 'Quiz bee');
    add(roomId('CEA', 'Design Studio 1'), 1, 9, 12, 'approved', 'Plate critique');
    add(roomId('CEA', 'AVR / Function Hall'), 2, 13, 17, 'approved', 'Engineering Week');
    add(roomId('COE', 'Demo Teaching Room'), 2, 8, 10, 'pending', 'Demo teaching');
    add(roomId('CIT', 'Machine Shop'), 0, 8, 12, 'approved', 'Skills training');
    add(roomId('CIT', 'AVR / Function Hall'), 1, 14, 17, 'pending', 'Tech talk');
    add(roomId('CGBE', 'Moot Court'), 3, 9, 11, 'approved', 'Mock trial',
        user: 'student', org: 'CGBE Dept.');
    add(roomId('CGBE', 'Conference Room'), 0, 15, 16, 'rejected', 'Meeting');
    add(roomId('LIB', 'Research Commons'), 0, 9, 11, 'approved', 'Research writing');
    add(roomId('LIB', 'Group Study Room 1'), 0, 13, 15, 'pending', 'Group study',
        user: 'student', org: 'BSIT 3A');
    add('mec', 2, 8, 12, 'approved', 'Intramurals');
    add('mec', 0, 15, 17, 'pending', 'Basketball practice',
        user: 'student', org: 'Varsity Team');
    add('grandstand', 5, 15, 17, 'pending', 'Foundation Day program');

    // ------------------------------------------------------------- write
    final batch = db.batch();
    for (final r in rooms) {
      batch.set(db.collection('rooms').doc(r.id), r.toMap());
    }
    for (final b in bookings) {
      batch.set(db.collection('bookings').doc(), b.toMap());
    }
    await batch.commit();

    return '${migrated ? 'Replaced old data. ' : ''}'
        'Seeded ${rooms.length} rooms and ${bookings.length} sample bookings.';
  }
}
