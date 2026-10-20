import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/app_models.dart';

class ReportService {
  ReportService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  static const String photoBucket = 'report-photos';

  String createHash({
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required String type,
    required String description,
  }) {
    final canonical = '${timestamp.toUtc().toIso8601String()}|'
        '${latitude.toStringAsFixed(6)}|'
        '${longitude.toStringAsFixed(6)}|'
        '$type|${description.trim()}';

    return sha256.convert(utf8.encode(canonical)).toString();
  }

  Stream<List<DisasterReport>> watchReports({
    bool isAdmin = false,
  }) {
    final currentUserId = _db.auth.currentUser?.id;

    if (!isAdmin && currentUserId == null) {
      return Stream.value(<DisasterReport>[]);
    }

    return _db
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) {
          final filteredRows = isAdmin
              ? rows
              : rows.where(
                  (row) => row['user_id']?.toString() == currentUserId,
                );

          return filteredRows.map((row) {
            return DisasterReport.fromMap(
              row['id'].toString(),
              {
                'type': row['type'],
                'description': row['description'],
                'latitude': row['latitude'],
                'longitude': row['longitude'],
                'created_at': row['created_at'],
                'hash': row['hash'],
                'status': row['status'],
                'user_id': row['user_id'],
                'photo_path': row['photo_path'],
                'assigned_to': row['assigned_to'],
                'handling_status': row['handling_status'],
                'handling_notes': row['handling_notes'],
                'handled_at': row['handled_at'],
                'handling_photo_path': row['handling_photo_path'],
              },
            );
          }).toList();
        });
  }

  Future<String> uploadReportPhoto({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final safeExtension = extension.toLowerCase().replaceAll('.', '');

    if (!['jpg', 'jpeg', 'png', 'webp'].contains(safeExtension)) {
      throw Exception('Format foto harus JPG, JPEG, PNG, atau WebP.');
    }

    if (bytes.isEmpty) {
      throw Exception('File foto kosong.');
    }

    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('Ukuran foto maksimal 5 MB.');
    }

    final fileName =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.$safeExtension';

    final path = '$userId/$fileName';

    await _db.storage.from(photoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: switch (safeExtension) {
              'jpg' || 'jpeg' => 'image/jpeg',
              'png' => 'image/png',
              'webp' => 'image/webp',
              _ => 'application/octet-stream',
            },
            upsert: false,
          ),
        );

    return path;
  }

  Future<String?> getReportPhotoUrl(String? photoPath) async {
    if (photoPath == null || photoPath.trim().isEmpty) {
      return null;
    }

    final path = photoPath.trim().replaceAll('\\', '/');

    try {
      final supabase = Supabase.instance.client;

      final url = await supabase.storage
          .from('report-photos')
          .createSignedUrl(path, 3600);

      return url;
    } on StorageException catch (e) {
      debugPrint(
        'Gagal membuat signed URL foto: '
        'status=${e.statusCode}, pesan=${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('Gagal memuat foto: $e');
      return null;
    }
  }

  Future<void> deleteReportPhoto(String path) async {
    await _db.storage.from(photoBucket).remove([path]);
  }

  Future<void> updateHandlingNotes({
    required String reportId,
    required String notes,
  }) async {
    await _db.rpc(
      'update_report_handling',
      params: {
        'p_report_id': int.parse(reportId),
        'p_handling_status': 'Sedang ditangani',
        'p_handling_notes': notes.trim(),
      },
    );
  }

  Future<String> uploadHandlingPhoto({
    required String userId,
    required String reportId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final safeExtension = extension.toLowerCase().replaceAll('.', '');

    if (!['jpg', 'jpeg', 'png', 'webp'].contains(safeExtension)) {
      throw Exception('Format foto harus JPG, JPEG, PNG, atau WebP.');
    }

    if (bytes.isEmpty) {
      throw Exception('File foto kosong.');
    }

    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('Ukuran foto maksimal 5 MB.');
    }

    final fileName =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.$safeExtension';

    // Folder userId mengikuti pola upload foto laporan yang sudah ada.
    final path = '$userId/handling/$reportId/$fileName';

    await _db.storage.from(photoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: switch (safeExtension) {
              'jpg' || 'jpeg' => 'image/jpeg',
              'png' => 'image/png',
              'webp' => 'image/webp',
              _ => 'application/octet-stream',
            },
            upsert: false,
          ),
        );

    return path;
  }

  Future<void> saveHandlingPhotoPath({
    required String reportId,
    required String photoPath,
  }) async {
    await _db.rpc(
      'update_report_handling_photo',
      params: {
        'p_report_id': int.parse(reportId),
        'p_handling_photo_path': photoPath,
      },
    );
  }

  Future<void> submit({
    required String type,
    required String description,
    required double latitude,
    required double longitude,
    required String userId,
    required String photoPath,
  }) async {
    final now = DateTime.now().toUtc();

    final hash = createHash(
      timestamp: now,
      latitude: latitude,
      longitude: longitude,
      type: type,
      description: description,
    );

    await _db.from('reports').insert({
      'type': type,
      'description': description.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'hash': hash,
      'status': 'Menunggu verifikasi',
      'user_id': userId,
      'photo_path': photoPath,
    });
  }
}
