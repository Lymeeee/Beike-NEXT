import 'package:flutter_test/flutter_test.dart';
import 'package:beike_next/services/empty_classroom/service.dart';
import 'package:beike_next/types/empty_classroom.dart';

void main() {
  test('EmptyClassroomService - all buildings load correctly', () async {
    final service = EmptyClassroomService();

    // Init service
    await service.init();
    expect(service.isInitialized, isTrue);
    expect(service.buildings, isNotEmpty);
    expect(service.freeRoomsByNode, isNotEmpty,
        reason: 'Initial data should load after init()');

    // Save initial data count
    final initialCount = service.freeRoomsByNode.length;
    print('Initial building: ${service.buildings.firstWhere((b) => b.id == service.selectedBuildingId).name}');
    print('Initial rooms: $initialCount nodes');

    // Test each building
    for (final building in service.buildings) {
      print('\n--- Switching to ${building.name} (${building.id}) ---');
      await service.selectBuilding(building.id);
      expect(service.selectedBuildingId, equals(building.id));
      expect(service.error, isNull,
          reason: 'No error when loading ${building.name}');
      expect(service.freeRoomsByNode, isNotEmpty,
          reason: '${building.name} should have rooms');

      final totalRooms = service.freeRoomsByNode
          .fold<int>(0, (sum, node) => sum + node.classroomItems.length);
      print('${building.name}: ${service.freeRoomsByNode.length} nodes, $totalRooms rooms');
    }

    // Switch back to first building
    await service.selectBuilding(service.buildings.first.id);
    expect(service.freeRoomsByNode, isNotEmpty);

    // Test time-based search
    await service.selectTimeFilter(0); // 全天
    expect(service.timeFilterId, equals(0));
    expect(service.freeRoomsByTime, isNotEmpty,
        reason: 'Time-based search should return results');

    // Switch back to node-based
    await service.selectTimeFilter(4);
    expect(service.freeRoomsByNode, isNotEmpty);

    print('\n=== All tests passed ===');

    service.dispose();
  });
}
