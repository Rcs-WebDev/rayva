import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

/// Tile peta gelap (CARTO Dark Matter, data © OpenStreetMap).
TileLayer rayvaTileLayer() => TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'com.rayva.app',
      maxNativeZoom: 19,
    );

Widget rayvaAttribution() => const SimpleAttributionWidget(
      source: Text('© OpenStreetMap © CARTO', style: TextStyle(fontSize: 10)),
      backgroundColor: Colors.black54,
      alignment: Alignment.topRight,
    );

/// Marker titik awal (hijau) / akhir (kotak catur).
Marker startMarker(LatLng p) => Marker(
      point: p,
      width: 22,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );

Marker finishMarker(LatLng p) => Marker(
      point: p,
      width: 24,
      height: 24,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: const Icon(Icons.flag, size: 14, color: Colors.black),
      ),
    );

/// Peta statis kecil untuk kartu aktivitas.
class RoutePreview extends StatelessWidget {
  const RoutePreview({super.key, required this.route, this.height = 180});
  final List<LatLng> route;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: IgnorePointer(
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(route),
              padding: const EdgeInsets.all(28),
              maxZoom: 17,
            ),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            rayvaTileLayer(),
            PolylineLayer(polylines: [
              Polyline(
                points: route,
                strokeWidth: 4,
                gradientColors: routeGradientColors,
              ),
            ]),
            MarkerLayer(markers: [startMarker(route.first), finishMarker(route.last)]),
          ],
        ),
      ),
    );
  }
}

