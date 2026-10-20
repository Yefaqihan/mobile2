import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../providers/app_provider.dart';
import '../widgets/resq_widgets.dart';
import '../services/biometric_login_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _blood = TextEditingController();
  final _allergies = TextEditingController();
  final _contact = TextEditingController();
  final _feedback = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _hasMedicalData = false;
  bool _loading = true;
  bool _saving = false;
  bool _unlocked = false;
  bool _enablingBiometric = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _blood.dispose();
    _allergies.dispose();
    _contact.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      final data = await supabase
          .from('medical_records')
          .select('blood_group, allergies, emergency_contact')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final hasData = data != null;

      if (data != null) {
        _blood.text = data['blood_group'] ?? '';
        _allergies.text = data['allergies'] ?? '';
        _contact.text = data['emergency_contact'] ?? '';
      }

      setState(() {
        _loading = false;
        _hasMedicalData = hasData;
        _unlocked = !hasData;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _snack('Gagal memuat data medis. Periksa koneksi Supabase.');
      debugPrint('Gagal memuat rekam medis: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Periksa kembali data yang kamu masukkan.');
      return;
    }

    setState(() => _saving = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _snack('Silakan masuk terlebih dahulu.');
        return;
      }

      await supabase.from('medical_records').upsert({
        'user_id': user.id,
        'blood_group': _blood.text.trim(),
        'allergies': _allergies.text.trim(),
        'emergency_contact': _contact.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      setState(() {
        _hasMedicalData = true;
        _unlocked = false;
      });

      _snack('Data medis tersimpan. Data sekarang terkunci.');
    } catch (e) {
      if (mounted) {
        _snack('Gagal menyimpan data medis ke Supabase.');
      }
      debugPrint('Gagal menyimpan rekam medis: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _enableBiometricLogin() async {
  try {
    final success = await BiometricLoginService().enable();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Login biometrik berhasil diaktifkan.'
              : 'Aktivasi biometrik dibatalkan.',
        ),
      ),
    );

    if (success) {
      setState(() {});
    }
  } catch (e, stackTrace) {
    debugPrint('GAGAL AKTIVASI BIOMETRIK: $e');
    debugPrintStack(stackTrace: stackTrace);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal mengaktifkan biometrik: $e'),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

  Future<void> _biometricLock() async {
    try {
      final auth = LocalAuthentication();

      final supported = await auth.isDeviceSupported();
      final biometrics = await auth.getAvailableBiometrics();

      if (!supported || biometrics.isEmpty) {
        _snack(
          'Biometrik tidak tersedia. Periksa pengaturan sidik jari HP.',
        );
        return;
      }

      final ok = await auth.authenticate(
        localizedReason: 'Verifikasi identitas untuk membuka data medis ResQ',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      setState(() => _unlocked = ok);

      if (!ok) {
        _snack('Verifikasi dibatalkan. Data medis tetap terkunci.');
      }
    } catch (e) {
      if (!mounted) return;

      _snack('Biometrik gagal. Periksa pengaturan perangkat.');
      debugPrint('Kesalahan biometrik: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu akan keluar dari akun ResQ dan kembali ke halaman login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await context.read<AppProvider>().signOut();
    } catch (e) {
      if (!mounted) return;

      _snack('Gagal keluar dari akun. Silakan coba lagi.');
      debugPrint('Logout gagal: $e');
    }
  }

  void _snack(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const Text(
          'PROFIL / PERSONAL',
          style: TextStyle(
            color: resqOrange,
            letterSpacing: 1.5,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Informasi pentingmu.',
          style: TextStyle(
            color: resqBlue,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),

        // Informasi akun
        ResQCard(
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: resqBlue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: resqBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.email ?? 'Pengguna ResQ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: resqBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Akun ResQ • Data medis',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Rekam medis
        Row(
          children: [
            const Expanded(
              child: SectionTitle(
                'Rekam medis darurat',
                subtitle: 'Data disimpan dengan aman di akun ResQ.',
              ),
            ),
            IconButton(
              onPressed: _biometricLock,
              icon: const Icon(
                Icons.fingerprint,
                color: resqOrange,
                size: 30,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_loading)
          const Center(
            child: CircularProgressIndicator(color: resqOrange),
          )
        else if (_hasMedicalData && !_unlocked)
          ResQCard(
            child: Column(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 38,
                  color: resqBlue,
                ),
                const SizedBox(height: 8),
                const Text('Data medis terkunci'),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Buka dengan biometrik',
                  icon: Icons.fingerprint,
                  onPressed: _biometricLock,
                ),
              ],
            ),
          )
        else
          ResQCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _blood.text.isEmpty ? null : _blood.text,
                    decoration: const InputDecoration(
                      labelText: 'Golongan darah',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      'A+',
                      'A-',
                      'B+',
                      'B-',
                      'AB+',
                      'AB-',
                      'O+',
                      'O-',
                      'Belum tahu',
                    ].map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih golongan darah terlebih dahulu.';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() => _blood.text = value ?? '');
                    },
                    hint: const Text('Pilih golongan darah'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _allergies,
                    maxLength: 300,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Alergi / kondisi penting',
                      hintText: 'Contoh: alergi obat tertentu',
                      border: OutlineInputBorder(),
                      helperText: 'Kosongkan jika tidak ada.',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';

                      if (text.isNotEmpty && text.length < 2) {
                        return 'Jelaskan alergi atau kondisi dengan lebih lengkap.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contact,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    maxLength: 15,
                    decoration: const InputDecoration(
                      labelText: 'Kontak darurat',
                      hintText: 'Contoh: 081234567890',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';

                      if (phone.isEmpty) {
                        return 'Nomor kontak darurat wajib diisi.';
                      }

                      if (phone.length < 8 || phone.length > 15) {
                        return 'Nomor harus terdiri dari 8–15 angka.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: _saving ? 'Menyimpan...' : 'Simpan data medis',
                    icon: Icons.save_outlined,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _unlocked = false);
                    },
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Kunci data medis'),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Feedback
        const SectionTitle('Masukan untuk ResQ'),
        const SizedBox(height: 10),
        ResQCard(
          child: Column(
            children: [
              TextField(
                controller: _feedback,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Kritik, saran, atau ide',
                  border: OutlineInputBorder(),
                  hintText: 'Apa yang bisa kami perbaiki?',
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Kirim masukan',
                icon: Icons.chat_bubble_outline,
                onPressed: () async {
                  final message = _feedback.text.trim();

                  if (message.isEmpty) {
                    _snack('Tulis masukan terlebih dahulu.');
                    return;
                  }

                  final supabase = Supabase.instance.client;
                  final currentUser = supabase.auth.currentUser;

                  if (currentUser == null) {
                    _snack('Silakan masuk terlebih dahulu.');
                    return;
                  }

                  try {
                    await supabase.from('feedback').insert({
                      'user_id': currentUser.id,
                      'message': message,
                    });

                    if (!mounted) return;

                    _feedback.clear();
                    _snack('Terima kasih! Feedback berhasil dikirim.');
                  } catch (e) {
                    if (!mounted) return;

                    _snack('Gagal mengirim feedback. Coba lagi.');
                    debugPrint('Gagal menyimpan feedback: $e');
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Aktivasi login biometrik
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _enablingBiometric ? null : _enableBiometricLogin,
            icon: const Icon(Icons.fingerprint),
            label: Text(
              _enablingBiometric
                  ? 'Mengaktifkan...'
                  : 'Aktifkan login biometrik',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: resqBlue,
              side: const BorderSide(color: resqBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Logout
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar dari akun'),
            style: OutlinedButton.styleFrom(
              foregroundColor: resqRed,
              side: const BorderSide(color: resqRed),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        const Text(
          'ResQ adalah prototipe edukasi. Simpan informasi medis dengan bijak dan jangan mengandalkan aplikasi ini sebagai satu-satunya sarana darurat.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.blueGrey,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
