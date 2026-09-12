import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/data/models/user_profile.dart';

void main() {
  group('UserProfile.fromJson', () {
    test('parses a fully populated row', () {
      final profile = UserProfile.fromJson({
        'id': 'u1',
        'username': 'devon',
        'email': 'devon@example.com',
        'group_id': 'g1',
      });

      expect(profile.id, 'u1');
      expect(profile.username, 'devon');
      expect(profile.email, 'devon@example.com');
      expect(profile.groupId, 'g1');
    });

    test('defaults username to Unknown when missing', () {
      final profile = UserProfile.fromJson({'id': 'u1'});
      expect(profile.username, 'Unknown');
    });

    test('leaves email and groupId null when absent', () {
      final profile = UserProfile.fromJson({'id': 'u1', 'username': 'devon'});
      expect(profile.email, isNull);
      expect(profile.groupId, isNull);
    });
  });
}
