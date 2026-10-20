class NewsModel {
  const NewsModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.source,
    required this.publishedAt,
    this.sourceUrl,
    this.imageUrl,
    this.location,
    this.authorId,
    this.status = 'Menunggu verifikasi',
    this.isPublished = false,
  });

  final int id;
  final String title;
  final String summary;
  final String content;
  final String category;
  final String source;
  final DateTime publishedAt;
  final String? sourceUrl;
  final String? imageUrl;
  final String? location;
  final String? authorId;
  final String status;
  final bool isPublished;

  factory NewsModel.fromMap(Map<String, dynamic> map) {
    return NewsModel(
      id: (map['id'] as num).toInt(),
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      content: map['content'] as String? ?? '',
      category: map['category'] as String? ?? 'Informasi Bencana',
      source: map['source'] as String? ?? 'ResQ',
      publishedAt: DateTime.tryParse(
            map['published_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      sourceUrl: map['source_url'] as String?,
      imageUrl: map['image_url'] as String?,
      location: map['location'] as String?,
      authorId: map['author_id'] as String?,
      status: map['status'] as String? ?? 'Menunggu verifikasi',
      isPublished: map['is_published'] as bool? ?? false,
    );
  }
}
