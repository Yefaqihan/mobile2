import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../services/report_service.dart';
import '../widgets/resq_widgets.dart';
import 'package:flutter/foundation.dart';

class TugasPetugasScreen extends StatefulWidget {
  const TugasPetugasScreen({super.key});

  @override
  State<TugasPetugasScreen> createState() => _TugasPetugasScreenState();
}

class _TugasPetugasScreenState extends State<TugasPetugasScreen> {
  final ReportService _service = ReportService();
  final Set<String> _updating = {};
  final Set<String> _expanded = {};
  final Map<String, TextEditingController> _notesControllers = {};
  final Map<String, Uint8List> _handlingPhotoBytes = {};
  final Map<String, String> _handlingPhotoExtensions = {};
  String _filterStatus = 'Semua';
  String _searchQuery = '';

  static const Color _blue = resqBlue;
  static const Color _orange = resqOrange;
  static const Color _background = Color(0xFFF4F7FC);
  static const Color _border = Color(0xFFE4EAF3);
  static const Color _textSecondary = Color(0xFF667085);

  Future<void> _saveHandlingNotes(DisasterReport report) async {
    final controller = _notesControllers.putIfAbsent(
      report.id,
      () => TextEditingController(text: report.handlingNotes),
    );

    final notes = controller.text.trim();

    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan penanganan tidak boleh kosong.'),
        ),
      );
      return;
    }

    setState(() => _updating.add(report.id));

    try {
      await _service.updateHandlingNotes(
        reportId: report.id,
        notes: notes,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan penanganan berhasil disimpan.'),
          backgroundColor: Color(0xFF287D52),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan catatan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updating.remove(report.id));
      }
    }
  }

  Future<void> _pickHandlingPhoto(DisasterReport report) async {
    try {
      final picker = ImagePicker();

      final file = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Foto tidak dapat dibaca.');
      }

      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Ukuran foto maksimal 5 MB.');
      }

      final extension = file.name.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('Gunakan foto JPG, JPEG, PNG, atau WebP.');
      }

      if (!mounted) return;

      setState(() {
        _handlingPhotoBytes[report.id] = bytes;
        _handlingPhotoExtensions[report.id] = extension;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih foto: $e'),
        ),
      );
    }
  }

  Future<void> _uploadHandlingPhoto(DisasterReport report) async {
    final bytes = _handlingPhotoBytes[report.id];
    final extension = _handlingPhotoExtensions[report.id];
    final user = Supabase.instance.client.auth.currentUser;

    if (bytes == null || extension == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih foto bukti terlebih dahulu.'),
        ),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi login berakhir. Silakan login kembali.'),
        ),
      );
      return;
    }

    setState(() => _updating.add(report.id));

    try {
      final uploadedPath = await _service.uploadHandlingPhoto(
        userId: user.id,
        reportId: report.id,
        bytes: bytes,
        extension: extension,
      );

      await _service.saveHandlingPhotoPath(
        reportId: report.id,
        photoPath: uploadedPath,
      );

      if (!mounted) return;

      setState(() {
        _handlingPhotoBytes.remove(report.id);
        _handlingPhotoExtensions.remove(report.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto bukti penanganan berhasil disimpan.'),
          backgroundColor: Color(0xFF287D52),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan foto bukti: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updating.remove(report.id));
      }
    }
  }

  Future<void> _openNavigation(DisasterReport report) async {
    final latitude = report.latitude;
    final longitude = report.longitude;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka navigasi.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka navigasi.'),
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(
    DisasterReport report,
    String status,
  ) async {
    final controller = _notesControllers.putIfAbsent(
      report.id,
      () => TextEditingController(text: report.handlingNotes),
    );

    setState(() => _updating.add(report.id));

    try {
      await Supabase.instance.client.rpc(
        'update_report_handling',
        params: {
          'p_report_id': int.parse(report.id),
          'p_handling_status': status,
          'p_handling_notes': controller.text.trim(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status berhasil diubah menjadi $status'),
          backgroundColor: const Color(0xFF287D52),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updating.remove(report.id));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Selesai':
        return const Color(0xFF287D52);
      case 'Sedang ditangani':
        return const Color(0xFFB66A12);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _verificationColor(String status) {
    if (status == 'Terverifikasi') {
      return const Color(0xFF287D52);
    }

    if (status == 'Ditolak') {
      return Colors.red.shade700;
    }

    return const Color(0xFF64748B);
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 7),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _blue,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(DisasterReport report) {
    final isUpdating = _updating.contains(report.id);
    final isExpanded = _expanded.contains(report.id);
    final statusColor = _statusColor(report.handlingStatus);

    final date = DateFormat(
      'dd MMM yyyy, HH:mm',
      'id_ID',
    ).format(report.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expanded.remove(report.id);
                } else {
                  _expanded.add(report.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.crisis_alert_rounded,
                      color: _orange,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Laporan #${report.id} • $date',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7A8492),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: _statusBadge(
                      report.handlingStatus,
                      statusColor,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _blue,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DESKRIPSI LAPORAN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF89919D),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _background,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      report.description.isEmpty
                          ? 'Tidak ada deskripsi laporan.'
                          : report.description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF46505D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'Verifikasi:',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                      _statusBadge(
                        report.status,
                        _verificationColor(report.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LOKASI KEJADIAN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: SizedBox(
                      height: 190,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            report.latitude,
                            report.longitude,
                          ),
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.resq',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  report.latitude,
                                  report.longitude,
                                ),
                                width: 45,
                                height: 45,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: _orange,
                                  size: 42,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Koordinat: ${report.latitude}, ${report.longitude}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openNavigation(report),
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Buka Navigasi Google Maps'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side: const BorderSide(color: _blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  const Text(
                    'CATATAN PENANGANAN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('notes_${report.id}'),
                    controller: _notesControllers.putIfAbsent(
                      report.id,
                      () => TextEditingController(
                        text: report.handlingNotes,
                      ),
                    ),
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText:
                          'Tuliskan tindakan, kondisi lokasi, atau bantuan yang diberikan...',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          isUpdating ? null : () => _saveHandlingNotes(report),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Simpan Catatan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // FOTO BUKTI PENANGANAN
                  const Text(
                    'FOTO BUKTI PENANGANAN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Pratinjau foto yang belum diunggah
                  if (_handlingPhotoBytes.containsKey(report.id)) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _handlingPhotoBytes[report.id]!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Foto bukti yang sudah tersimpan

                  if (report.handlingPhotoPath != null &&
                      report.handlingPhotoPath!.trim().isNotEmpty) ...[
                    FutureBuilder<String?>(
                      key: ValueKey(report.handlingPhotoPath),
                      future: _service.getReportPhotoUrl(
                        report.handlingPhotoPath,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final imageUrl = snapshot.data;

                        if (imageUrl == null || imageUrl.isEmpty) {
                          return const Text(
                            'Foto bukti tidak dapat ditemukan atau diakses.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          );
                        }

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Text(
                                'Foto bukti gagal dimuat.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          isUpdating ? null : () => _pickHandlingPhoto(report),
                      icon: const Icon(Icons.add_a_photo_rounded),
                      label: Text(
                        _handlingPhotoBytes.containsKey(report.id)
                            ? 'Ganti Foto Bukti'
                            : 'Pilih Foto Bukti',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side: const BorderSide(color: _blue),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUpdating ||
                              !_handlingPhotoBytes.containsKey(report.id)
                          ? null
                          : () => _uploadHandlingPhoto(report),
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: const Text('Simpan Foto Bukti'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'STATUS PENANGANAN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),

                  const SizedBox(height: 7),
                  DropdownButtonFormField<String>(
                    initialValue: const [
                      'Belum ditangani',
                      'Sedang ditangani',
                      'Selesai',
                    ].contains(report.handlingStatus)
                        ? report.handlingStatus
                        : 'Belum ditangani',
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(
                          color: _blue,
                          width: 1.5,
                        ),
                      ),
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'Belum ditangani',
                        child: Text('Belum ditangani'),
                      ),
                      DropdownMenuItem(
                        value: 'Sedang ditangani',
                        child: Text('Sedang ditangani'),
                      ),
                      DropdownMenuItem(
                        value: 'Selesai',
                        child: Text('Selesai'),
                      ),
                    ],
                    onChanged: isUpdating
                        ? null
                        : (value) {
                            if (value != null &&
                                value != report.handlingStatus) {
                              _updateStatus(report, value);
                            }
                          },
                  ),
                  if (isUpdating) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(
                      color: _orange,
                      minHeight: 3,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Menyimpan perubahan...',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Silakan login kembali.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _blue,
        elevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tugas Penanganan',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Kelola laporan bencana yang ditugaskan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: Color(0xFF7A8492),
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<DisasterReport>>(
        stream: _service.watchReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 44,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Laporan gagal dimuat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Periksa koneksi internet, lalu coba lagi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _textSecondary),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {}),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _blue),
            );
          }

          final allReports = snapshot.data!
              .where((report) => report.assignedTo == user.id)
              .toList()
            ..sort(
              (a, b) => b.createdAt.compareTo(a.createdAt),
            );

          final pending = allReports
              .where((r) => r.handlingStatus == 'Belum ditangani')
              .length;

          final inProgress = allReports
              .where((r) => r.handlingStatus == 'Sedang ditangani')
              .length;

          final completed =
              allReports.where((r) => r.handlingStatus == 'Selesai').length;

          final query = _searchQuery.trim().toLowerCase();

          final reports = allReports.where((report) {
            final matchesStatus = _filterStatus == 'Semua' ||
                report.handlingStatus == _filterStatus;

            final matchesSearch = query.isEmpty ||
                report.type.toLowerCase().contains(query) ||
                report.id.toLowerCase().contains(query) ||
                report.description.toLowerCase().contains(query);

            return matchesStatus && matchesSearch;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.15),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ringkasan Tugas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Pantau dan perbarui laporan yang ditugaskan.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.assignment_turned_in_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _summaryCard(
                    title: 'Belum ditangani',
                    count: pending,
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  _summaryCard(
                    title: 'Diproses',
                    count: inProgress,
                    icon: Icons.autorenew_rounded,
                    color: _orange,
                  ),
                  const SizedBox(width: 8),
                  _summaryCard(
                    title: 'Selesai',
                    count: completed,
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF287D52),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: 'Cari jenis, ID, atau deskripsi laporan...',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF89919D),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _blue,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _blue,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'Semua',
                    'Belum ditangani',
                    'Sedang ditangani',
                    'Selesai',
                  ].map((status) {
                    final selected = _filterStatus == status;

                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _filterStatus = status);
                        },
                        selectedColor: _blue.withValues(alpha: 0.10),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected ? _blue : _border,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? _blue : _textSecondary,
                        ),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Daftar Laporan',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _blue,
                      ),
                    ),
                  ),
                  Text(
                    '${reports.length} dari ${allReports.length} tugas',
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (reports.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 30,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.assignment_outlined,
                        size: 44,
                        color: Color(0xFFB0B8C3),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        allReports.isEmpty
                            ? 'Belum Ada Tugas'
                            : 'Laporan Tidak Ditemukan',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _blue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        allReports.isEmpty
                            ? 'Laporan yang ditugaskan oleh admin akan muncul di sini.'
                            : 'Coba ubah kata pencarian atau filter status.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF7A8492),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...reports.map(_buildReportCard),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
