import 'package:flutter_test/flutter_test.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/data/models/{{FEATURE_SNAKE}}_dto.dart';
import 'package:{{PROJECT_NAME}}/features/{{FEATURE_SNAKE}}/domain/models/{{FEATURE_SNAKE}}.dart';

/// DTO tests pin the transport contract: JSON round-trips and the
/// DTO→domain conversion stay correct when the schema evolves.
void main() {
  group('{{FEATURE_PASCAL}}Dto', () {
    const Map<String, dynamic> json = <String, dynamic>{
      'id': '1',
      'name': 'Test',
    };

    test('deserializes from JSON', () {
      final {{FEATURE_PASCAL}}Dto dto = {{FEATURE_PASCAL}}Dto.fromJson(json);
      expect(dto.id, '1');
      expect(dto.name, 'Test');
    });

    test('serializes to JSON (round trip)', () {
      final {{FEATURE_PASCAL}}Dto dto = {{FEATURE_PASCAL}}Dto.fromJson(json);
      expect(dto.toJson(), json);
    });

    test('toDomain maps every field', () {
      const {{FEATURE_PASCAL}}Dto dto = {{FEATURE_PASCAL}}Dto(id: '1', name: 'Test');
      final {{FEATURE_PASCAL}} domain = dto.toDomain();
      expect(domain.id, '1');
      expect(domain.name, 'Test');
    });
  });
}
