import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../services/activity_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/map_widgets.dart';
import 'activity_detail_screen.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key, required this.onStartRecording});
  final VoidCallback onStartRecording;

  Future<void> _addDemo(BuildContext context) async {
    final a = await activityRepo.addDemo();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: a)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const RayvaLogo(size: 26),
        actions: [
          IconButton(
            tooltip: 'Tambah aktivitas demo',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _addDemo(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: activityRepo,
        builder: (context, _) {
          final items = activityRepo.items;
          if (items.isEmpty) return _empty(context);
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: items.length,
            itemBuilder: (context, i) => ActivityCard(activity: items[i]),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (r) => rayvaGradient.createShader(r),
              child: const Icon(Icons.route, size: 96, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text('Belum ada aktivitas',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Mulai rekam lari, jalan, atau gowes kamu. Atau coba aktivitas demo untuk melihat animasi rute.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Mulai Rekam',
              icon: Icons.play_arrow_rounded,
              onPressed: onStartRecording,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _addDemo(context),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Coba Aktivitas Demo'),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final isRide = a.type == SportType.ride;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(activity: a),
          )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: rayvaGradient,
                      ),
                      child: Icon(a.type.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            formatShortDate(a.startTime),
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: StatTile(label: 'Jarak', value: formatKm(a.distanceM), unit: 'km')),
                    Expanded(
                      child: StatTile(
                        label: isRide ? 'Kec. rata2' : 'Pace',
                        value: isRide ? a.avgSpeedKmh.toStringAsFixed(1) : formatPace(a.paceSecPerKm),
                        unit: isRide ? 'km/j' : '/km',
                      ),
                    ),
                    Expanded(child: StatTile(label: 'Waktu', value: formatDuration(a.durationSec))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (a.route.length >= 2) RoutePreview(route: a.route),
            ],
          ),
        ),
      ),
    );
  }
}

