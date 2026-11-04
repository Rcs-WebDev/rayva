import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../utils/geo.dart';

/// Jenis olahraga. (Dinamai SportType agar tidak bentrok dengan
/// `ActivityType` milik package geolocator.)
enum SportType {
  run('Lari', Icons.directions_run, 1.0),
  walk('Jalan', Icons.directions_walk, 0.75),
  ride('Sepeda', Icons.directions_bike, 0.3);

  const SportType(this.label, this.icon, this.kcalPerKgKm);
  final String label;
  final IconData icon;
  final double kcalPerKgKm;
}

class TrackPoint {
  const TrackPoint({
    required this.lat,
    required this.lng,
    required this.time,
    this.alt = 0,
    this.speed = 0,
  });

  final double lat;
  final double lng;
  final double alt;

  /// meter / detik
  final double speed;
  final DateTime time;

  LatLng get latLng => LatLng(lat, lng);

  Map<String, dynamic> toJson() => {
        'la': lat,
        'lo': lng,
        'a': alt,
        's': speed,
        't': time.millisecondsSinceEpoch,
      };

  factory TrackPoint.fromJson(Map<String, dynamic> j) => TrackPoint(
        lat: (j['la'] as num).toDouble(),
        lng: (j['lo'] as num).toDouble(),
        alt: (j['a'] as num?)?.toDouble() ?? 0,
        speed: (j['s'] as num?)?.toDouble() ?? 0,
        time: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
      );
}

class Activity {
  Activity({
    required this.id,
    required this.title,
    required this.type,
    required this.startTime,
    required this.durationSec,
    required this.distanceM,
    required this.points,
  });

  final String id;
  final String title;
  final SportType type;
  final DateTime startTime;

  /// Waktu bergerak (tanpa jeda), detik.
  final int durationSec;
  final double distanceM;
  final List<TrackPoint> points;

  late final List<LatLng> route = points.map((p) => p.latLng).toList();

  double get avgSpeedKmh => durationSec == 0 ? 0 : distanceM / durationSec * 3.6;

  double get paceSecPerKm =>
      distanceM < 10 ? 0 : durationSec / (distanceM / 1000);

  double get maxSpeedKmh =>
      points.fold<double>(0, (m, p) => max(m, p.speed)) * 3.6;

  double get elevationGain {
    double gain = 0;
    for (var i = 1; i < points.length; i++) {
      final d = points[i].alt - points[i - 1].alt;
      if (d > 0.3) gain += d;
    }
    return gain;
  }

  bool get hasElevation {
    if (points.length < 2) return false;
    final alts = points.map((p) => p.alt);
    return alts.reduce(max) - alts.reduce(min) > 1;
  }

  /// Perkiraan kalori untuk berat 65 kg.
  int get estimatedCalories => (distanceM / 1000 * 65 * type.kcalPerKgKm).round();

  /// Durasi (detik) setiap 1 km.
  List<int> get splits {
    final res = <int>[];
    if (points.length < 2) return res;
    final cum = cumulativeDistances(route);
    var nextKm = 1000.0;
    var lastTime = points.first.time;
    for (var i = 1; i < points.length; i++) {
      while (cum[i] >= nextKm) {
        res.add(points[i].time.difference(lastTime).inSeconds);
        lastTime = points[i].time;
        nextKm += 1000;
      }
    }
    return res;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'start': startTime.millisecondsSinceEpoch,
        'dur': durationSec,
        'dist': distanceM,
        'pts': points.map((p) => p.toJson()).toList(),
      };

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
        id: j['id'] as String,
        title: j['title'] as String,
        type: SportType.values.byName(j['type'] as String),
        startTime: DateTime.fromMillisecondsSinceEpoch(j['start'] as int),
        durationSec: j['dur'] as int,
        distanceM: (j['dist'] as num).toDouble(),
        points: (j['pts'] as List)
            .map((e) => TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static String defaultTitle(SportType type, DateTime t) {
    final h = t.hour;
    final part = h < 11
        ? 'Pagi'
        : h < 15
            ? 'Siang'
            : h < 18
                ? 'Sore'
                : 'Malam';
    return '${type.label} $part';
  }
}

