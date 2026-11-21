class RoomModel {
  final String id;
  final String name;
  final String categoryType; // "Department" or "General"
  final String departmentName;
  final int capacity;
  final List<String> equipment;
  final List<String> requiredSignatories;

  const RoomModel({
    required this.id,
    required this.name,
    required this.categoryType,
    required this.departmentName,
    required this.capacity,
    required this.equipment,
    required this.requiredSignatories,
  });

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
    };
  }
}