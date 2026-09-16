import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'package:leaderboard/app.dart';
import 'package:leaderboard/core/config/supabase_config.dart';
import 'package:leaderboard/services/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await Workmanager().initialize(callbackDispatcher);

  // `update` rather than `replace`: replace cancels and re-enqueues the work on
  // every launch, restarting its interval each time, so a frequently opened app
  // could keep pushing the next background sync out of reach. update keeps the
  // existing schedule running while still applying any change made here.
  await Workmanager().registerPeriodicTask(
    kSyncTaskName,
    kSyncTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(const ProviderScope(child: AppUsageApp()));
}
