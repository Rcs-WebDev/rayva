import 'dart:math';

import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../services/activity_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: activityRepo,
        builder: (context, _) {
          final items = activityRepo.items;
          final totalKm = items.fold<double>(0, (s, a) => s + a.distanceM) / 1000;
          final totalSec = items.fold<int>(0, (s, a) => s + a.durationSec);
          final totalElev = items.fold<double>(0, (s, a) => s + a.elevationGain);

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final weekStart = today.subtract(Duration(days: today.weekday - 1));
          final week = List<double>.filled(7, 0);
          for (final a in items) {
            final d = DateTime(a.startTime.year, a.startTime.month, a.startTime.day);
            final diff = d.difference(weekStart).inDays;
            if (diff >= 0 && diff < 7) week[diff] += a.distanceM / 1000;
          }
          final weekTotal = week.reduce((a, b) => a + b);
          final maxDay = max(week.reduce(max), 0.1);

          Activity? longest;
          Activity? fastest;
          for (final a in items) {
            if (longest == null || a.distanceM > longest.distanceM) longest = a;
            if (a.type == SportType.run &&
                a.distanceM >= 1000 &&
                (fastest == null || a.paceSecPerKm < fastest.paceSecPerKm)) {
              fastest = a;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Ringkasan minggu ini
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: rayvaGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MINGGU INI',
                        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text.rich(TextSpan(
                      text: weekTotal.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
                      children: const [TextSpan(text: ' km', style: TextStyle(fontSize: 18))],
                    )),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 110,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOutCubic,
                                  height: 6 + 74 * week[i] / maxDay,
                                  margin: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                        alpha: i == today.weekday - 1 ? 1 : 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(_days[i], style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Total Semua Waktu'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: [
                  _tile('Aktivitas', '${items.length}', ''),
                  _tile('Jarak', totalKm.toStringAsFixed(1), 'km'),
                  _tile('Waktu', formatDuration(totalSec), ''),
                  _tile('Elevasi', totalElev.toStringAsFixed(0), 'm'),
                ],
              ),
              const SectionTitle('Per Jenis'),
              for (final t in SportType.values) _typeRow(t, items),
              const SectionTitle('Rekor Pribadi'),
              _record(Icons.emoji_events, 'Jarak terjauh',
                  longest == null ? '-' : '${formatKm(longest.distanceM)} km'),
              _record(Icons.bolt, 'Pace lari tercepat (≥1 km)',
                  fastest == null ? '-' : '${formatPace(fastest.paceSecPerKm)} /km'),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(String label, String value, String unit) => Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: StatTile(label: label, value: value, unit: unit),
      );

  Widget _typeRow(SportType t, List<Activity> items) {
    final list = items.where((a) => a.type == t);
    final km = list.fold<double>(0, (s, a) => s + a.distanceM) / 1000;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Icon(t.icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${list.length}x  •  ${km.toStringAsFixed(1)} km',
              style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _record(IconData icon, String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent2),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

