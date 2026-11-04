import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity.dart';
import '../utils/geo.dart';

/// Penyimpanan lokal aktivitas (shared_preferences, JSON).
class ActivityRepository extends ChangeNotifier {
  static const _key = 'rayva_activities_v1';
  final List<Activity> _items = [];

  List<Activity> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _items.clear();
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _items.addAll(list.map((e) => Activity.fromJson(Map<String, dynamic>.from(e as Map))));
        _items.sort((a, b) => b.startTime.compareTo(a.startTime));
      } catch (e) {
        debugPrint('Rayva: gagal memuat aktivitas: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((a) => a.toJson()).toList()));
  }

  Future<void> add(Activity a) async {
    _items.insert(0, a);
    _items.sort((a, b) => b.startTime.compareTo(a.startTime));
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((a) => a.id == id);
    notifyListeners();
    await _persist();
  }

  /// Membuat aktivitas contoh (rute melingkar di sekitar Monas, Jakarta)
  /// supaya animasi replay bisa dicoba tanpa harus keluar rumah.
  Future<Activity> addDemo() async {
    final a = _createDemoActivity();
    await add(a);
    return a;
  }

  Activity _createDemoActivity() {
    final rnd = Random();
    const center = LatLng(-6.1754, 106.8272);
    const n = 420;
    final phase = rnd.nextDouble() * 2 * pi;
    final base = 550 + rnd.nextDouble() * 300;
    final start = DateTime.now().subtract(Duration(minutes: 60 + rnd.nextInt(600)));
    var t = start;
    double dist = 0;
    LatLng? prev;
    final pts = <TrackPoint>[];

    for (var i = 0; i <= n; i++) {
      final a = i / n * 2 * pi;
      final r = base + 200 * sin(3 * a + phase) + 80 * cos(5 * a);
      final dLat = (r * cos(a)) / 111320;
      final dLng = (r * sin(a)) / (111320 * cos(center.latitude * pi / 180));
      final p = LatLng(center.latitude + dLat, center.longitude + dLng);
      final speed = 2.9 + 0.5 * sin(a * 4 + phase) + rnd.nextDouble() * 0.3;
      if (prev != null) {
        final d = metersBetween(prev, p);
        dist += d;
        t = t.add(Duration(milliseconds: (d / speed * 1000).round()));
      }
      pts.add(TrackPoint(
        lat: p.latitude,
        lng: p.longitude,
        alt: 12 + 8 * sin(a * 2 + phase) + rnd.nextDouble() * 0.5,
        speed: speed,
        time: t,
      ));
      prev = p;
    }

    return Activity(
      id: start.millisecondsSinceEpoch.toString(),
      title: '${Activity.defaultTitle(SportType.run, start)} di Monas (Demo)',
      type: SportType.run,
      startTime: start,
      durationSec: t.difference(start).inSeconds,
      distanceM: dist,
      points: pts,
    );
  }
}

final activityRepo = ActivityRepository();

