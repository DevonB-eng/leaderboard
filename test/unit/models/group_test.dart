import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/data/models/group.dart';

void main() {
  group('Group.fromJson', () {
    test('parses member ids and app votes', () {
      final group = Group.fromJson({
        'id': 'g1',
        'name': 'Roomies',
        'member_ids': ['u1', 'u2'],
        'app_votes': {
          'Instagram': ['u1'],
        },
      });

      expect(group.id, 'g1');
      expect(group.name, 'Roomies');
      expect(group.memberIds, ['u1', 'u2']);
      expect(group.appVotes, {
        'Instagram': ['u1'],
      });
    });

    test('defaults name when missing', () {
      final group = Group.fromJson({'id': 'g1'});
      expect(group.name, 'Unknown Group');
    });

    test('defaults member_ids to an empty list when null', () {
      final group = Group.fromJson({'id': 'g1', 'member_ids': null});
      expect(group.memberIds, isEmpty);
    });

    test('defaults app_votes to an empty map when null', () {
      final group = Group.fromJson({'id': 'g1'});
      expect(group.appVotes, isEmpty);
    });
  });

  group('GroupSummary.fromJson', () {
    test('derives member count from member_ids', () {
      final summary = GroupSummary.fromJson({
        'id': 'g1',
        'name': 'Roomies',
        'member_ids': ['u1', 'u2', 'u3'],
      });

      expect(summary.memberCount, 3);
    });

    test('member count is 0 when member_ids is missing', () {
      final summary = GroupSummary.fromJson({'id': 'g1', 'name': 'Roomies'});
      expect(summary.memberCount, 0);
    });
  });
}
