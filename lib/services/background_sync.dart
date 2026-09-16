import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'package:leaderboard/core/config/supabase_config.dart';
import 'package:leaderboard/data/repositories/screentime_repository.dart';

const kSyncTaskName = 'screentime_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != kSyncTaskName) return Future.value(true);

    // Every outcome is logged: this runs with no UI, so logcat (tag "flutter")
    // is the only place a sync that skipped or failed shows up. The task still
    // reports success either way, since the next periodic run is the retry.
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _log('skipped: not signed in');
        return Future.value(true);
      }

      final uploaded = await ScreentimeRepository().syncAndUpload();
      _log(
        uploaded
            ? 'uploaded'
            : 'skipped: usage access not granted, or usage could not be read',
      );
    } catch (error, stackTrace) {
      _log('failed: $error\n$stackTrace');
    }

    return Future.value(true);
  });
}

void _log(String message) => debugPrint('[$kSyncTaskName] $message');
