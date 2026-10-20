import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

const Color _background = Color(0xFFF7F5EF);
const Color _darkGreen = Color(0xFF26382B);
const Color _green = Color(0xFF4F7D58);
const Color _orange = Color(0xFFE58B3D);

class KelolaBeritaScreen extends StatefulWidget {
  const KelolaBeritaScreen({super.key});

  @override
  State<KelolaBeritaScreen> createState() => _KelolaBeritaScreenState();
}

class _KelolaBeritaScreenState extends State<KelolaBeritaScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _berita = [];
  List<Map<String, dynamic>> _laporanSelesai = [];

  final List<String> _kategoriList = [
    'Banjir',
    'Gempa Bumi',
    'Tanah Longsor',
    'Gunung Api',
    'Cuaca Ekstrem',
    'Tsunami',
    'Kebakaran Hutan',
    'Kesiapsiagaan',
    'Lainnya',
  ];

  Future<String?> _urlTampilanFoto(dynamic nilai) async {
    if (nilai == null || nilai.toString().trim().isEmpty) {
      return null;
    }

    String path = nilai.toString().trim();
    final uri = Uri.tryParse(path);

    // Jika URL berasal dari Supabase Storage,
    // ambil path file di dalam bucket.
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      final bagian = uri.pathSegments;
      final posisiBucket = bagian.indexOf('report-photos');

      if (posisiBucket == -1) {
        // URL dari sumber lain, gunakan langsung.
        return path;
      }

      if (posisiBucket + 1 >= bagian.length) {
        return null;
      }

      path = bagian.skip(posisiBucket + 1).join('/');
    }

    path = path.replaceFirst(RegExp(r'^/+'), '');

    if (path.startsWith('report-photos/')) {
      path = path.substring('report-photos/'.length);
    }

    try {
      return await _db.storage
          .from('report-photos')
          .createSignedUrl(path, 3600);
    } catch (e) {
      debugPrint('Signed URL gagal: $e');

      try {
        return _db.storage.from('report-photos').getPublicUrl(path);
      } catch (error) {
        debugPrint('URL foto gagal: $error');
        return null;
      }
    }
  }

  List<String> _daftarFotoBerita(Map<String, dynamic> berita) {
    final hasil = <String>[];
    final dataFoto = berita['image_urls'];

    if (dataFoto is List) {
      for (final foto in dataFoto) {
        final nilai = foto.toString().trim();
        if (nilai.isNotEmpty && !hasil.contains(nilai)) {
          hasil.add(nilai);
        }
      }
    } else if (dataFoto is String && dataFoto.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(dataFoto);
        if (decoded is List) {
          for (final foto in decoded) {
            final nilai = foto.toString().trim();
            if (nilai.isNotEmpty && !hasil.contains(nilai)) {
              hasil.add(nilai);
            }
          }
        }
      } catch (e) {
        debugPrint('Data image_urls tidak valid: $e');
      }
    }

    final fotoUtama = berita['image_url']?.toString().trim() ?? '';

    if (fotoUtama.isNotEmpty && !hasil.contains(fotoUtama)) {
      hasil.insert(0, fotoUtama);
    }

    return hasil;
  }

  String? _urlFoto(dynamic nilai) {
    if (nilai == null || nilai.toString().trim().isEmpty) {
      return null;
    }

    String path = nilai.toString().trim();
    final uri = Uri.tryParse(path);

    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      final bagian = uri.pathSegments;
      final posisiBucket = bagian.indexOf('report-photos');

      // Jika foto dari URL eksternal, simpan URL aslinya.
      if (posisiBucket == -1) {
        return path;
      }

      // Ambil path file setelah nama bucket.
      if (posisiBucket + 1 >= bagian.length) {
        return null;
      }

      path = bagian.skip(posisiBucket + 1).join('/');
    }

    path = path.replaceFirst(RegExp(r'^/+'), '');

    if (path.startsWith('report-photos/')) {
      path = path.substring('report-photos/'.length);
    }

    return path.isEmpty ? null : path;
  }

  Future<String?> _ambilUrlFotoLaporan(dynamic nilai) async {
    if (nilai == null || nilai.toString().trim().isEmpty) {
      return null;
    }

    final path = nilai.toString().trim();

    // Kalau sudah berupa URL lengkap, gunakan langsung.
    final uri = Uri.tryParse(path);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return path;
    }

    // Bersihkan path sebelum meminta URL ke Supabase.
    String pathBersih = path.replaceFirst(RegExp(r'^/+'), '');

    if (pathBersih.startsWith('report-photos/')) {
      pathBersih = pathBersih.substring('report-photos/'.length);
    }

    try {
      // Coba membuat URL yang berlaku selama 1 jam.
      return await _db.storage
          .from('report-photos')
          .createSignedUrl(pathBersih, 3600);
    } catch (e) {
      debugPrint('Gagal membuat signed URL foto: $e');

      try {
        // Alternatif untuk bucket yang bersifat publik.
        return _db.storage.from('report-photos').getPublicUrl(pathBersih);
      } catch (error) {
        debugPrint('Gagal mengambil URL publik foto: $error');
        return null;
      }
    }
  }

  Future<String> _unggahFotoBerita(
    XFile foto,
    int index,
  ) async {
    final namaAsli = foto.name;
    final bagianNama = namaAsli.split('.');
    String ekstensi =
        bagianNama.length > 1 ? bagianNama.last.toLowerCase() : 'jpg';

    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ekstensi)) {
      ekstensi = 'jpg';
    }

    final waktu = DateTime.now().microsecondsSinceEpoch;
    final namaFile = 'news/${waktu}_$index.$ekstensi';

    String tipeKonten;

    switch (ekstensi) {
      case 'png':
        tipeKonten = 'image/png';
        break;
      case 'webp':
        tipeKonten = 'image/webp';
        break;
      default:
        tipeKonten = 'image/jpeg';
    }

    try {
      final bytes = await foto.readAsBytes();

      await _db.storage.from('report-photos').uploadBinary(
            namaFile,
            bytes,
            fileOptions: FileOptions(
              contentType: tipeKonten,
              upsert: true,
            ),
          );

      return namaFile;
    } catch (e) {
      debugPrint('GAGAL UPLOAD FOTO GALERI: $e');
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _db.from('news').select().order(
              'created_at',
              ascending: false,
            ),
        _db
            .from('reports')
            .select(
              'id, type, description, latitude, longitude, '
              'created_at, status, handling_status, '
              'handling_notes, handling_photo_path, photo_path',
            )
            .eq('status', 'Terverifikasi')
            .eq('handling_status', 'Selesai')
            .order('created_at', ascending: false),
      ]);

      if (!mounted) return;

      setState(() {
        _berita = List<Map<String, dynamic>>.from(results[0]);
        _laporanSelesai = List<Map<String, dynamic>>.from(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Gagal memuat data. Periksa koneksi dan hak akses.';
      });
    }
  }

  Future<void> _buatBerita() async {
    final formKey = GlobalKey<FormState>();

    final judulController = TextEditingController();
    final ringkasanController = TextEditingController();
    final isiController = TextEditingController();
    final lokasiController = TextEditingController();

    String kategori = 'Banjir';
    String sumber = 'ResQ';
    String? laporanId;

    List<String> fotoLaporanTerpilih = [];
    List<XFile> fotoGaleriTerpilih = [];

    final berhasil = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _background,
              title: const Text(
                'Buat Berita Bencana',
                style: TextStyle(
                  color: _darkGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(laporanId),
                          initialValue: laporanId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Laporan terkait (opsional)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Tanpa laporan terkait'),
                            ),
                            ..._laporanSelesai.map((laporan) {
                              return DropdownMenuItem<String>(
                                value: laporan['id'].toString(),
                                child: Text(
                                  '#${laporan['id']} - ${laporan['type']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              laporanId = value;
                              fotoLaporanTerpilih = [];

                              if (value == null) return;

                              final laporan = _laporanSelesai.firstWhere(
                                (item) => item['id'].toString() == value,
                              );

                              final fotoWarga =
                                  laporan['photo_path']?.toString().trim() ??
                                      '';

                              final fotoPetugas = laporan['handling_photo_path']
                                      ?.toString()
                                      .trim() ??
                                  '';

                              if (fotoWarga.isNotEmpty) {
                                fotoLaporanTerpilih.add(fotoWarga);
                              }

                              if (fotoPetugas.isNotEmpty) {
                                fotoLaporanTerpilih.add(fotoPetugas);
                              }

                              if (lokasiController.text.isEmpty) {
                                final latitude = laporan['latitude'];
                                final longitude = laporan['longitude'];

                                if (latitude != null && longitude != null) {
                                  lokasiController.text =
                                      '$latitude, $longitude';
                                }
                              }

                              if (isiController.text.isEmpty) {
                                isiController.text = 'DESKRIPSI KEJADIAN\n'
                                    '${laporan['description'] ?? 'Belum ada deskripsi kejadian.'}\n\n'
                                    'LANGKAH PENANGGULANGAN\n'
                                    '${laporan['handling_notes'] ?? 'Informasi penanganan belum tersedia.'}\n\n'
                                    'STATUS PENANGANAN\n'
                                    '${laporan['handling_status'] ?? 'Belum ada informasi status.'}\n\n'
                                    'DOKUMENTASI PETUGAS\n'
                                    'Dokumentasi penanganan ditampilkan pada bagian foto berita.';
                              }

                              if (judulController.text.isEmpty) {
                                judulController.text =
                                    'Penanganan ${laporan['type'] ?? 'Bencana'}';
                              }

                              if (ringkasanController.text.isEmpty) {
                                ringkasanController.text =
                                    'Informasi kejadian dan penanganan '
                                    '${laporan['type'] ?? 'bencana'} '
                                    'berdasarkan laporan yang telah '
                                    'diselesaikan.';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Foto berita (${fotoLaporanTerpilih.length} foto laporan)',
                            style: const TextStyle(
                              color: _darkGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (laporanId == null)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Pilih laporan untuk menggunakan fotonya, '
                              'atau tambahkan foto dari galeri.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (laporanId != null)
                          Builder(
                            builder: (context) {
                              final laporan = _laporanSelesai.firstWhere(
                                (item) => item['id'].toString() == laporanId,
                              );

                              final daftarFoto = <String, String>{};

                              final fotoWarga =
                                  laporan['photo_path']?.toString().trim() ??
                                      '';

                              final fotoPetugas = laporan['handling_photo_path']
                                      ?.toString()
                                      .trim() ??
                                  '';

                              if (fotoWarga.isNotEmpty) {
                                daftarFoto[fotoWarga] = 'Foto laporan warga';
                              }

                              if (fotoPetugas.isNotEmpty) {
                                daftarFoto[fotoPetugas] =
                                    'Foto penanganan petugas';
                              }

                              if (daftarFoto.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Laporan ini belum memiliki foto.',
                                      style: TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: daftarFoto.entries.map((entry) {
                                  final pathFoto = entry.key;
                                  final namaFoto = entry.value;
                                  final dipilih =
                                      fotoLaporanTerpilih.contains(pathFoto);

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        value: dipilih,
                                        title: Text(namaFoto),
                                        onChanged: (checked) {
                                          setDialogState(() {
                                            if (checked == true) {
                                              if (!fotoLaporanTerpilih
                                                  .contains(pathFoto)) {
                                                fotoLaporanTerpilih
                                                    .add(pathFoto);
                                              }
                                            } else {
                                              fotoLaporanTerpilih
                                                  .remove(pathFoto);
                                            }
                                          });
                                        },
                                      ),
                                      if (dipilih)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: FutureBuilder<String?>(
                                            future:
                                                _ambilUrlFotoLaporan(pathFoto),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const SizedBox(
                                                  height: 100,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                );
                                              }

                                              if (snapshot.hasError ||
                                                  snapshot.data == null ||
                                                  snapshot.data!.isEmpty) {
                                                return const Text(
                                                  'Foto tidak ditemukan. Periksa path dan bucket Supabase.',
                                                  style: TextStyle(
                                                      color: Colors.red),
                                                );
                                              }

                                              return Image.network(
                                                snapshot.data!,
                                                width: double.infinity,
                                                height: 200,
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  debugPrint(
                                                      'Gagal menampilkan foto: $error');

                                                  return const Padding(
                                                    padding: EdgeInsets.all(12),
                                                    child: Text(
                                                      'Foto gagal dimuat. Periksa URL dan izin akses Storage.',
                                                      style: TextStyle(
                                                          color: Colors.red),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final hasil =
                                    await _imagePicker.pickMultiImage();

                                if (hasil.isNotEmpty) {
                                  setDialogState(() {
                                    for (final foto in hasil) {
                                      final sudahAda = fotoGaleriTerpilih.any(
                                        (item) =>
                                            item.name == foto.name &&
                                            item.path == foto.path,
                                      );

                                      if (!sudahAda) {
                                        fotoGaleriTerpilih.add(foto);
                                      }
                                    }
                                  });
                                }
                              } catch (e) {
                                _pesan(
                                  'Gagal memilih foto dari galeri.',
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.photo_library_outlined,
                            ),
                            label: const Text(
                              'Tambah Foto dari Galeri',
                            ),
                          ),
                        ),
                        if (fotoGaleriTerpilih.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${fotoGaleriTerpilih.length} foto galeri dipilih',
                              style: const TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ...fotoGaleriTerpilih.asMap().entries.map((entry) {
                            final index = entry.key;
                            final foto = entry.value;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: FutureBuilder(
                                future: foto.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        snapshot.data!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }

                                  return const SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              title: Text(
                                foto.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                tooltip: 'Hapus foto pilihan',
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    fotoGaleriTerpilih.removeAt(index);
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                        const Divider(height: 28),
                        TextFormField(
                          controller: judulController,
                          decoration: const InputDecoration(
                            labelText: 'Judul berita',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Judul wajib diisi.'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: ringkasanController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Ringkasan berita',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Ringkasan wajib diisi.'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: isiController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Isi berita',
                            helperText:
                                'Gunakan bagian DESKRIPSI KEJADIAN, LANGKAH PENANGGULANGAN, dan STATUS PENANGANAN.',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Isi berita wajib diisi.'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: kategori,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                          ),
                          items: _kategoriList.map((item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                kategori = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: lokasiController,
                          decoration: const InputDecoration(
                            labelText: 'Lokasi (opsional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: sumber,
                          decoration: const InputDecoration(
                            labelText: 'Sumber berita',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ResQ',
                              child: Text('ResQ'),
                            ),
                            DropdownMenuItem(
                              value: 'Petugas ResQ',
                              child: Text('Petugas ResQ'),
                            ),
                            DropdownMenuItem(
                              value: 'Laporan masyarakat',
                              child: Text('Laporan masyarakat'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                sumber = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Simpan Draf'),
                ),
              ],
            );
          },
        );
      },
    );

    if (berhasil == true) {
      final user = _db.auth.currentUser;

      if (user == null) {
        _pesan('Silakan login kembali.');
      } else {
        setState(() {
          _saving = true;
        });

        try {
          final List<String> semuaUrlFoto = [];

          // Ambil URL foto laporan yang dipilih.
          for (final path in fotoLaporanTerpilih) {
            final url = _urlFoto(path);

            if (url != null && !semuaUrlFoto.contains(url)) {
              semuaUrlFoto.add(url);
            }
          }

          // Unggah foto dari galeri ke Supabase Storage.
          for (int i = 0; i < fotoGaleriTerpilih.length; i++) {
            final url = await _unggahFotoBerita(
              fotoGaleriTerpilih[i],
              i,
            );

            if (!semuaUrlFoto.contains(url)) {
              semuaUrlFoto.add(url);
            }
          }

          // Simpan berita beserta semua URL fotonya.
          await _db.from('news').insert({
            'title': judulController.text.trim(),
            'image_url': semuaUrlFoto.isEmpty ? null : semuaUrlFoto.first,
            'image_urls': semuaUrlFoto,
            'summary': ringkasanController.text.trim(),
            'content': isiController.text.trim(),
            'category': kategori,
            'source': sumber,
            'location': lokasiController.text.trim().isEmpty
                ? null
                : lokasiController.text.trim(),
            'author_id': user.id,
            'status': 'Menunggu verifikasi',
            'is_published': false,
            'published_at': DateTime.now().toUtc().toIso8601String(),
          });

          _pesan('Draf berita berhasil disimpan.');
          await _loadData();
        } catch (e) {
          _pesan('Gagal menyimpan berita: $e');
        } finally {
          if (mounted) {
            setState(() {
              _saving = false;
            });
          }
        }
      }
    }

    judulController.dispose();
    ringkasanController.dispose();
    isiController.dispose();
    lokasiController.dispose();
  }

  Future<void> _setujuiBerita(
    Map<String, dynamic> berita,
  ) async {
    try {
      await _db.from('news').update({
        'status': 'Disetujui',
        'is_published': true,
        'published_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', berita['id']);

      _pesan('Berita berhasil diterbitkan.');
      await _loadData();
    } catch (e) {
      _pesan('Gagal menerbitkan berita: $e');
    }
  }

  Future<void> _batalkanPublikasi(
    Map<String, dynamic> berita,
  ) async {
    try {
      await _db.from('news').update({
        'is_published': false,
      }).eq('id', berita['id']);

      _pesan('Publikasi berita dibatalkan.');
      await _loadData();
    } catch (e) {
      _pesan('Gagal mengubah publikasi: $e');
    }
  }

  Future<void> _hapusBerita(
    Map<String, dynamic> berita,
  ) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus berita?'),
        content: Text(
          'Berita "${berita['title']}" akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    try {
      await _db.from('news').delete().eq('id', berita['id']);

      _pesan('Berita berhasil dihapus.');
      await _loadData();
    } catch (e) {
      _pesan('Gagal menghapus berita: $e');
    }
  }

  void _pesan(String pesan) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan)),
    );
  }

  Color _warnaStatus(String status) {
    if (status == 'Disetujui') return _green;
    if (status == 'Ditolak') return Colors.red;
    return _orange;
  }

  Widget _placeholderFotoBerita() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFE5EDE4),
            Color(0xFFF7F5EF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            size: 42,
            color: _green,
          ),
          SizedBox(height: 8),
          Text(
            'ResQ',
            style: TextStyle(
              color: _darkGreen,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Informasi dan Penanganan Bencana',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gambarBerita(dynamic nilai) {
    return FutureBuilder<String?>(
      future: _urlTampilanFoto(nilai),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 150,
            child: Center(
              child: CircularProgressIndicator(color: _green),
            ),
          );
        }

        final url = snapshot.data;

        if (url == null || url.isEmpty) {
          return _placeholderFotoBerita();
        }

        return Image.network(
          url,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Gagal menampilkan foto berita: $error');
            return _placeholderFotoBerita();
          },
        );
      },
    );
  }

  Future<void> _lihatDetailBerita(
    Map<String, dynamic> berita,
  ) async {
    final fotoBerita = _daftarFotoBerita(berita);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _background,
          title: Text(
            berita['title']?.toString() ?? 'Detail Berita',
            style: const TextStyle(
              color: _darkGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (fotoBerita.isNotEmpty) ...[
                    const Text(
                      'Foto Berita',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...fotoBerita.map(
                      (foto) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _gambarBerita(foto),
                        ),
                      ),
                    ),
                  ] else
                    const Text('Belum ada foto berita.'),
                  const Divider(height: 24),
                  const Text(
                    'Ringkasan',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(berita['summary']?.toString() ?? '-'),
                  const SizedBox(height: 16),
                  const Text(
                    'Isi Berita',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(berita['content']?.toString() ?? '-'),
                  const SizedBox(height: 16),
                  Text('Kategori: ${berita['category'] ?? '-'}'),
                  Text('Sumber: ${berita['source'] ?? '-'}'),
                  Text('Lokasi: ${berita['location'] ?? '-'}'),
                  Text('Status: ${berita['status'] ?? '-'}'),
                  Text(
                    'Publikasi: '
                    '${berita['is_published'] == true ? 'Sudah terbit' : 'Belum terbit'}',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final menunggu = _berita
        .where(
          (item) => item['status'] == 'Menunggu verifikasi',
        )
        .length;

    final terbit = _berita
        .where(
          (item) =>
              item['status'] == 'Disetujui' && item['is_published'] == true,
        )
        .length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Kelola Berita',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _darkGreen,
        actions: [
          IconButton(
            onPressed: _loadData,
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _buatBerita,
        backgroundColor: _green,
        foregroundColor: Colors.white,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: Text(_saving ? 'Menyimpan...' : 'Buat Berita'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _green),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          'Total Berita',
                          _berita.length,
                          Icons.newspaper,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          'Menunggu',
                          menunggu,
                          Icons.hourglass_empty,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          'Terbit',
                          terbit,
                          Icons.check_circle_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Daftar Berita',
                    style: TextStyle(
                      color: _darkGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_berita.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Belum ada berita. Tekan Buat Berita untuk mulai.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ..._berita.map((berita) {
                    final status =
                        berita['status']?.toString() ?? 'Tidak diketahui';
                    final published = berita['is_published'] == true;

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                          color: Color(0xFFEAE7DE),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _gambarBerita(berita['image_url']),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        berita['title']?.toString() ??
                                            'Tanpa judul',
                                        style: const TextStyle(
                                          color: _darkGreen,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'publish') {
                                          _setujuiBerita(berita);
                                        } else if (value == 'unpublish') {
                                          _batalkanPublikasi(berita);
                                        } else if (value == 'delete') {
                                          _hapusBerita(berita);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (!published)
                                          const PopupMenuItem(
                                            value: 'publish',
                                            child: Text(
                                              'Setujui & terbitkan',
                                            ),
                                          ),
                                        if (published)
                                          const PopupMenuItem(
                                            value: 'unpublish',
                                            child: Text(
                                              'Batalkan publikasi',
                                            ),
                                          ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Hapus berita'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  berita['summary']?.toString() ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _lihatDetailBerita(berita),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text('Lihat Detail'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _green,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Chip(
                                      label: Text(status),
                                      labelStyle: TextStyle(
                                        color: _warnaStatus(status),
                                        fontSize: 12,
                                      ),
                                      backgroundColor:
                                          _warnaStatus(status).withAlpha(25),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Chip(
                                      label: Text(
                                        published
                                            ? 'Sudah terbit'
                                            : 'Belum terbit',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                Text(
                                  '${berita['category'] ?? 'Lainnya'}'
                                  ' · ${berita['source'] ?? 'ResQ'}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _statCard(
    String judul,
    int jumlah,
    IconData ikon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: _green, size: 22),
          const SizedBox(height: 8),
          Text(
            '$jumlah',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _darkGreen,
            ),
          ),
          Text(
            judul,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
