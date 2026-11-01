import 'package:integration_test/integration_test_driver.dart';

/// Driver for `flutter drive` runs of the `integration_test/` files that
/// report data (see `integration_test/frame_cost_test.dart`). The timeout
/// covers the longest run, the 30 min battery phase (M11 ruling 16).
Future<void> main() => integrationDriver(timeout: const Duration(minutes: 90));
