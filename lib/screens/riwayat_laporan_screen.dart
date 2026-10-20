import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_models.dart';
import '../services/report_service.dart';
import '../widgets/resq_widgets.dart';

class RiwayatLaporanScreen extends StatefulWidget {
  const RiwayatLaporanScreen({super.key});

  @override
  State<RiwayatLaporanScreen> createState() => _RiwayatLaporanScreenState();
}

class _RiwayatLaporanScreenState extends State<RiwayatLaporanScreen> {
  final ReportService _service = ReportService();

  static const Color _blue = resqBlue;
  static const Color _orange = resqOrange;
  static const Color _background = Color(0xFFF4F7FC);
  static const Color _border = Color(0xFFE4EAF3);
  static const Color _secondary = Color(0xFF667085);
  static const Color _green = Color(0xFF287D52);
  static const Color _red = Color(0xFFC03939);

  bool _isAdmin = false;
  String _filterStatus = 'Semua';
  String _searchQuery = '';

  final Set<String> _updatingReports = {};
  final Set<String> _expandedReports = {};

  List<Map<String, dynamic>> _officers = [];

  final List<String> _filterOptions = [
    'Semua',
    'Belum terkonfirmasi',
    'Terverifikasi',
    'Ditolak',
  ];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  // Memeriksa apakah pengguna yang masuk adalah admin.
  Future<void> _checkAdmin() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final result = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final isAdmin = result?['role']?.toString().toLowerCase() == 'admin';

      setState(() {
        _isAdmin = isAdmin;
      });

      if (isAdmin) {
        await _loadOfficers();
      }
    } catch (e) {
      debugPrint('Gagal memeriksa peran admin: $e');
    }
  }

  // Mengambil daftar petugas dari Supabase.
  Future<void> _loadOfficers() async {
    try {
      final result = await Supabase.instance.client.rpc(
        'get_petugas_list',
      );

      if (!mounted) return;

      setState(() {
        _officers = List<Map<String, dynamic>>.from(result);
      });
    } catch (e) {
      debugPrint('Gagal memuat daftar petugas: $e');
    }
  }

  // Mengubah status verifikasi laporan.
  Future<void> _updateReportStatus(
    DisasterReport report,
    String status,
  ) async {
    if (!_isAdmin) return;

    final reportId = int.tryParse(report.id);

    if (reportId == null) {
      _snack('ID laporan tidak valid.');
      return;
    }

    setState(() {
      _updatingReports.add(report.id);
    });

    try {
      await Supabase.instance.client.rpc(
        'set_report_status',
        params: {
          'p_report_id': reportId,
          'p_status': status,
        },
      );

      if (mounted) {
        _snack('Status laporan berhasil diubah menjadi $status.');
      }
    } catch (e) {
      debugPrint('Gagal mengubah status laporan: $e');

      if (mounted) {
        _snack('Gagal mengubah status. Periksa hak akses admin.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingReports.remove(report.id);
        });
      }
    }
  }

  // Menugaskan laporan kepada petugas.
  Future<void> _assignOfficer(DisasterReport report) async {
    if (!_isAdmin) return;

    if (_officers.isEmpty) {
      _snack('Belum ada akun petugas yang tersedia.');
      return;
    }

    String? selectedOfficer = _officers.first['user_id']?.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Tugaskan Petugas',
                style: TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: DropdownButtonFormField<String>(
                value: selectedOfficer,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pilih petugas',
                  border: OutlineInputBorder(),
                ),
                items: _officers.map((officer) {
                  final id = officer['user_id'].toString();

                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      'Petugas ${id.substring(0, id.length > 8 ? 8 : id.length)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedOfficer = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: selectedOfficer == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, true);
                        },
                  child: const Text('Tugaskan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedOfficer == null) return;

    final reportId = int.tryParse(report.id);

    if (reportId == null) {
      _snack('ID laporan tidak valid.');
      return;
    }

    setState(() {
      _updatingReports.add(report.id);
    });

    try {
      await Supabase.instance.client.rpc(
        'assign_report_to_officer',
        params: {
          'p_report_id': reportId,
          'p_officer_id': selectedOfficer,
        },
      );

      if (mounted) {
        _snack('Laporan berhasil ditugaskan kepada petugas.');
      }
    } catch (e) {
      debugPrint('Gagal menugaskan petugas: $e');

      if (mounted) {
        _snack(
          'Gagal menugaskan petugas. Periksa status laporan dan hak akses.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingReports.remove(report.id);
        });
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Warna status verifikasi.
  Color _verificationColor(String status) {
    switch (status.toLowerCase()) {
      case 'terverifikasi':
        return _green;
      case 'ditolak':
        return _red;
      default:
        return _orange;
    }
  }

  // Warna status penanganan.
  Color _handlingColor(String status) {
    final value = status.toLowerCase();

    if (value == 'selesai') {
      return _green;
    }

    if (value.contains('proses') || value.contains('ditangani')) {
      return _orange;
    }

    return _secondary;
  }

  // Badge status yang digunakan pada kartu.
  Widget _statusBadge(
    String text, {
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // Kartu ringkasan jumlah laporan.
  Widget _summaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: const TextStyle(
                color: _blue,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(
                color: _secondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Menghitung jumlah laporan berdasarkan status.
  int _countStatus(
    List<DisasterReport> reports,
    String status,
  ) {
    return reports
        .where(
          (report) => report.status.toLowerCase() == status.toLowerCase(),
        )
        .length;
  }

  // Mencari dan memfilter laporan.
  List<DisasterReport> _filterReports(
    List<DisasterReport> reports,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return reports.where((report) {
      final matchesStatus = _filterStatus == 'Semua' ||
          report.status.toLowerCase() == _filterStatus.toLowerCase();

      final matchesSearch = query.isEmpty ||
          report.type.toLowerCase().contains(query) ||
          report.id.toLowerCase().contains(query) ||
          report.description.toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Cari jenis, ID, atau deskripsi laporan...',
        hintStyle: const TextStyle(
          fontSize: 12,
          color: _secondary,
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: _secondary,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
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
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filterOptions.map((status) {
          final selected = _filterStatus == status;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status),
              selected: selected,
              showCheckmark: false,
              selectedColor: _blue,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? _blue : _border,
              ),
              labelStyle: TextStyle(
                color: selected ? Colors.white : _secondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              onSelected: (_) {
                setState(() {
                  _filterStatus = status;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportCard(DisasterReport report) {
    final isExpanded = _expandedReports.contains(report.id);
    final isUpdating = _updatingReports.contains(report.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Bagian ringkas yang tetap terlihat.
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedReports.remove(report.id);
                } else {
                  _expandedReports.add(report.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: _orange,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID #${report.id} • ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(report.createdAt.toLocal())}',
                          style: const TextStyle(
                            color: _secondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _statusBadge(
                          report.status,
                          color: _verificationColor(report.status),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _secondary,
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Deskripsi Bencana'),
                  const SizedBox(height: 6),
                  Text(
                    report.description,
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),

                  if (report.photoPath != null &&
                      report.photoPath!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sectionTitle('Foto Laporan Warga'),
                    _ReportPhoto(photoPath: report.photoPath),
                  ],

                  if (report.handlingPhotoPath != null &&
                      report.handlingPhotoPath!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _sectionTitle('Foto Bukti Penanganan Petugas'),
                    _ReportPhoto(
                      photoPath: report.handlingPhotoPath,
                    ),
                  ],

                  if (report.handlingNotes != null &&
                      report.handlingNotes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionTitle('Catatan Penanganan Petugas'),
                    const SizedBox(height: 5),
                    Text(
                      report.handlingNotes!,
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],

                  if (report.handlingStatus.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionTitle('Status Penanganan'),
                    const SizedBox(height: 6),
                    _statusBadge(
                      report.handlingStatus,
                      color: _handlingColor(report.handlingStatus),
                    ),
                  ],

                  const SizedBox(height: 14),
                  _sectionTitle('Lokasi Kejadian'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      'Latitude: ${report.latitude.toStringAsFixed(6)}\n'
                      'Longitude: ${report.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  _sectionTitle('Hash Verifikasi SHA-256'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      report.hash,
                      style: const TextStyle(
                        color: _secondary,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),

                  // Panel tindakan admin.
                  if (_isAdmin) ...[
                    const SizedBox(height: 18),
                    const Divider(color: _border),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: _blue,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Verifikasi Laporan',
                            style: TextStyle(
                              color: _blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (isUpdating)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _orange,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: DropdownButtonFormField<String>(
                        value: _filterOptions.skip(1).contains(report.status)
                            ? report.status
                            : 'Belum terkonfirmasi',
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Status verifikasi',
                          filled: true,
                          fillColor: _background,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _border,
                            ),
                          ),
                        ),
                        items: _filterOptions
                            .skip(1)
                            .map(
                              (status) => DropdownMenuItem<String>(
                                value: status,
                                child: Text(
                                  status,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isUpdating
                            ? null
                            : (status) {
                                if (status != null && status != report.status) {
                                  _updateReportStatus(report, status);
                                }
                              },
                      ),
                    ),
                    if (report.status == 'Terverifikasi') ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              isUpdating ? null : () => _assignOfficer(report),
                          icon: const Icon(
                            Icons.assignment_ind_outlined,
                            size: 18,
                          ),
                          label: const Text('Tugaskan Petugas'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (isUpdating) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(
                        color: _orange,
                        backgroundColor: _border,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _blue,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            color: _secondary,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _blue,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _secondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _blue,
        elevation: 0,
        title: const Text(
          'Riwayat Laporan',
          style: TextStyle(
            color: _blue,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<List<DisasterReport>>(
        stream: _service.watchReports(
          isAdmin: _isAdmin,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ResQCard(
                  child: Text(
                    'Riwayat belum bisa dimuat.\n${snapshot.error}',
                    style: const TextStyle(color: resqRed),
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _orange),
            );
          }

          final allReports = snapshot.data!;

          final sortedReports = List<DisasterReport>.from(allReports)
            ..sort(
              (a, b) => b.createdAt.compareTo(a.createdAt),
            );

          final pendingCount = _countStatus(
            allReports,
            'Belum terkonfirmasi',
          );
          final verifiedCount = _countStatus(
            allReports,
            'Terverifikasi',
          );

          final filteredReports = _filterReports(sortedReports);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // Header halaman.
              const Text(
                'PENGELOLAAN LAPORAN',
                style: TextStyle(
                  color: _orange,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Laporan Warga',
                style: TextStyle(
                  color: _blue,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Periksa laporan, verifikasi informasi, dan tugaskan petugas.',
                style: TextStyle(
                  color: _secondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),

              // Ringkasan.
              Row(
                children: [
                  _summaryCard(
                    title: 'Total laporan',
                    count: allReports.length,
                    icon: Icons.assignment_outlined,
                    color: _blue,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    title: 'Menunggu',
                    count: pendingCount,
                    icon: Icons.pending_actions_outlined,
                    color: _orange,
                  ),
                  const SizedBox(width: 10),
                  _summaryCard(
                    title: 'Terverifikasi',
                    count: verifiedCount,
                    icon: Icons.verified_outlined,
                    color: _green,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pencarian.
              _buildSearchField(),
              const SizedBox(height: 14),

              // Filter status.
              const Text(
                'Filter status verifikasi',
                style: TextStyle(
                  color: _blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _buildFilters(),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Daftar Laporan',
                      style: TextStyle(
                        color: _blue,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${filteredReports.length} laporan',
                    style: const TextStyle(
                      color: _secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (allReports.isEmpty)
                _buildEmptyState(
                  title: 'Belum ada laporan',
                  description:
                      'Laporan yang dikirim warga akan muncul di halaman ini.',
                )
              else if (filteredReports.isEmpty)
                _buildEmptyState(
                  title: 'Laporan tidak ditemukan',
                  description:
                      'Coba ubah kata pencarian atau pilih filter status lainnya.',
                )
              else
                ...filteredReports.map(_buildReportCard),
            ],
          );
        },
      ),
    );
  }
}

// Widget foto laporan dan foto bukti penanganan.
class _ReportPhoto extends StatefulWidget {
  const _ReportPhoto({required this.photoPath});

  final String? photoPath;

  @override
  State<_ReportPhoto> createState() => _ReportPhotoState();
}

class _ReportPhotoState extends State<_ReportPhoto> {
  late Future<String?> _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _ReportPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.photoPath != widget.photoPath) {
      _loadPhoto();
    }
  }

  void _loadPhoto() {
    _photoUrl = ReportService().getReportPhotoUrl(widget.photoPath);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoPath == null || widget.photoPath!.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: _photoUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Foto bukti gagal dimuat.'),
          );
        }

        final url = snapshot.data;

        if (url == null || url.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Foto bukti tidak dapat dimuat.'),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text('Gagal menampilkan foto bukti.'),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
