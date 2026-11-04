import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rayva/utils/format.dart';
import 'package:rayva/utils/geo.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(65), '01:05');
    expect(formatDuration(3725), '1:02:05');
  });

  test('formatPace', () {
    expect(formatPace(332), "5'32\"");
    expect(formatPace(0), "--'--\"");
  });

  test('positionAt interpolates along route', () {
    final pts = [const LatLng(0, 0), const LatLng(0, 0.01)];
    final cum = cumulativeDistances(pts);
    final (p, idx) = positionAt(pts, cum, cum.last / 2);
    expect(idx, 0);
    expect(p.longitude, closeTo(0.005, 1e-6));
  });
}

