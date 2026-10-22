import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_ai/core/models/global_memory.dart';
import 'package:yofardev_ai/features/chat/data/datasources/global_memory_datasource.dart';

void main() {
  late GlobalMemoryLocalDatasource datasource;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    datasource = GlobalMemoryLocalDatasource();
  });

  test('returns empty memory when nothing stored', () async {
    final GlobalMemory memory = await datasource.getMemory();
    expect(memory.isEmpty, isTrue);
  });

  test('round-trips items through storage', () async {
    final GlobalMemory memory = GlobalMemory(
      items: <GlobalMemoryItem>[
        GlobalMemoryItem(
          id: 'item-1',
          text: 'Works as a developer',
          updatedAt: DateTime(2026, 3, 12, 10, 30),
        ),
        GlobalMemoryItem(
          id: 'item-2',
          text: 'Lives in Paris',
          updatedAt: DateTime(2026, 4, 1, 8),
        ),
      ],
    );

    await datasource.saveMemory(memory);
    final GlobalMemory loaded = await datasource.getMemory();

    expect(loaded.items.length, 2);
    expect(loaded.items.first.id, 'item-1');
    expect(loaded.items.first.text, 'Works as a developer');
    expect(loaded.items.first.updatedAt, DateTime(2026, 3, 12, 10, 30));
    expect(loaded.items.last.text, 'Lives in Paris');
  });

  test('clear removes stored memory', () async {
    await datasource.saveMemory(
      GlobalMemory(
        items: <GlobalMemoryItem>[
          GlobalMemoryItem(
            id: 'item-1',
            text: 'fact',
            updatedAt: DateTime.now(),
          ),
        ],
      ),
    );

    await datasource.clear();

    expect((await datasource.getMemory()).isEmpty, isTrue);
  });

  test('tolerates missing fields in stored JSON', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'global_memory': jsonEncode(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'text': 'partial fact'},
        ],
      }),
    });

    final GlobalMemory memory = await GlobalMemoryLocalDatasource().getMemory();

    expect(memory.items.single.text, 'partial fact');
    expect(memory.items.single.id, '');
  });
}
