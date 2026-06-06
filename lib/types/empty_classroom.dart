import 'package:json_annotation/json_annotation.dart';

part 'empty_classroom.g.dart';

@JsonSerializable()
class Building {
  final String id;
  final String name;

  const Building({required this.id, required this.name});

  factory Building.fromJson(Map<String, dynamic> json) =>
      _$BuildingFromJson(json);

  Map<String, dynamic> toJson() => _$BuildingToJson(this);
}

@JsonSerializable()
class SectionType {
  final String id;
  final String name;

  const SectionType({required this.id, required this.name});

  factory SectionType.fromJson(Map<String, dynamic> json) =>
      _$SectionTypeFromJson(json);

  Map<String, dynamic> toJson() => _$SectionTypeToJson(this);
}

@JsonSerializable()
class Node {
  final String id;
  final String name;
  final String startTime;
  final String endTime;

  const Node({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);

  Map<String, dynamic> toJson() => _$NodeToJson(this);
}

@JsonSerializable()
class ClassroomItem {
  final int classroomId;
  final String classroomName;
  final dynamic scheduleId;
  final double? noSeatRate;
  final int? seatCount;

  const ClassroomItem({
    required this.classroomId,
    required this.classroomName,
    this.scheduleId,
    this.noSeatRate,
    required this.seatCount,
  });

  factory ClassroomItem.fromJson(Map<String, dynamic> json) =>
      _$ClassroomItemFromJson(json);

  Map<String, dynamic> toJson() => _$ClassroomItemToJson(this);
}

/// Response from freeClassRooms (search by node)
@JsonSerializable()
class FreeClassroomNode {
  final String nodeId;
  final String nodeName;
  final String startTime;
  final String endTime;
  final List<ClassroomItem> classroomItems;

  const FreeClassroomNode({
    required this.nodeId,
    required this.nodeName,
    required this.startTime,
    required this.endTime,
    required this.classroomItems,
  });

  factory FreeClassroomNode.fromJson(Map<String, dynamic> json) =>
      _$FreeClassroomNodeFromJson(json);

  Map<String, dynamic> toJson() => _$FreeClassroomNodeToJson(this);
}

/// Response from freeJoinClassRooms (search by time range)
@JsonSerializable()
class FreeClassroomTimeRange {
  final int classroomId;
  final String classroomName;
  final dynamic scheduleId;
  final double? noSeatRate;
  final int? seatCount;

  const FreeClassroomTimeRange({
    required this.classroomId,
    required this.classroomName,
    this.scheduleId,
    this.noSeatRate,
    required this.seatCount,
  });

  factory FreeClassroomTimeRange.fromJson(Map<String, dynamic> json) =>
      _$FreeClassroomTimeRangeFromJson(json);

  Map<String, dynamic> toJson() => _$FreeClassroomTimeRangeToJson(this);
}
