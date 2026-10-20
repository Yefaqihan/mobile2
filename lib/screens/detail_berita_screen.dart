import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _background = Color(0xFFF7F5EF);
const Color _darkGreen = Color(0xFF26382B);
const Color _green = Color(0xFF4F7D58);
const Color _muted = Color(0xFF777970);
const Color _line = Color(0xFFE6E4DB);

class DetailBeritaScreen extends StatefulWidget {
  final String title;
  final String category;
  final String summary;
  final String content;
  final String location;
  final String date;
  final String source;
  final String? sourceUrl;
  final List<String> imageUrls;

  const DetailBeritaScreen({
    super.key,
    required this.title,
    required this.category,
    required this.summary,
    required this.content,
    required this.location,
    required this.date,
    required this.source,
    this.sourceUrl,
    this.imageUrls = const [],
  });

  @override
  State<DetailBeritaScreen> createState() => _DetailBeritaScreenState();
}

class _DetailBeritaScreenState extends State<DetailBeritaScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  final PageController _pageController = PageController();
  final Map<String, Future<String?>> _imageCache = {};

  int _currentImage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<String?> _resolveImageUrl(String value) {
    return _imageCache.putIfAbsent(
      value,
      () => _loadImageUrl(value),
    );
  }

  Future<String?> _loadImageUrl(String value) async {
    String path = value.trim();

    if (path.isEmpty) return null;

    final uri = Uri.tryParse(path);

    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('report-photos');

      // Gambar dari luar Supabase.
      if (bucketIndex == -1) return path;

      if (bucketIndex + 1 >= segments.length) return null;

      path = segments.skip(bucketIndex + 1).join('/');
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
      debugPrint('Gagal membuat URL gambar: $e');

      try {
        return _db.storage.from('report-photos').getPublicUrl(path);
      } catch (_) {
        return null;
      }
    }
  }

  String _formatDate(String value) {
    if (value.trim().isEmpty) {
      return 'Tanggal tidak tersedia';
    }

    final date = DateTime.tryParse(value);

    if (date == null) return value;

    final localDate = date.toLocal();

    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${localDate.day} ${months[localDate.month - 1]} '
        '${localDate.year}';
  }

  String _cleanText(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }

  String _plainTitle(String value) {
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 20, 6),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Kembali',
              color: _darkGreen,
            ),
            const SizedBox(width: 6),
            const Text(
              'Berita dan Informasi',
              style: TextStyle(
                color: _darkGreen,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery() {
    if (widget.imageUrls.isEmpty) {
      return _buildImagePlaceholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentImage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildImage(widget.imageUrls[index]);
                  },
                ),
              ),
              if (widget.imageUrls.length > 1)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_currentImage + 1}/${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.imageUrls.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = _currentImage == index;

                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: selected ? _green : _line,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildImage(widget.imageUrls[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImage(String value) {
    return FutureBuilder<String?>(
      future: _resolveImageUrl(value),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: const Color(0xFFE9EAE3),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _green,
                ),
              ),
            ),
          );
        }

        final url = snapshot.data;

        if (url == null || url.isEmpty) {
          return _buildImagePlaceholder();
        }

        return Image.network(
          url,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder();
          },
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 220,
      color: const Color(0xFFE9EAE3),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            color: _green,
            size: 36,
          ),
          SizedBox(height: 8),
          Text(
            'Foto belum tersedia',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Column(
      children: [
        _buildMetadataRow(
          Icons.location_on_outlined,
          'Lokasi',
          widget.location,
        ),
        const Padding(
          padding: EdgeInsets.only(left: 30),
          child: Divider(height: 20, color: _line),
        ),
        _buildMetadataRow(
          Icons.calendar_today_outlined,
          'Tanggal',
          _formatDate(widget.date),
        ),
        if (widget.source.trim().isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 30),
            child: Divider(height: 20, color: _line),
          ),
          _buildMetadataRow(
            Icons.article_outlined,
            'Sumber',
            widget.source,
          ),
        ],
      ],
    );
  }

  Widget _buildMetadataRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _green),
        const SizedBox(width: 10),
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value.trim(),
            style: const TextStyle(
              color: _darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArticleHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: _darkGreen,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildArticleText(String text) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      text.trim(),
      style: const TextStyle(
        color: Color(0xFF41443E),
        fontSize: 14,
        height: 1.8,
      ),
      textAlign: TextAlign.start,
    );
  }

  List<Map<String, String>> _parseSections() {
    final content = _cleanText(widget.content);

    if (content.isEmpty) return [];

    final pattern = RegExp(
      r'^(DESKRIPSI KEJADIAN|LANGKAH PENANGGULANGAN|'
      r'STATUS PENANGANAN|DOKUMENTASI PETUGAS)\s*:?\s*$',
      multiLine: true,
      caseSensitive: false,
    );

    final matches = pattern.allMatches(content).toList();

    if (matches.isEmpty) {
      return [
        {
          'title': 'Informasi lengkap',
          'body': content,
        },
      ];
    }

    final sections = <Map<String, String>>[];

    // Teks sebelum judul bagian pertama tetap ditampilkan.
    final firstHeadingStart = matches.first.start;
    final beforeHeading = content.substring(0, firstHeadingStart).trim();

    if (beforeHeading.isNotEmpty) {
      sections.add({
        'title': 'Informasi lengkap',
        'body': beforeHeading,
      });
    }

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final end =
          i + 1 < matches.length ? matches[i + 1].start : content.length;

      final body = content.substring(match.end, end).trim();

      if (body.isEmpty) continue;

      sections.add({
        'title': _plainTitle(match.group(1) ?? 'Informasi'),
        'body': body,
      });
    }

    return sections;
  }

  Widget _buildArticleContent() {
    final summary = _cleanText(widget.summary);
    final content = _cleanText(widget.content);

    // Hindari mengulang ringkasan jika isi berita sama.
    final showSummary =
        summary.isNotEmpty && summary.toLowerCase() != content.toLowerCase();

    final sections = _parseSections();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSummary) ...[
          _buildArticleHeading('Ringkasan'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: _green,
                  width: 3,
                ),
              ),
            ),
            child: _buildArticleText(summary),
          ),
          const SizedBox(height: 28),
        ],
        _buildArticleHeading(
          showSummary ? 'Informasi lengkap' : 'Informasi berita',
        ),
        if (sections.isEmpty)
          _buildArticleText(
            summary.isNotEmpty ? summary : 'Belum ada isi berita.',
          )
        else
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sections.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        section['title']!,
                        style: const TextStyle(
                          color: _green,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  _buildArticleText(section['body']!),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSourceLink() {
    final url = widget.sourceUrl?.trim() ?? '';

    if (url.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _line),
          bottom: BorderSide(color: _line),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.link,
            color: _green,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tautan sumber',
                  style: TextStyle(
                    color: _darkGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  url,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 13,
                    height: 1.5,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
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
      body: Column(
        children: [
          Container(
            color: _background,
            child: _buildTopBar(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              children: [
                _buildGallery(),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EADF),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      widget.category.trim().isEmpty
                          ? 'BERITA'
                          : widget.category.toUpperCase(),
                      style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 26,
                    height: 1.28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildMetadata(),
                const SizedBox(height: 26),
                const Divider(height: 1, color: _line),
                const SizedBox(height: 24),
                _buildArticleContent(),
                const SizedBox(height: 12),
                _buildSourceLink(),
                const SizedBox(height: 26),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _darkGreen,
                    side: const BorderSide(color: _line),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Kembali ke daftar berita',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
