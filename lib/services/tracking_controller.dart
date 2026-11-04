import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/activity.dart';

enum TrackingState { idle, recording, paused }

/// Mengelola perekaman GPS: izin, stream lokasi, jarak, waktu, jeda.
class TrackingController extends ChangeNotifier {
  TrackingState state = TrackingState.idle;
  SportType type = SportType.run;
  final List<TrackPoint> points = [];
  double distanceM = 0;
  Position? current;
  String? error;
  bool ready = false;

  DateTime? _start;
  Duration _accum = Duration.zero;
  DateTime? _segStart;
  bool _gapNext = false;
  StreamSubscription<Position>? _sub;
  bool _backgroundMode = false;
  Timer? _timer;

  static const _maxAccuracyM = 30.0;
  static const _minStepM = 2.0;
  static const _maxSpeedMs = 60.0;

  List<LatLng> get route => points.map((e) => e.latLng).toList();

  int get elapsedSec => (_accum +
          (_segStart == null ? Duration.zero : DateTime.now().difference(_segStart!)))
      .inSeconds;

  double get currentSpeedKmh {
    final s = current?.speed ?? 0;
    return (s < 0 ? 0 : s) * 3.6;
  }

  double get avgPaceSecPerKm =>
      distanceM < 10 ? 0 : elapsedSec / (distanceM / 1000);

  double get avgSpeedKmh => elapsedSec == 0 ? 0 : distanceM / elapsedSec * 3.6;

  void setType(SportType t) {
    if (state != TrackingState.idle) return;
    type = t;
    notifyListeners();
  }

  Future<void> init() async {
    error = await _checkPermission();
    ready = error == null;
    notifyListeners();
    if (!ready) return;
    try {
      current ??= await Geolocator.getLastKnownPosition();
      notifyListeners();
    } catch (_) {}
    _listen(background: state != TrackingState.idle);
  }

  Future<String?> _checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'GPS tidak aktif. Aktifkan layanan lokasi di HP kamu.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return 'Izin lokasi ditolak. Rayva butuh lokasi untuk merekam rute.';
    }
    if (perm == LocationPermission.deniedForever) {
      return 'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan.';
    }
    return null;
  }

  LocationSettings _settings(bool background) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
        intervalDuration: const Duration(seconds: 1),
        // Foreground service agar tetap merekam saat layar mati.
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Rayva sedang merekam',
                notificationText: 'Rute aktivitasmu sedang dilacak',
                enableWakeLock: true,
              )
            : null,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 2,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: background,
        allowBackgroundLocationUpdates: background,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 2);
  }

  void _listen({required bool background}) {
    if (_sub != null && _backgroundMode == background) return;
    _sub?.cancel();
    _backgroundMode = background;
    _sub = Geolocator.getPositionStream(locationSettings: _settings(background)).listen(
      _onPosition,
      onError: (Object e) {
        error = 'Gagal membaca lokasi: $e';
        notifyListeners();
      },
    );
  }

  void _onPosition(Position p) {
    current = p;
    error = null;
    if (state == TrackingState.recording) _addPoint(p);
    notifyListeners();
  }

  void _addPoint(Position p) {
    if (p.accuracy > _maxAccuracyM) return;
    if (points.isNotEmpty) {
      final last = points.last;
      final d = Geolocator.distanceBetween(last.lat, last.lng, p.latitude, p.longitude);
      if (!_gapNext) {
        if (d < _minStepM) return; // GPS jitter
        final dt = p.timestamp.difference(last.time).inMilliseconds / 1000;
        if (dt > 0 && d / dt > _maxSpeedMs) return; // lompatan tidak wajar
        distanceM += d;
      }
    }
    _gapNext = false;
    points.add(TrackPoint(
      lat: p.latitude,
      lng: p.longitude,
      alt: p.altitude,
      speed: p.speed < 0 ? 0 : p.speed,
      time: p.timestamp,
    ));
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  Future<void> start() async {
    if (!ready) {
      await init();
      if (!ready) return;
    }
    points.clear();
    distanceM = 0;
    _accum = Duration.zero;
    _start = DateTime.now();
    _segStart = _start;
    _gapNext = false;
    state = TrackingState.recording;
    if (current != null) _addPoint(current!);
    _listen(background: true);
    _startTimer();
    notifyListeners();
  }

  void pause() {
    if (state != TrackingState.recording) return;
    _accum += DateTime.now().difference(_segStart!);
    _segStart = null;
    state = TrackingState.paused;
    _timer?.cancel();
    notifyListeners();
  }

  void resume() {
    if (state != TrackingState.paused) return;
    _segStart = DateTime.now();
    _gapNext = true; // jarak selama jeda tidak dihitung
    state = TrackingState.recording;
    _startTimer();
    notifyListeners();
  }

  /// Menyelesaikan rekaman. Mengembalikan null jika rute terlalu pendek.
  Activity? finish(String title) {
    pause();
    Activity? activity;
    if (points.length >= 2 && _start != null) {
      activity = Activity(
        id: _start!.millisecondsSinceEpoch.toString(),
        title: title,
        type: type,
        startTime: _start!,
        durationSec: elapsedSec,
        distanceM: distanceM,
        points: List.of(points),
      );
    }
    _reset();
    return activity;
  }

  void discard() => _reset();

  void _reset() {
    _timer?.cancel();
    state = TrackingState.idle;
    points.clear();
    distanceM = 0;
    _accum = Duration.zero;
    _segStart = null;
    _start = null;
    if (ready) _listen(background: false);
    notifyListeners();
  }
}

/// Instance global agar rekaman tetap berjalan saat pindah tab.
final tracker = TrackingController();

