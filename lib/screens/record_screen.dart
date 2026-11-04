import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/activity.dart';
import '../services/activity_repository.dart';
import '../services/tracking_controller.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/map_widgets.dart';
import '../widgets/pulse_dot.dart';
import 'activity_detail_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with SingleTickerProviderStateMixin {
  static const _fallback = LatLng(-6.1754, 106.8272); // Jakarta
  final _map = MapController();
  late final AnimationController _pulse;
  bool _follow = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    tracker.addListener(_onTrackerUpdate);
    tracker.init();
  }

  @override
  void dispose() {
    tracker.removeListener(_onTrackerUpdate);
    _pulse.dispose();
    super.dispose();
  }

  void _onTrackerUpdate() {
    if (!_follow || !_mapReady) return;
    final c = tracker.current;
    if (c == null) return;
    final zoom = _map.camera.zoom < 14 ? 17.0 : _map.camera.zoom;
    _map.move(LatLng(c.latitude, c.longitude), zoom);
  }

  void _recenter() {
    setState(() => _follow = true);
    _onTrackerUpdate();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _start() async {
    await tracker.start();
    if (!mounted) return;
    if (tracker.error != null) {
      _snack(tracker.error!);
      return;
    }
    _recenter();
  }

  Future<void> _finish() async {
    tracker.pause();
    final titleCtrl = TextEditingController(
      text: Activity.defaultTitle(tracker.type, DateTime.now()),
    );
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Simpan Aktivitas',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '${formatKm(tracker.distanceM)} km  •  ${formatDuration(tracker.elapsedSec)}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul aktivitas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Simpan',
              icon: Icons.check,
              onPressed: () => Navigator.pop(ctx, 'save'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, 'resume'),
                    child: const Text('Lanjutkan'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, 'discard'),
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: const Text('Buang'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    switch (result) {
      case 'save':
        final title = titleCtrl.text.trim().isEmpty
            ? Activity.defaultTitle(tracker.type, DateTime.now())
            : titleCtrl.text.trim();
        final activity = tracker.finish(title);
        if (activity == null) {
          _snack('Rute terlalu pendek untuk disimpan.');
          return;
        }
        await activityRepo.add(activity);
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ActivityDetailScreen(activity: activity),
        ));
      case 'discard':
        tracker.discard();
        _snack('Aktivitas dibuang.');
      case 'resume':
        tracker.resume();
      default:
        break; // tetap dijeda
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: tracker,
        builder: (context, _) {
          final route = tracker.route;
          final cur = tracker.current;
          final curLatLng = cur == null ? null : LatLng(cur.latitude, cur.longitude);
          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: curLatLng ?? _fallback,
                  initialZoom: curLatLng == null ? 12 : 17,
                  onMapReady: () {
                    _mapReady = true;
                    _onTrackerUpdate();
                  },
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture && _follow) setState(() => _follow = false);
                  },
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  rayvaTileLayer(),
                  if (route.length >= 2)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: route,
                        strokeWidth: 6,
                        gradientColors: routeGradientColors,
                        borderStrokeWidth: 4,
                        borderColor: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ]),
                  MarkerLayer(markers: [
                    if (route.isNotEmpty) startMarker(route.first),
                    if (curLatLng != null)
                      Marker(
                        point: curLatLng,
                        width: 80,
                        height: 80,
                        child: PulseDot(animation: _pulse),
                      ),
                  ]),
                ],
              ),
              _topBar(),
              if (tracker.error != null) _errorBanner(tracker.error!),
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 12),
                      child: FloatingActionButton.small(
                        heroTag: 'recenter',
                        backgroundColor: AppColors.card,
                        onPressed: _recenter,
                        child: Icon(
                          _follow ? Icons.my_location : Icons.location_searching,
                          color: _follow ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ),
                    _panel(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _topBar() {
    final s = tracker.state;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const RayvaLogo(size: 18),
            ),
            const Spacer(),
            if (s != TrackingState.idle)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: s == TrackingState.recording
                      ? Colors.redAccent
                      : Colors.amber.shade800,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s == TrackingState.recording ? Icons.fiber_manual_record : Icons.pause,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s == TrackingState.recording ? 'MEREKAM' : 'JEDA',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 64, 12, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.location_off),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Geolocator.openLocationSettings(),
                    child: const Text('Pengaturan GPS', style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () => Geolocator.openAppSettings(),
                    child: const Text('Izin Aplikasi', style: TextStyle(color: Colors.white)),
                  ),
                  FilledButton(
                    onPressed: () => tracker.init(),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    final s = tracker.state;
    final isRide = tracker.type == SportType.ride;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s != TrackingState.idle) ...[
            Text(
              formatDuration(tracker.elapsedSec),
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, height: 1),
            ),
            const SizedBox(height: 4),
            const Text('WAKTU',
                style: TextStyle(color: AppColors.muted, letterSpacing: 1.5, fontSize: 11)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Jarak',
                    value: formatKm(tracker.distanceM),
                    unit: 'km',
                    align: CrossAxisAlignment.center,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: isRide ? 'Kec. rata2' : 'Pace',
                    value: isRide
                        ? tracker.avgSpeedKmh.toStringAsFixed(1)
                        : formatPace(tracker.avgPaceSecPerKm),
                    unit: isRide ? 'km/j' : '/km',
                    align: CrossAxisAlignment.center,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Sekarang',
                    value: tracker.currentSpeedKmh.toStringAsFixed(1),
                    unit: 'km/j',
                    align: CrossAxisAlignment.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _controls(s),
        ],
      ),
    );
  }

  Widget _controls(TrackingState s) {
    switch (s) {
      case TrackingState.idle:
        return Column(
          children: [
            SegmentedButton<SportType>(
              showSelectedIcon: false,
              segments: SportType.values
                  .map((t) => ButtonSegment(
                        value: t,
                        icon: Icon(t.icon),
                        label: Text(t.label),
                      ))
                  .toList(),
              selected: {tracker.type},
              onSelectionChanged: (sel) => tracker.setType(sel.first),
            ),
            const SizedBox(height: 18),
            RoundButton(
              icon: Icons.play_arrow_rounded,
              size: 84,
              label: 'MULAI',
              onTap: _start,
            ),
          ],
        );
      case TrackingState.recording:
        return RoundButton(
          icon: Icons.pause_rounded,
          size: 76,
          label: 'Jeda',
          onTap: tracker.pause,
        );
      case TrackingState.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            RoundButton(
              icon: Icons.play_arrow_rounded,
              label: 'Lanjut',
              onTap: tracker.resume,
            ),
            RoundButton(
              icon: Icons.stop_rounded,
              label: 'Selesai',
              color: Colors.redAccent,
              onTap: _finish,
            ),
          ],
        );
    }
  }
}

