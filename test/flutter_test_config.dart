import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Avoid network font fetches (and the flakiness/timeouts they cause) in tests.
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
