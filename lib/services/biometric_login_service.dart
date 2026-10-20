import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BiometricLoginService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _enabledKey = 'resq_biometric_enabled';
  static const String _lockedKey = 'resq_app_locked';

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isEnabled() async {
    return await _storage.read(key: _enabledKey) == 'true';
  }

  Future<bool> isLocked() async {
    return await _storage.read(key: _lockedKey) == 'true';
  }

  Future<bool> enable() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      throw Exception('Masuk ke akun terlebih dahulu.');
    }

    final supported = await _auth.isDeviceSupported();
    final biometrics = await _auth.getAvailableBiometrics();

    if (!supported || biometrics.isEmpty) {
      throw Exception(
        'Atur sidik jari atau biometrik di pengaturan HP terlebih dahulu.',
      );
    }

    final verified = await _auth.authenticate(
      localizedReason: 'Aktifkan login biometrik untuk ResQ',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );

    if (!verified) return false;

    await _storage.write(key: _enabledKey, value: 'true');
    return true;
  }

  Future<bool> login() async {
    if (!await isEnabled()) {
      throw Exception('Login biometrik belum diaktifkan.');
    }

    final supported = await _auth.isDeviceSupported();
    final biometrics = await _auth.getAvailableBiometrics();

    if (!supported || biometrics.isEmpty) {
      throw Exception('Biometrik tidak tersedia pada perangkat ini.');
    }

    final verified = await _auth.authenticate(
      localizedReason: 'Verifikasi identitas untuk membuka ResQ',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );

    if (!verified) return false;

    // Sesi Supabase tetap aktif selama aplikasi dikunci.
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Sesi akun sudah berakhir. Masuk menggunakan email dan kata sandi.',
      );
    }

    await _storage.delete(key: _lockedKey);
    return true;
  }

  Future<void> lock() async {
    await _storage.write(key: _lockedKey, value: 'true');
  }

  Future<void> unlock() async {
    await _storage.delete(key: _lockedKey);
  }

  Future<void> disable() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _lockedKey);
  }
}
