import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'package:leaderboard/core/config/supabase_config.dart';
import 'package:leaderboard/data/repositories/screentime_repository.dart';

const kSyncTaskName = 'screentime_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != kSyncTaskName) return Future.value(true);

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return Future.value(true);

      await ScreentimeRepository().syncAndUpload();
    } catch (_) {
      return Future.value(true);
    }

    return Future.value(true);
  });
}
