// Deliberate violation for test/architecture_test.dart. Never import from lib/.
// ignore_for_file: unused_element
void register() => getIt.registerFactory<int>(() => 42);
