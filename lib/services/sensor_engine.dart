import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';
import 'package:light/light.dart';

class SensorEngine {
  SensorEngine({
    required this.onEmergency,
    this.onStatusChanged,
  });

  final void Function() onEmergency;
  final void Function(String status)? onStatusChanged;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<int>? _lightSub;
  Timer? _idleTimer;

  DateTime? _lastMotion;
  double _lightLux = -1;
  double _acceleration = 0;

  bool _impactDetected = false;
  bool _enabled = false;
  bool _triggered = false;

  bool get enabled => _enabled;
  double get lightLux => _lightLux;
  double get acceleration => _acceleration;

  void _status(String value) {
    onStatusChanged?.call(value);
  }

  Future<void> start() async {
    if (_enabled) return;

    _enabled = true;
    _triggered = false;
    _impactDetected = false;
    _lastMotion = DateTime.now();
    _status('Memulai sensor...');

    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(
        (event) {
          if (!_enabled) return;

          _acceleration = math.sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );

          if (_acceleration > 20) {
            _impactDetected = true;
            _lastMotion = DateTime.now();
            _status('Benturan terdeteksi; menunggu kondisi berikutnya');
          } else if (_acceleration > 12) {
            _lastMotion = DateTime.now();
            _status('Gerakan terdeteksi');
          }

          _check();
        },
        onError: (error) {
          _status('Sensor gerak error: $error');
        },
      );
    } catch (error) {
      _status('Gagal mengaktifkan sensor gerak: $error');
    }

    try {
      _lightSub = Light().lightSensorStream.listen(
        (lux) {
          if (!_enabled) return;
          _lightLux = lux.toDouble();
          _check();
        },
        onError: (error) {
          _lightLux = -1;
          _status('Sensor cahaya error: $error');
        },
      );
    } catch (error) {
      _lightLux = -1;
      _status('Sensor cahaya tidak tersedia: $error');
    }

    _idleTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _check(),
    );

    _status('Sensor aktif; menunggu kondisi darurat');
  }

  void _check() {
    if (!_enabled || _triggered) return;

    if (!_impactDetected) {
      return;
    }

    if (_lightLux != 0) {
      return;
    }

    if (_lastMotion == null) return;

    final idleDuration = DateTime.now().difference(_lastMotion!);

    if (idleDuration >= const Duration(seconds: 5)) {
      _triggered = true;
      _status('Kondisi darurat terdeteksi');
      onEmergency();
    }
  }

  void resetTrigger() {
    _triggered = false;
    _impactDetected = false;
    _lastMotion = DateTime.now();
    _status('Pemicu direset; sensor kembali memantau');
  }

  Future<void> stop() async {
    _enabled = false;

    _idleTimer?.cancel();
    _idleTimer = null;

    await _accelSub?.cancel();
    await _lightSub?.cancel();

    _accelSub = null;
    _lightSub = null;

    _status('Sensor dihentikan');
  }

  Future<void> dispose() => stop();
}
