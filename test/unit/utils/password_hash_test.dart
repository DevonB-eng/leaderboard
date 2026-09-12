import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/core/utils/password_hash.dart';

void main() {
  group('hashPassword', () {
    test('produces the known SHA-256 hex digest for a given input', () {
      // Precomputed: sha256("hunter2")
      expect(
        hashPassword('hunter2'),
        'f52fbd32b2b3b86ff88ef6c490628285f482af15ddcb29541f94bcf526a3f6c7',
      );
    });

    test('is deterministic for the same input', () {
      expect(hashPassword('correct-horse'), hashPassword('correct-horse'));
    });

    test('produces different hashes for different inputs', () {
      expect(hashPassword('password1'), isNot(hashPassword('password2')));
    });

    test('is case sensitive', () {
      expect(hashPassword('Password'), isNot(hashPassword('password')));
    });
  });
}
