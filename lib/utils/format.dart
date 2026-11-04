import 'package:intl/intl.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String formatDuration(int totalSec) {
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

String formatKm(double meters) => (meters / 1000).toStringAsFixed(2);

String formatPace(double secPerKm) {
  if (secPerKm <= 0 || secPerKm.isNaN || secPerKm.isInfinite || secPerKm > 5999) {
    return "--'--\"";
  }
  var m = secPerKm ~/ 60;
  var s = (secPerKm - m * 60).round();
  if (s == 60) {
    m += 1;
    s = 0;
  }
  return "$m'${_two(s)}\"";
}

String formatDate(DateTime d) => DateFormat('EEEE, d MMM yyyy • HH:mm').format(d);

String formatShortDate(DateTime d) => DateFormat('d MMM yyyy • HH:mm').format(d);

