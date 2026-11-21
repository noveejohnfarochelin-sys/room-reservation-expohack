import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:room_reservation_expohack/models/booking_model.dart';
import 'package:room_reservation_expohack/models/room_model.dart';

class SeedService {
  Future<String> seedInitialData() async {
    final db = FirebaseFirestore.instance;
    final existing = await db.collection('rooms').limit(1).get();
    if (existing.docs.isNotEmpty) {
      return 'Rooms already exist. Seeding skipped.';
    }

    const rooms = <RoomModel>[
      RoomModel(
        id: 'cci_computer_lab_1',
        name: 'CCI Computer Lab 1',
        categoryType: 'Department',
        departmentName: 'College of Computing and Informatics',
        capacity: 40,
        equipment: ['Desktop PCs', 'Projector', 'Aircon'],
        requiredSignatories: ['CCI Dean'],
      ),
      RoomModel(
        id: 'cci_smart_classroom',
        name: 'CCI Smart Classroom',
        categoryType: 'Department',
        departmentName: 'College of Computing and Informatics',
        capacity: 50,
        equipment: ['Smart TV', 'Aircon'],
        requiredSignatories: ['CCI Dean'],
      ),
      RoomModel(
        id: 'coe_drafting_cad',
        name: 'COE Drafting & CAD Room',
        categoryType: 'Department',
        departmentName: 'College of Engineering',
        capacity: 45,
        equipment: ['Projector', 'Drafting Tables'],
        requiredSignatories: ['COE Dean'],
      ),
      RoomModel(
        id: 'general_avr',
        name: 'Audio-Visual Room (AVR)',
        categoryType: 'General',
        departmentName: 'General Facilities',
        capacity: 120,
        equipment: ['Projector', 'Sound System', 'Microphones', 'Aircon'],
        requiredSignatories: ['GSO Head'],
      ),
      RoomModel(
        id: 'general_function_hall',
        name: 'ISATU Function Hall',
        categoryType: 'General',
        departmentName: 'General Facilities',
        capacity: 200,
        equipment: ['Projector', 'Sound System', 'Catering Area'],
        requiredSignatories: ['GSO Head', 'University President'],
      ),
      RoomModel(
        id: 'general_gymnasium',
        name: 'University Gymnasium',
        categoryType: 'General',
        departmentName: 'General Facilities',
        capacity: 500,
        equipment: ['Sound System', 'Bleachers', 'Stage'],
        requiredSignatories: ['GSO Head', 'University President'],
      ),
    ];

    final batch = db.batch();
    for (final room in rooms) {
      batch.set(db.collection('rooms').doc(room.id), room.toMap());
    }

    final tomorrow = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 1)));

    final pending = BookingModel(
      id: '',
      roomId: 'cci_computer_lab_1',
      roomName: 'CCI Computer Lab 1',
      departmentName: 'College of Computing and Informatics',
      eventName: 'Programming Workshop',
      requesterName: 'Maria Santos',
      organization: 'ISATU Computer Society',
      requesterRole: 'President',
      bookingDate: tomorrow,
      startTime: 540,
      endTime: 660,
      attendeeCount: 30,
      includedEquipment: const ['Desktop PCs', 'Projector'],
      status: 'pending',
      requiredSignatories: const ['CCI Dean'],
      approvedBy: const [],
      createdAt: DateTime.now(),
    );

    final approved = BookingModel(
      id: '',
      roomId: 'general_avr',
      roomName: 'Audio-Visual Room (AVR)',
      departmentName: 'General Facilities',
      eventName: 'Student Leadership Seminar',
      requesterName: 'Juan Dela Cruz',
      organization: 'Supreme Student Council',
      requesterRole: 'President',
      bookingDate: tomorrow,
      startTime: 780,
      endTime: 900,
      attendeeCount: 80,
      includedEquipment: const ['Projector', 'Sound System'],
      status: 'approved',
      requiredSignatories: const ['GSO Head'],
      approvedBy: const ['GSO Head'],
      createdAt: DateTime.now(),
    );

    batch.set(db.collection('bookings').doc(), pending.toMap());
    batch.set(db.collection('bookings').doc(), approved.toMap());
    await batch.commit();

    return 'Seeded 6 rooms and 2 sample bookings for $tomorrow.';
  }
}