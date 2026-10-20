import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/news_model.dart';

class NewsService {
  NewsService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  Future<void> submitNews({
    required String title,
    required String summary,
    required String content,
    required String category,
    required String source,
    String? sourceUrl,
    String? imageUrl,
    String? location,
  }) async {
    final user = _db.auth.currentUser;

    if (user == null) {
      throw Exception('Silakan login terlebih dahulu.');
    }

    await _db.from('news').insert({
      'title': title.trim(),
      'summary': summary.trim(),
      'content': content.trim(),
      'category': category,
      'source': source.trim().isEmpty ? 'ResQ' : source.trim(),
      'source_url': _emptyToNull(sourceUrl),
      'image_url': _emptyToNull(imageUrl),
      'location': _emptyToNull(location),
      'author_id': user.id,
      'status': 'Menunggu verifikasi',
      'is_published': false,
    });
  }

  Stream<List<NewsModel>> watchPublishedNews() {
    return _db
        .from('news')
        .stream(primaryKey: ['id'])
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .map(
          (rows) => rows
              .where((row) => row['status'] == 'Disetujui')
              .map((row) => NewsModel.fromMap(row))
              .toList(),
        );
  }

  Future<List<NewsModel>> getMyNews() async {
    final user = _db.auth.currentUser;

    if (user == null) {
      throw Exception('Silakan login terlebih dahulu.');
    }

    final rows = await _db
        .from('news')
        .select()
        .eq('author_id', user.id)
        .order('created_at', ascending: false);

    return rows.map<NewsModel>((row) => NewsModel.fromMap(row)).toList();
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
