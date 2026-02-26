import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmanager/workmanager.dart';

import 'package:leaderboard/firebase_options.dart';
import 'package:leaderboard/utils/screen_time.dart';

/*
background_sync.dart - top level callback to allow for screentime data to be fetched and uploaded in the background on Android/ios
*/

// The unique name used to register and identify this task with workmanager.
// Must match exactly what you pass in main.dart when registering the task.
const kSyncTaskName = 'screentime_sync';

// This MUST be a top-level function — not a class method, not a closure.
// Workmanager spawns a background isolate and calls this directly.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Guard: only handle the task we registered
    if (taskName != kSyncTaskName) return Future.value(true);

    try {
      // Firebase must be re-initialized here — the background isolate
      // has no memory of the main app, so it starts completely fresh.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // If nobody is signed in there's nothing to upload — return cleanly.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return Future.value(true);

      // Same logic as the in-app refresh — fetch OS screentime and upload.
      final service = ScreenTimeService();
      final badAppUsage = await service.fetchBadAppUsage();
      await service.uploadScreentime(badAppUsage);

    } catch (e) {
      // Returning false tells workmanager the task failed and it should retry.
      // Returning true tells it the task is done regardless of outcome.
      // We return true here to avoid aggressive retries on persistent errors
      // like no internet connection — the next scheduled run will catch it.
      // debugPrint('Background sync error: $e');
      return Future.value(true);
    }

    return Future.value(true);
  });
}