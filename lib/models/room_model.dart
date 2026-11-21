class RoomModel {
  final String id;
  final String name;
  final String categoryType; // "Department" (college / library) or "General" (standalone venue)
  final String departmentName;
  final int capacity;
  final List<String> equipment;
  final List<String> requiredSignatories;

  // Fields used by the UniSpace UI (all optional so older code still compiles).
  final String code; // CEA, CCI, COE, CIT, CGBE, LIB, MEC, GRAND
  final String kind; // Lecture room, Laboratory, Studio, Gym, ...
  final String blurb; // short description (standalone venues)
  final int sortOrder; // keeps rooms in the order the UI expects

  const RoomModel({
    required this.id,
    required this.name,
    required this.categoryType,
    required this.departmentName,
    required this.capacity,
    required this.equipment,
    required this.requiredSignatories,
    this.code = '',
    this.kind = 'Room',
    this.blurb = '',
    this.sortOrder = 0,
  });

  /// Standalone venues (gym, grandstand) are booked directly, not via a college.
  bool get isStandalone => categoryType == 'General';

  factory RoomModel.fromMap(Map<String, dynamic> data, String id) {
    return RoomModel(
      id: id,
      name: (data['name'] ?? '') as String,
      categoryType: (data['categoryType'] ?? 'General') as String,
      departmentName: (data['departmentName'] ?? 'General Facilities') as String,
      capacity: ((data['capacity'] ?? 0) as num).toInt(),
      equipment: List<String>.from(data['equipment'] ?? const <String>[]),
      requiredSignatories:
          List<String>.from(data['requiredSignatories'] ?? const <String>[]),
      code: (data['code'] ?? '') as String,
      kind: (data['kind'] ?? 'Room') as String,
      blurb: (data['blurb'] ?? '') as String,
      sortOrder: ((data['sortOrder'] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'categoryType': categoryType,
      'departmentName': departmentName,
      'capacity': capacity,
      'equipment': equipment,
      'requiredSignatories': requiredSignatories,
      'code': code,
      'kind': kind,
      'blurb': blurb,
      'sortOrder': sortOrder,
    };
  }
}
