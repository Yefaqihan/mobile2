import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/official_disaster_service.dart';
import 'detail_berita_screen.dart';

const Color _background = Color(0xFFF7F5EF);
const Color _darkGreen = Color(0xFF26382B);
const Color _green = Color(0xFF4F7D58);
const Color _orange = Color(0xFFE58B3D);

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  final OfficialDisasterService _officialService = OfficialDisasterService();
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = const [
    'Semua',
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

  String _selectedCategory = 'Semua';
  String _searchText = '';
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _communityNews = [];
  OfficialDisasterNews? _earthquake;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNews() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    debugPrint('RESQ: MULAI MEMUAT HALAMAN BERITA');

    try {
      final berita = await _loadCommunityNews();

      if (!mounted) return;

      setState(() {
        _communityNews = berita;
      });

      debugPrint('RESQ: ${berita.length} berita berhasil dimuat');
    } catch (e, stackTrace) {
      debugPrint('RESQ: GAGAL MEMUAT BERITA: $e');
      debugPrint('$stackTrace');

      if (mounted) {
        setState(() {
          _error = 'Berita gagal dimuat. Periksa koneksi dan akses Supabase.';
        });
      }
    }

    try {
      final gempa = await _officialService.getLatestEarthquake();

      if (!mounted) return;

      setState(() {
        _earthquake = gempa;
      });
    } catch (e) {
      debugPrint('RESQ: Gagal memuat informasi gempa: $e');
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    debugPrint('RESQ: PEMUATAN HALAMAN BERITA SELESAI');
  }

  Future<List<Map<String, dynamic>>> _loadCommunityNews() async {
    try {
      final response = await _db
          .from('news')
          .select()
          .eq('is_published', true)
          .eq('status', 'Disetujui')
          .order('published_at', ascending: false);

      final berita = List<Map<String, dynamic>>.from(response);

      debugPrint('JUMLAH BERITA: ${berita.length}');

      return berita;
    } catch (e, stackTrace) {
      debugPrint('ERROR LOAD BERITA: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  List<Map<String, dynamic>> get _filteredNews {
    return _communityNews.where((news) {
      final category = news['category']?.toString() ?? 'Lainnya';
      final title = news['title']?.toString() ?? '';
      final summary = news['summary']?.toString() ?? '';
      final location = news['location']?.toString() ?? '';

      final matchesCategory = _selectedCategory == 'Semua' ||
          category.toLowerCase() == _selectedCategory.toLowerCase();

      final query = _searchText.toLowerCase();

      final matchesSearch = query.isEmpty ||
          title.toLowerCase().contains(query) ||
          summary.toLowerCase().contains(query) ||
          location.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  bool get _showEarthquake {
    if (_earthquake == null) return false;

    final matchesCategory =
        _selectedCategory == 'Semua' || _selectedCategory == 'Gempa Bumi';

    final query = _searchText.toLowerCase();

    final matchesSearch = query.isEmpty ||
        _earthquake!.title.toLowerCase().contains(query) ||
        _earthquake!.summary.toLowerCase().contains(query) ||
        _earthquake!.location.toLowerCase().contains(query);

    return matchesCategory && matchesSearch;
  }

  @override
  Widget build(BuildContext context) {
    final news = _filteredNews;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _darkGreen,
        elevation: 0,
        title: const Text(
          'Berita Bencana',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loadNews,
            tooltip: 'Muat ulang berita',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNews,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSearch(),
            const SizedBox(height: 20),
            const Text(
              'Kategori',
              style: TextStyle(
                color: _darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            _buildCategories(),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Informasi terbaru',
                    style: TextStyle(
                      color: _darkGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (!_loading)
                  Text(
                    '${news.length + (_showEarthquake ? 1 : 0)} berita',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null) _buildError(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(
                    color: _green,
                  ),
                ),
              )
            else ...[
              if (_showEarthquake) _buildEarthquakeCard(_earthquake!),
              ...news.map(_buildCommunityCard),
              if (!_showEarthquake && news.isEmpty) _buildEmptyState(),
            ],
            const SizedBox(height: 16),
            _buildOfficialSource(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _darkGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.public,
            color: Color(0xFFD9E8D7),
            size: 32,
          ),
          SizedBox(height: 12),
          Text(
            'Tetap terinformasi, tetap siaga.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Pantau informasi kebencanaan resmi dan berita dari komunitas ResQ.',
            style: TextStyle(
              color: Color(0xFFE2E9DF),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchText = value.trim();
        });
      },
      decoration: InputDecoration(
        hintText: 'Cari judul, lokasi, atau informasi...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final selected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: selected,
              selectedColor: _green,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : _darkGreen,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedCategory = category;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEarthquakeCard(OfficialDisasterNews news) {
    return _newsCard(
      category: news.category,
      title: news.title,
      summary: news.summary,
      location: news.location,
      date: news.date,
      source: 'BMKG · Sumber resmi',
      icon: Icons.public,
      color: _orange,
      onTap: () {
        _openDetail(
          title: news.title,
          category: news.category,
          summary: news.summary,
          content: '${news.summary}\n\n'
              'Lokasi: ${news.location}\n'
              'Waktu: ${news.date}\n\n'
              'Informasi ini diambil dari feed gempa BMKG. '
              'Periksa laman resmi BMKG untuk informasi terbaru.',
          location: news.location,
          date: news.date,
          source: 'BMKG',
          sourceUrl: news.sourceUrl,
          imageUrls: const [],
        );
      },
    );
  }

  Widget _buildCommunityCard(Map<String, dynamic> news) {
    final title = news['title']?.toString() ?? 'Tanpa judul';
    final summary = news['summary']?.toString() ?? '';
    final category = news['category']?.toString() ?? 'Lainnya';
    final location = news['location']?.toString() ?? 'Umum';
    final source = news['source']?.toString() ?? 'ResQ';
    final date = news['published_at']?.toString() ?? '';
    final content = news['content']?.toString() ?? summary;
    final sourceUrl = news['source_url']?.toString();

    // Kumpulkan foto sampul dan semua foto tambahan.
    final semuaFoto = <String>[];

    void tambahFoto(dynamic nilai) {
      if (nilai == null) return;

      final foto = nilai.toString().trim();

      if (foto.isNotEmpty && !semuaFoto.contains(foto)) {
        semuaFoto.add(foto);
      }
    }

    // Foto sampul didahulukan.
    tambahFoto(news['image_url']);

    final fotoTambahan = news['image_urls'];

    if (fotoTambahan is List) {
      for (final foto in fotoTambahan) {
        tambahFoto(foto);
      }
    } else if (fotoTambahan is String && fotoTambahan.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(fotoTambahan);

        if (decoded is List) {
          for (final foto in decoded) {
            tambahFoto(foto);
          }
        } else {
          tambahFoto(fotoTambahan);
        }
      } catch (e) {
        debugPrint('Gagal membaca image_urls: $e');
        tambahFoto(fotoTambahan);
      }
    }

    final String? imageUrl = semuaFoto.isEmpty ? null : semuaFoto.first;

    return _newsCard(
      category: category,
      title: title,
      summary: summary,
      location: location,
      date: date,
      source: source,
      icon: Icons.article_outlined,
      color: _green,
      imageUrl: imageUrl,
      onTap: () {
        _openDetail(
          title: title,
          category: category,
          summary: summary,
          content: content,
          location: location,
          date: date,
          source: source,
          sourceUrl: sourceUrl,
          imageUrls: semuaFoto,
        );
      },
    );
  }

  // Membuka halaman detail berita yang baru.
  void _openDetail({
    required String title,
    required String category,
    required String summary,
    required String content,
    required String location,
    required String date,
    required String source,
    required List<String> imageUrls,
    String? sourceUrl,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailBeritaScreen(
          title: title,
          category: category,
          summary: summary,
          content: content,
          location: location,
          date: date,
          source: source,
          sourceUrl: sourceUrl,
          imageUrls: imageUrls,
        ),
      ),
    );
  }

  Widget _newsCard({
    required String category,
    required String title,
    required String summary,
    required String location,
    required String date,
    required String source,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? imageUrl,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEAE7DE)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.black38,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildNewsImage(imageUrl),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: _darkGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$source${date.isEmpty ? '' : ' · $date'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Baca selengkapnya',
                    style: TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward,
                    color: _green,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _resolveNewsImageUrl(dynamic nilai) async {
    if (nilai == null || nilai.toString().trim().isEmpty) {
      return null;
    }

    String path = nilai.toString().trim();
    final uri = Uri.tryParse(path);

    // URL eksternal langsung digunakan.
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      final bagian = uri.pathSegments;
      final posisiBucket = bagian.indexOf('report-photos');

      if (posisiBucket == -1) {
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
      debugPrint('Gagal membuat URL foto berita: $e');

      try {
        return _db.storage.from('report-photos').getPublicUrl(path);
      } catch (error) {
        debugPrint('Gagal mengambil URL publik: $error');
        return null;
      }
    }
  }

  Widget _buildNewsImage(
    String? imageUrl, {
    double height = 180,
  }) {
    Widget placeholder() {
      return Container(
        height: height,
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
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
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

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return placeholder();
    }

    return FutureBuilder<String?>(
      future: _resolveNewsImageUrl(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            width: double.infinity,
            child: const Center(
              child: CircularProgressIndicator(color: _green),
            ),
          );
        }

        final url = snapshot.data;

        if (url == null || url.isEmpty) {
          return placeholder();
        }

        return Image.network(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Foto berita gagal dimuat: $error');
            return placeholder();
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.newspaper_outlined,
            size: 44,
            color: _green,
          ),
          SizedBox(height: 12),
          Text(
            'Belum ada berita',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _darkGreen,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Belum ada berita untuk kategori atau pencarian ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFF9A4E16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFF7C4018),
              ),
            ),
          ),
          TextButton(
            onPressed: _loadNews,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialSource() {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text(
        'Sumber resmi gempa: BMKG. Informasi resmi tetap menjadi acuan; '
        'periksa kanal otoritas untuk pembaruan dan instruksi darurat.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black45,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }
}
