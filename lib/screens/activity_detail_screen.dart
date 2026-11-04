import 'dart:math';

import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../services/activity_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/route_replay_map.dart';

class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activity, this.autoPlay = true});

  final Activity activity;
  final bool autoPlay;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus aktivitas?'),
        content: Text('"${activity.title}" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await activityRepo.remove(activity.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final splits = a.splits;
    return Scaffold(
      appBar: AppBar(
        title: Text(a.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SizedBox(height: 400, child: RouteReplayMap(route: a.route, autoPlay: autoPlay)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(a.type.icon, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${a.type.label}  •  ${formatDate(a.startTime)}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _statsGrid(a),
                if (splits.isNotEmpty) ...[
                  const SectionTitle('Split per km'),
                  _Splits(splits: splits),
                ],
                if (a.hasElevation) ...[
                  const SectionTitle('Elevasi'),
                  Container(
                    height: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: cardDecoration(),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _ElevationPainter(a.points.map((p) => p.alt).toList()),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(Activity a) {
    final isRide = a.type == SportType.ride;
    final items = <(String, String, String)>[
      ('Jarak', formatKm(a.distanceM), 'km'),
      ('Waktu', formatDuration(a.durationSec), ''),
      (
        isRide ? 'Kec. rata2' : 'Pace',
        isRide ? a.avgSpeedKmh.toStringAsFixed(1) : formatPace(a.paceSecPerKm),
        isRide ? 'km/j' : '/km',
      ),
      ('Kec. maks', a.maxSpeedKmh.toStringAsFixed(1), 'km/j'),
      ('Elevasi', a.elevationGain.toStringAsFixed(0), 'm'),
      ('Kalori', a.estimatedCalories.toString(), 'kkal'),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: items
          .map((e) => Container(
                padding: const EdgeInsets.all(12),
                decoration: cardDecoration(),
                child: StatTile(label: e.$1, value: e.$2, unit: e.$3, valueSize: 20),
              ))
          .toList(),
    );
  }
}

class _Splits extends StatelessWidget {
  const _Splits({required this.splits});
  final List<int> splits;

  @override
  Widget build(BuildContext context) {
    final fastest = max(splits.reduce(min), 1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < splits.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text('${i + 1}', style: const TextStyle(color: AppColors.muted)),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      formatPace(splits[i].toDouble()),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (fastest / max(splits[i], 1)).clamp(0.05, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: splits[i] == fastest ? rayvaGradient : null,
                          color: splits[i] == fastest ? null : AppColors.primary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(min);
    final hi = values.reduce(max);
    final range = max(hi - lo, 1.0);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - (values[i] - lo) / range * size.height * 0.9 - size.height * 0.05;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary.withValues(alpha: 0.5), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter old) => old.values != values;
}