import 'package:latlong2/latlong.dart';

const _distance = Distance(roundResult: false);

double metersBetween(LatLng a, LatLng b) => _distance.distance(a, b);

/// Jarak kumulatif (meter) dari titik awal ke setiap titik.
List<double> cumulativeDistances(List<LatLng> pts) {
  final out = <double>[];
  if (pts.isEmpty) return out;
  out.add(0);
  for (var i = 1; i < pts.length; i++) {
    out.add(out.last + metersBetween(pts[i - 1], pts[i]));
  }
  return out;
}

/// Posisi pada rute setelah menempuh [d] meter, hasil interpolasi.
/// Mengembalikan (titik, index segmen terakhir yang sudah dilewati).
(LatLng, int) positionAt(List<LatLng> pts, List<double> cum, double d) {
  if (pts.isEmpty) return (const LatLng(0, 0), 0);
  if (d <= 0 || pts.length == 1) return (pts.first, 0);
  if (d >= cum.last) return (pts.last, pts.length - 1);

  var lo = 0;
  var hi = cum.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (cum[mid] <= d) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final seg = cum[hi] - cum[lo];
  final f = seg == 0 ? 0.0 : (d - cum[lo]) / seg;
  final a = pts[lo];
  final b = pts[hi];
  return (
    LatLng(
      a.latitude + (b.latitude - a.latitude) * f,
      a.longitude + (b.longitude - a.longitude) * f,
    ),
    lo,
  );
}

