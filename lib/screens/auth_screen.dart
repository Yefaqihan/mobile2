import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/app_provider.dart';
import '../services/biometric_login_service.dart';
import '../widgets/resq_widgets.dart';
import 'main_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkingLock = true;

  @override
  void initState() {
    super.initState();
    _initializeLock();
  }

  Future<void> _initializeLock() async {
    final provider = context.read<AppProvider>();

    await provider.initializeLockState();

    if (mounted) {
      setState(() => _checkingLock = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (_checkingLock ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: resqOrange),
            ),
          );
        }

        return Consumer<AppProvider>(
          builder: (context, provider, child) {
            final user = Supabase.instance.client.auth.currentUser;

            if (user != null && !provider.appLocked) {
              return const MainScreen();
            }

            return const AuthScreen();
          },
        );
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _register = false;
  bool _busy = false;
  bool _obscure = true;

  String? _error;
  String? _success;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      setState(() {
        _error = 'Masukkan email dan kata sandi minimal 6 karakter.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    try {
      final supabase = Supabase.instance.client;

      if (_register) {
        final response = await supabase.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );

        if (response.session != null) {
          await supabase.auth.signOut();
        }

        if (!mounted) return;

        setState(() {
          _register = false;
          _success = 'Pendaftaran berhasil. Silakan masuk dengan akunmu.';
          _password.clear();
        });
      } else {
        await supabase.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );

        await context.read<AppProvider>().unlockWithPassword();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Terjadi kesalahan. Periksa koneksi dan konfigurasi Supabase.';
        });
      }
      debugPrint('Proses autentikasi gagal: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _biometric() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    try {
      final service = BiometricLoginService();

      if (!await service.isEnabled()) {
        if (mounted) {
          setState(() {
            _error =
                'Login biometrik belum aktif. Masuk dengan email dan kata sandi, lalu aktifkan di profil.';
          });
        }
        return;
      }

      final success = await context.read<AppProvider>().biometricLogin();

      if (!mounted) return;

      if (!success) {
        setState(() {
          _error =
              'Verifikasi dibatalkan. Silakan coba lagi atau masuk manual.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Login biometrik gagal. Silakan masuk dengan email dan kata sandi.';
      });
      debugPrint('Login biometrik gagal: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: resqOrange,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Tetap siap.\nTetap selamat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: resqBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Teman siaga untuk informasi bencana dan persiapan darurat.',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 28),
                ResQCard(
                  child: Column(
                    children: [
                      Text(
                        _register ? 'Buat akun ResQ' : 'Selamat datang kembali',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: resqBlue,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Kata sandi',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _obscure = !_obscure);
                            },
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: resqRed),
                        ),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _success!,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: _busy
                            ? 'Memproses...'
                            : (_register ? 'Daftar akun' : 'Masuk'),
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _busy ? null : _submit,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _register = !_register;
                                  _error = null;
                                  _success = null;
                                });
                              },
                        child: Text(
                          _register
                              ? 'Sudah punya akun? Masuk'
                              : 'Belum punya akun? Daftar',
                        ),
                      ),
                      if (!_register) ...[
                        const Divider(height: 24),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _biometric,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Masuk dengan biometrik'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: resqBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Informasi ResQ membantu persiapan, bukan pengganti petugas darurat.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
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
