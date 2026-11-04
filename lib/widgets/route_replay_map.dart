import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import '../utils/geo.dart';
import 'map_widgets.dart';

/// Peta dengan animasi replay rute: garis jalur "digambar" perlahan
/// mengikuti rute yang dijalani, lengkap dengan penanda kepala yang
/// bergerak, kontrol play/pause, slider, kecepatan, dan mode kamera ikut.
class RouteReplayMap extends StatefulWidget {
  const RouteReplayMap({super.key, required this.route, this.autoPlay = true});

  final List<LatLng> route;
  final bool autoPlay;

  @override
  State<RouteReplayMap> createState() => _RouteReplayMapState();
}

class _RouteReplayMapState extends State<RouteReplayMap>
    with SingleTickerProviderStateMixin {
  late final List<double> _cum = cumulativeDistances(widget.route);
  late final AnimationController _ctrl;
  final _map = MapController();
  int _speed = 1;
  bool _follow = false;
  bool _mapReady = false;

  double get _total => _cum.isEmpty ? 0 : _cum.last;

  /// ~2.5 detik per km pada kecepatan 1x (min 4 dtk, maks 20 dtk).
  int get _baseMs => (_total / 1000 * 2500).clamp(4000, 20000).round();

  CameraFit get _fit => CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(widget.route),
        padding: const EdgeInsets.fromLTRB(40, 60, 40, 100),
        maxZoom: 17,
      );

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: _baseMs))
      ..addListener(_onTick);
    if (widget.autoPlay && widget.route.length >= 2) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _ctrl.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  LatLng get _head => positionAt(widget.route, _cum, _ctrl.value * _total).$1;

  void _onTick() {
    if (_follow && _mapReady) _map.move(_head, _map.camera.zoom);
  }

  void _togglePlay() {
    if (_ctrl.isAnimating) {
      _ctrl.stop();
    } else if (_ctrl.value >= 1) {
      _ctrl.forward(from: 0);
    } else {
      _ctrl.forward();
    }
    setState(() {});
  }

  void _cycleSpeed() {
    setState(() {
      _speed = switch (_speed) { 1 => 2, 2 => 4, 4 => 8, _ => 1 };
      _ctrl.duration = Duration(milliseconds: (_baseMs / _speed).round());
      if (_ctrl.isAnimating) _ctrl.forward(); // terapkan durasi baru
    });
  }

  void _toggleFollow() {
    setState(() => _follow = !_follow);
    if (!_mapReady) return;
    if (_follow) {
      _map.move(_head, 16.5);
    } else {
      _map.fitCamera(_fit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    if (route.length < 2) {
      return const ColoredBox(
        color: AppColors.card,
        child: Center(child: Text('Rute tidak tersedia')),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: _fit,
            onMapReady: () => _mapReady = true,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            rayvaTileLayer(),
            // Jalur penuh (samar) sebagai "bayangan".
            PolylineLayer(polylines: [
              Polyline(
                points: route,
                strokeWidth: 4,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ]),
            // Jalur yang sedang dianimasikan.
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final (head, idx) = positionAt(route, _cum, _ctrl.value * _total);
                final drawn = [...route.sublist(0, idx + 1), head];
                return PolylineLayer(polylines: [
                  Polyline(
                    points: drawn,
                    strokeWidth: 6,
                    gradientColors: routeGradientColors,
                    borderStrokeWidth: 4,
                    borderColor: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ]);
              },
            ),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final done = _ctrl.value >= 1;
                return MarkerLayer(markers: [
                  startMarker(route.first),
                  if (done) finishMarker(route.last),
                  if (!done)
                    Marker(
                      point: _head,
                      width: 34,
                      height: 34,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: rayvaGradient,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: AppColors.accent, blurRadius: 16, spreadRadius: 2),
                          ],
                        ),
                      ),
                    ),
                ]);
              },
            ),
            rayvaAttribution(),
          ],
        ),
        // Jarak tempuh berjalan.
        Positioned(
          left: 12,
          top: 12,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(_ctrl.value * _total / 1000).toStringAsFixed(2)} / ${(_total / 1000).toStringAsFixed(2)} km',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        // Kontrol replay.
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final icon = _ctrl.isAnimating
                  ? Icons.pause
                  : (_ctrl.value >= 1 ? Icons.replay : Icons.play_arrow);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  children: [
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                      icon: Icon(icon, color: Colors.white),
                      onPressed: _togglePlay,
                    ),
                    Expanded(
                      child: Slider(
                        value: _ctrl.value.clamp(0.0, 1.0),
                        onChanged: (v) {
                          _ctrl.stop();
                          _ctrl.value = v;
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: _cycleSpeed,
                      child: Text(
                        '${_speed}x',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kamera ikuti jalur',
                      icon: Icon(
                        _follow ? Icons.videocam : Icons.videocam_outlined,
                        color: _follow ? AppColors.primary : Colors.white,
                      ),
                      onPressed: _toggleFollow,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}