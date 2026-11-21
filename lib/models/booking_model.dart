import 'package:cloud_firestore/cloud_firestore.dart';

/// Formats minutes-from-midnight as "09:00 AM".
String formatMinutes(int minutes) {
  final h24 = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h24 >= 12 ? 'PM' : 'AM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
}

class BookingModel {
  final String id;
  final String roomId;
  final String roomName;
  final String departmentName;
  final String eventName; // the UI calls this "purpose"
  final String requesterName;
  final String organization;
  final String requesterRole;
  final String bookingDate; // YYYY-MM-DD
  final int startTime; // minutes from midnight
  final int endTime; // minutes from midnight
  final int attendeeCount;
  final List<String> includedEquipment;
  final String status; // pending, approved, cancelled, rejected
  final List<String> requiredSignatories;
  final List<String> approvedBy;
  final DateTime createdAt;
  final String userId; // demo username of the requester ("My requests" filter)
  final String rejectionReason; // why a signatory rejected the request
  final String rejectedBy; // signatory who rejected it

  const BookingModel({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.departmentName,
    required this.eventName,
    required this.requesterName,
    required this.organization,
    required this.requesterRole,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.attendeeCount,
    required this.includedEquipment,
    required this.status,
    required this.requiredSignatories,
    required this.approvedBy,
    required this.createdAt,
    this.userId = '',
    this.rejectionReason = '',
    this.rejectedBy = '',
  });

  factory BookingModel.fromMap(Map<String, dynamic> data, String id) {
    final created = data['createdAt'];
    return BookingModel(
      id: id,
      roomId: (data['roomId'] ?? '') as String,
      roomName: (data['roomName'] ?? '') as String,
      departmentName: (data['departmentName'] ?? '') as String,
      eventName: (data['eventName'] ?? '') as String,
      requesterName: (data['requesterName'] ?? '') as String,
      organization: (data['organization'] ?? '') as String,
      requesterRole: (data['requesterRole'] ?? '') as String,
      bookingDate: (data['bookingDate'] ?? '') as String,
      startTime: ((data['startTime'] ?? 0) as num).toInt(),
      endTime: ((data['endTime'] ?? 0) as num).toInt(),
      attendeeCount: ((data['attendeeCount'] ?? 0) as num).toInt(),
      includedEquipment:
          List<String>.from(data['includedEquipment'] ?? const <String>[]),
      status: (data['status'] ?? 'pending') as String,
      requiredSignatories:
          List<String>.from(data['requiredSignatories'] ?? const <String>[]),
      approvedBy: List<String>.from(data['approvedBy'] ?? const <String>[]),
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      userId: (data['userId'] ?? '') as String,
      rejectionReason: (data['rejectionReason'] ?? '') as String,
      rejectedBy: (data['rejectedBy'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'roomId': roomId,
      'roomName': roomName,
      'departmentName': departmentName,
      'eventName': eventName,
      'requesterName': requesterName,
      'organization': organization,
      'requesterRole': requesterRole,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
      'attendeeCount': attendeeCount,
      'includedEquipment': includedEquipment,
      'status': status,
      'requiredSignatories': requiredSignatories,
      'approvedBy': approvedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'rejectionReason': rejectionReason,
      'rejectedBy': rejectedBy,
    };
  }

  BookingModel copyWith({
    String? id,
    String? roomId,
    String? roomName,
    String? departmentName,
    int? startTime,
    int? endTime,
    String? status,
    List<String>? requiredSignatories,
    List<String>? approvedBy,
    DateTime? createdAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      departmentName: departmentName ?? this.departmentName,
      eventName: eventName,
      requesterName: requesterName,
      organization: organization,
      requesterRole: requesterRole,
      bookingDate: bookingDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      attendeeCount: attendeeCount,
      includedEquipment: includedEquipment,
      status: status ?? this.status,
      requiredSignatories: requiredSignatories ?? this.requiredSignatories,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt ?? this.createdAt,
      userId: userId,
      rejectionReason: rejectionReason,
      rejectedBy: rejectedBy,
    );
  }

  String get formattedTimeRange =>
      '${formatMinutes(startTime)} - ${formatMinutes(endTime)}';
}