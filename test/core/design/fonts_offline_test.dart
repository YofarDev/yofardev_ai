import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool previousAllowRuntimeFetching;

  setUp(() {
    previousAllowRuntimeFetching = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    GoogleFonts.config.allowRuntimeFetching = previousAllowRuntimeFetching;
  });

  test('Outfit and Plus Jakarta Sans resolve from bundled assets', () async {
    final List<TextStyle> styles = <TextStyle>[
      GoogleFonts.outfit(fontWeight: FontWeight.w400),
      GoogleFonts.outfit(fontWeight: FontWeight.w500),
      GoogleFonts.outfit(fontWeight: FontWeight.w600),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
    ];

    expect(styles, hasLength(5));
    await expectLater(GoogleFonts.pendingFonts(), completes);
  });
}
