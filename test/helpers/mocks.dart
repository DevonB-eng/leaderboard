import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:leaderboard/data/repositories/group_repository.dart';
import 'package:leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:leaderboard/data/repositories/screentime_repository.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

class MockLeaderboardRepository extends Mock implements LeaderboardRepository {}

class MockScreentimeRepository extends Mock implements ScreentimeRepository {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}
