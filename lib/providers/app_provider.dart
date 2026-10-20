import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/sensor_engine.dart';
import '../services/biometric_login_service.dart';

class AppProvider extends ChangeNotifier {
  int tabIndex = 0;
  String userRole = 'pengguna';
  bool roleLoading = false;
  bool developerOverride = false;
  bool emergencyActive = false;
  bool appLocked = false;

  SensorEngine? _sensor;

  void setTab(int index) {
    tabIndex = index;
    notifyListeners();
  }

  void attachSensor(SensorEngine sensor) {
    _sensor = sensor;
  }

  void setDeveloperOverride(bool value) {
    developerOverride = value;
    notifyListeners();
  }

  void triggerEmergency() {
    emergencyActive = true;
    notifyListeners();
  }

  void cancelEmergency() {
    emergencyActive = false;
    _sensor?.resetTrigger();
    notifyListeners();
  }

  Future<void> loadUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      userRole = 'pengguna';
      roleLoading = false;
      notifyListeners();
      return;
    }

    roleLoading = true;
    notifyListeners();

    try {
      final result = await Supabase.instance.client
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      final role = result?['role'] as String?;

      if (role == 'admin' || role == 'petugas') {
        userRole = role!;
      } else {
        userRole = 'pengguna';
      }
    } catch (e) {
      debugPrint('Gagal membaca role pengguna: $e');
      userRole = 'pengguna';
    } finally {
      roleLoading = false;
      notifyListeners();
    }
  }

  Future<void> initializeLockState() async {
    appLocked = await BiometricLoginService().isLocked();
    notifyListeners();
  }

  Future<void> signOut() async {
    final biometric = BiometricLoginService();

    if (await biometric.isEnabled()) {
      await biometric.lock();
      appLocked = true;
    } else {
      await Supabase.instance.client.auth.signOut();
      appLocked = false;
    }

    tabIndex = 0;
    userRole = 'pengguna';
    notifyListeners();
  }

  Future<bool> biometricLogin() async {
    final success = await BiometricLoginService().login();

    if (success) {
      appLocked = false;
      tabIndex = 0;
      notifyListeners();
    }

    return success;
  }

  Future<void> unlockWithPassword() async {
    // Dipanggil setelah login email dan kata sandi berhasil.
    await BiometricLoginService().unlock();
    appLocked = false;
    notifyListeners();
  }
}
