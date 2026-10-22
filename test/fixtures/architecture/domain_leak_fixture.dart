// Deliberate architecture violation used by test/architecture_test.dart.
// NOT real app code — never import it from lib/.
// ignore_for_file: unused_import
import '../../../lib/features/sound/data/datasources/tts_datasource.dart';

class DomainLeakFixture {
  final TtsDatasource datasource = TtsDatasource();
}
