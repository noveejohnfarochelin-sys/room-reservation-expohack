/// One recurring weekly class block (stored in the `class_schedules` collection).
class ClassScheduleModel {
  final String id;
  final String collegeCode;
  final String roomId;
  final String roomName;
  final int dayOfWeek; // 1 = Monday ... 7 = Sunday
  final int startMin; // minutes from midnight
  final int endMin;
  final String courseCode;
  final String section;
  final String instructor;

  const ClassScheduleModel({
    required this.id,
    required this.collegeCode,
    required this.roomId,
    required this.roomName,
    required this.dayOfWeek,
    required this.startMin,
    required this.endMin,
    required this.courseCode,
    this.section = '',
    this.instructor = '',
  });

  factory ClassScheduleModel.fromMap(Map<String, dynamic> data, String id) {
    return ClassScheduleModel(
      id: id,
      collegeCode: (data['college_code'] ?? '').toString(),
      roomId: (data['room_id'] ?? '').toString(),
      roomName: (data['room_name'] ?? '').toString(),
      dayOfWeek: ((data['day_of_week'] ?? 1) as num).toInt(),
      startMin: ((data['start_min'] ?? 0) as num).toInt(),
      endMin: ((data['end_min'] ?? 0) as num).toInt(),
      courseCode: (data['course_code'] ?? '').toString(),
      section: (data['section'] ?? '').toString(),
      instructor: (data['instructor'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'college_code': collegeCode,
        'room_id': roomId,
        'room_name': roomName,
        'day_of_week': dayOfWeek,
        'start_min': startMin,
        'end_min': endMin,
        'course_code': courseCode,
        'section': section,
        'instructor': instructor,
      };

  ClassScheduleModel withId(String newId) => ClassScheduleModel(
        id: newId,
        collegeCode: collegeCode,
        roomId: roomId,
        roomName: roomName,
        dayOfWeek: dayOfWeek,
        startMin: startMin,
        endMin: endMin,
        courseCode: courseCode,
        section: section,
        instructor: instructor,
      );

  /// "Class · CS 101 (BSCS 1A)"
  String get label =>
      section.isEmpty ? 'Class · $courseCode' : 'Class · $courseCode ($section)';

  /// "Blocked by scheduled class: CS 101 (BSCS 1A)"
  String get blockReason => section.isEmpty
      ? 'Blocked by scheduled class: $courseCode'
      : 'Blocked by scheduled class: $courseCode ($section)';

  String get key => '$roomId|$dayOfWeek|$startMin|$endMin|$courseCode|$section';
}