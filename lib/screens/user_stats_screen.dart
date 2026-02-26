
import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';

import 'package:leaderboard/utils/screen_time.dart';

/*
user_stats_screen.dart - displays user screentime data
- graph with weekly/monthly data
- list of top bad apps 
*/

class UserStatsPage extends StatefulWidget {
  const UserStatsPage({super.key});

  @override
  UserStatsPageState createState() => UserStatsPageState();
}

class UserStatsPageState extends State<UserStatsPage> {
  final _service = ScreenTimeService();
  List<AppUsageInfo> _badAppInfos = [];
  bool _isLoading = false;

  void _refresh() async {
    setState(() => _isLoading = true);
    try {
      final badAppUsage = await _service.fetchBadAppUsage();
      setState(() => _badAppInfos = badAppUsage);
      await _service.uploadScreentime(badAppUsage);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting usage stats: $exception')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _service.groupForDisplay(_badAppInfos);
    final totalMinutes = grouped.fold<int>(0, (sum, e) => sum + e.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Screentime'),
        backgroundColor: Colors.green,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _badAppInfos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.phone_android, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No data yet. Tap refresh to load screentime.'),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    ExpansionTile(
                      leading: const Icon(Icons.warning, color: Colors.red, size: 20),
                      title: Text(
                        'Total "Bad" Screentime: $totalMinutes minutes',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      initiallyExpanded: false,
                      children: grouped.map((e) => _buildAppTile(e.key, e.value)).toList(),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _refresh,
        backgroundColor: _isLoading ? Colors.grey : Colors.green,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  Widget _buildAppTile(String name, int minutes) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: const Icon(Icons.phone_android, color: Colors.red),
      title: Text(name),
      subtitle: Text(_formatDuration(Duration(minutes: minutes))),
      trailing: Text(
        '$minutes min',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}