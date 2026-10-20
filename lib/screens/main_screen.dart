import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:torch_light/torch_light.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:vibration/vibration.dart';

import '../providers/app_provider.dart';
import '../services/sensor_engine.dart';
import '../widgets/resq_widgets.dart';
import 'home_screen.dart';
import 'survival_screen.dart';
import 'ledger_screen.dart';
import 'news_screen.dart';
import 'profile_screen.dart';
import 'riwayat_laporan_screen.dart';
import 'tugas_petugas_screen.dart';
import 'admin/kelola_berita_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final SensorEngine _sensor;

  Future<void> _loadRole() async {
    await context.read<AppProvider>().loadUserRole();
  }

  @override
  void initState() {
    super.initState();

    _sensor = SensorEngine(
      onEmergency: () {
        if (!mounted) return;
        context.read<AppProvider>().triggerEmergency();
      },
    );

    context.read<AppProvider>().attachSensor(_sensor);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _loadRole();
      unawaited(_sensor.start());
    });
  }

  @override
  void dispose() {
    _sensor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (app.roleLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    late final List<Widget> screens;
    late final List<NavigationDestination> destinations;

    if (app.userRole == 'admin') {
      screens = const [
        HomeScreen(),
        RiwayatLaporanScreen(),
        KelolaBeritaScreen(),
        ProfileScreen(),
      ];

      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'Verifikasi',
        ),
        NavigationDestination(
          icon: Icon(Icons.newspaper_outlined),
          selectedIcon: Icon(Icons.newspaper),
          label: 'Berita',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    } else if (app.userRole == 'petugas') {
      screens = const [
        HomeScreen(),
        TugasPetugasScreen(),
        ProfileScreen(),
      ];

      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Tugas',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    } else {
      screens = const [
        HomeScreen(),
        SurvivalScreen(),
        LedgerScreen(),
        NewsScreen(),
        ProfileScreen(),
      ];

      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.radar_outlined),
          selectedIcon: Icon(Icons.radar),
          label: 'Siaga',
        ),
        NavigationDestination(
          icon: Icon(Icons.support_agent_outlined),
          selectedIcon: Icon(Icons.support_agent),
          label: 'AI Hub',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'Laporan',
        ),
        NavigationDestination(
          icon: Icon(Icons.newspaper_outlined),
          selectedIcon: Icon(Icons.newspaper),
          label: 'Berita',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    }

    final safeIndex = app.tabIndex.clamp(0, screens.length - 1);

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: safeIndex,
              children: screens,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: app.setTab,
            backgroundColor: Colors.white,
            indicatorColor: resqOrange.withValues(alpha: .13),
            destinations: destinations,
          ),
        ),
        if (app.emergencyActive)
          EmergencyOverlay(onCancel: app.cancelEmergency),
      ],
    );
  }
}

class EmergencyOverlay extends StatefulWidget {
  const EmergencyOverlay({
    super.key,
    required this.onCancel,
  });

  final VoidCallback onCancel;

  @override
  State<EmergencyOverlay> createState() => _EmergencyOverlayState();
}

class _EmergencyOverlayState extends State<EmergencyOverlay> {
  int _seconds = 30;

  Timer? _timer;
  Timer? _torchTimer;

  final AudioPlayer _alarmPlayer = AudioPlayer();

  bool _alarmStarted = false;
  bool _torchOn = false;
  bool _stopping = false;

  String? _errorMessage;

  // Getaran singkat sebagai peringatan selama hitung mundur.
  Future<void> _getarPeringatan() async {
    try {
      await Vibration.vibrate(
        duration: 300,
        amplitude: 180,
      );
    } catch (e) {
      debugPrint('RESQ: Getaran tidak tersedia: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // Getaran langsung saat peringatan darurat muncul.
    unawaited(_getarPeringatan());

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_seconds <= 1) {
          timer.cancel();

          setState(() {
            _seconds = 0;
          });

          // Hitung mundur selesai, aktifkan alarm dan senter.
          unawaited(_startAlarmAndTorch());
        } else {
          setState(() {
            _seconds--;
          });

          // Getaran singkat setiap detik.
          unawaited(_getarPeringatan());
        }
      },
    );
  }

  Future<void> _startAlarmAndTorch() async {
    if (_alarmStarted || !mounted || _stopping) return;

    _alarmStarted = true;

    // Atur volume media ke maksimum.
    try {
      await VolumeController.instance.setVolume(1.0);
    } catch (e) {
      debugPrint('RESQ: Gagal mengatur volume: $e');
    }

    if (!mounted || _stopping) return;

    // Putar alarm terus-menerus.
    try {
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);

      await _alarmPlayer.play(
        AssetSource('sounds/alarm.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('RESQ: Gagal memutar alarm: $e');

      if (mounted) {
        setState(() {
          _errorMessage = 'Suara alarm gagal diputar.';
        });
      }
    }

    if (!mounted || _stopping) return;

    // Mulai kedipan senter.
    try {
      await TorchLight.enableTorch();
      _torchOn = true;

      _torchTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (timer) {
          if (!mounted || _stopping) {
            timer.cancel();
            return;
          }

          unawaited(_toggleTorch());
        },
      );
    } catch (e) {
      debugPrint('RESQ: Gagal menyalakan senter: $e');

      if (mounted) {
        setState(() {
          _errorMessage = 'Senter tidak tersedia atau gagal dinyalakan.';
        });
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleTorch() async {
    if (!mounted || _stopping) return;

    try {
      if (_torchOn) {
        await TorchLight.disableTorch();
        _torchOn = false;
      } else {
        await TorchLight.enableTorch();
        _torchOn = true;
      }
    } catch (e) {
      debugPrint('RESQ: Gagal mengedipkan senter: $e');

      _torchTimer?.cancel();
      _torchTimer = null;

      if (mounted) {
        setState(() {
          _errorMessage = 'Senter gagal berkedip.';
        });
      }
    }
  }

  Future<void> _stopAlarmAndTorch() async {
    if (_stopping) return;

    _stopping = true;

    // Hentikan semua timer.
    _timer?.cancel();
    _torchTimer?.cancel();

    // Hentikan getaran.
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('RESQ: Gagal menghentikan getaran: $e');
    }

    // Hentikan suara alarm.
    try {
      await _alarmPlayer.stop();
    } catch (e) {
      debugPrint('RESQ: Gagal menghentikan alarm: $e');
    }

    // Pastikan senter mati.
    try {
      if (_torchOn) {
        await TorchLight.disableTorch();
        _torchOn = false;
      }
    } catch (e) {
      debugPrint('RESQ: Gagal mematikan senter: $e');
    }

    if (!mounted) return;

    // Tutup overlay dan reset pemicu melalui AppProvider.
    widget.onCancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _torchTimer?.cancel();

    // Bersihkan alarm dan senter saat overlay dihapus.
    unawaited(_alarmPlayer.stop());
    unawaited(_alarmPlayer.dispose());

    unawaited(_batalkanGetaran());

    if (_torchOn) {
      unawaited(
        TorchLight.disableTorch().catchError((_) {}),
      );
    }

    super.dispose();
  }

  Future<void> _batalkanGetaran() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('RESQ: Gagal membersihkan getaran: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarmActive = _seconds == 0;

    return Positioned.fill(
      child: Material(
        color: resqRed,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  alarmActive
                      ? Icons.campaign_rounded
                      : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 88,
                ),
                const SizedBox(height: 18),
                Text(
                  alarmActive ? 'ALARM DARURAT AKTIF' : 'KONDISI DARURAT?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  alarmActive
                      ? 'Alarm suara dan senter berkedip telah '
                          'diaktifkan. Pastikan kamu berada di tempat aman.'
                      : 'Deteksi sensor mengindikasikan benturan '
                          'dan kondisi gelap. Pastikan kamu aman.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '$_seconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 68,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  alarmActive
                      ? 'detik — alarm sudah aktif'
                      : 'detik sebelum alarm dan senter aktif',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
                if (!alarmActive) ...[
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.vibration,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Peringatan getaran aktif',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
                if (alarmActive) ...[
                  const SizedBox(height: 18),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.volume_up,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Alarm maksimal',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flashlight_on,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Senter berkedip',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _stopAlarmAndTorch,
                    icon: Icon(
                      alarmActive
                          ? Icons.stop_circle_outlined
                          : Icons.check_circle_outline,
                    ),
                    label: Text(
                      alarmActive
                          ? 'Hentikan alarm dan senter'
                          : 'Saya aman — batalkan',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: resqRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (alarmActive)
                  const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: Text(
                      'Ini prototipe. Alarm tidak otomatis '
                      'menghubungi layanan darurat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
