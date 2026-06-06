// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'empty_classroom.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Building _$BuildingFromJson(Map<String, dynamic> json) =>
    Building(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$BuildingToJson(Building instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
};

SectionType _$SectionTypeFromJson(Map<String, dynamic> json) =>
    SectionType(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$SectionTypeToJson(SectionType instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

Node _$NodeFromJson(Map<String, dynamic> json) => Node(
  id: json['id'] as String,
  name: json['name'] as String,
  startTime: json['startTime'] as String,
  endTime: json['endTime'] as String,
);

Map<String, dynamic> _$NodeToJson(Node instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'startTime': instance.startTime,
  'endTime': instance.endTime,
};

ClassroomItem _$ClassroomItemFromJson(Map<String, dynamic> json) =>
    ClassroomItem(
      classroomId: (json['classroomId'] as num).toInt(),
      classroomName: json['classroomName'] as String,
      scheduleId: json['scheduleId'],
      noSeatRate: (json['noSeatRate'] as num?)?.toDouble(),
      seatCount: (json['seatCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ClassroomItemToJson(ClassroomItem instance) =>
    <String, dynamic>{
      'classroomId': instance.classroomId,
      'classroomName': instance.classroomName,
      'scheduleId': instance.scheduleId,
      'noSeatRate': instance.noSeatRate,
      'seatCount': instance.seatCount,
    };

FreeClassroomNode _$FreeClassroomNodeFromJson(Map<String, dynamic> json) =>
    FreeClassroomNode(
      nodeId: json['nodeId'] as String,
      nodeName: json['nodeName'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      classroomItems: (json['classroomItems'] as List<dynamic>)
          .map((e) => ClassroomItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$FreeClassroomNodeToJson(FreeClassroomNode instance) =>
    <String, dynamic>{
      'nodeId': instance.nodeId,
      'nodeName': instance.nodeName,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'classroomItems': instance.classroomItems,
    };

FreeClassroomTimeRange _$FreeClassroomTimeRangeFromJson(
  Map<String, dynamic> json,
) => FreeClassroomTimeRange(
  classroomId: (json['classroomId'] as num).toInt(),
  classroomName: json['classroomName'] as String,
  scheduleId: json['scheduleId'],
  noSeatRate: (json['noSeatRate'] as num?)?.toDouble(),
  seatCount: (json['seatCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$FreeClassroomTimeRangeToJson(
  FreeClassroomTimeRange instance,
) => <String, dynamic>{
  'classroomId': instance.classroomId,
  'classroomName': instance.classroomName,
  'scheduleId': instance.scheduleId,
  'noSeatRate': instance.noSeatRate,
  'seatCount': instance.seatCount,
};
