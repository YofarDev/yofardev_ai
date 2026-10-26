import 'dart:async';
import 'dart:io';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

// usage: dart run bin/frames.dart <ws-uri> <seconds> <label>
Future<void> main(List<String> args) async {
  final VmService svc = await vmServiceConnectUri(args[0]);
  final int secs = int.parse(args[1]);
  final List<Map<String, dynamic>> frames = <Map<String, dynamic>>[];
  svc.onExtensionEvent.listen((Event e) {
    if (e.extensionKind == 'Flutter.Frame') {
      frames.add(Map<String, dynamic>.from(e.extensionData!.data));
    }
  });
  await svc.streamListen(EventStreams.kExtension);
  await Future<void>.delayed(const Duration(seconds: 2));
  frames.clear();
  stdout.writeln('${args[2]}: recording');
  await Future<void>.delayed(Duration(seconds: secs));
  if (frames.isEmpty) {
    stdout.writeln('${args[2]}: no frames (idle, nothing repainted)');
    exit(0);
  }
  List<double> ms(String k) =>
      frames.map((f) => (f[k] as int) / 1000.0).toList()..sort();
  double pct(List<double> v, double p) => v[((v.length - 1) * p).round()];
  final List<double> b = ms('build'), r = ms('raster'), el = ms('elapsed');
  final int jank = frames.where((f) => (f['elapsed'] as int) > 16667).length;
  stdout.writeln('${args[2]}: frames=${frames.length} (${(frames.length / secs).toStringAsFixed(1)}/s) '
      'build p50/p90/p99/max=${pct(b, .5).toStringAsFixed(1)}/${pct(b, .9).toStringAsFixed(1)}/${pct(b, .99).toStringAsFixed(1)}/${b.last.toStringAsFixed(1)}ms '
      'raster p50/p90/p99/max=${pct(r, .5).toStringAsFixed(1)}/${pct(r, .9).toStringAsFixed(1)}/${pct(r, .99).toStringAsFixed(1)}/${r.last.toStringAsFixed(1)}ms '
      'frames>16.7ms=$jank');
  exit(0);
}
