class Shelter {
  const Shelter(
      {required this.name,
      required this.latitude,
      required this.longitude,
      this.note = 'Titik demo'});
  final String name;
  final double latitude;
  final double longitude;
  final String note;
}

class DisasterReport {
  const DisasterReport({
    required this.id,
    required this.type,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.hash,
    this.status = 'Menunggu verifikasi',
    this.photoPath,
    this.userId,
    this.assignedTo,
    this.handlingStatus = 'Belum ditangani',
    this.handlingNotes,
    this.handledAt,
    this.handlingPhotoPath,
  });

  final String id;
  final String type;
  final String description;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String hash;
  final String status;
  final String? photoPath;
  final String? userId;
  final String? assignedTo;
  final String handlingStatus;
  final String? handlingNotes;
  final DateTime? handledAt;
  final String? handlingPhotoPath;

  factory DisasterReport.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return DisasterReport(
      id: id,
      type: map['type'] as String? ?? 'Lainnya',
      description: map['description'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(
            map['created_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      hash: map['hash'] as String? ?? '',
      status: map['status'] as String? ?? 'Menunggu verifikasi',
      photoPath: map['photo_path'] as String?,
      userId: map['user_id'] as String?,
      assignedTo: map['assigned_to'] as String?,
      handlingStatus: map['handling_status'] as String? ?? 'Belum ditangani',
      handlingNotes: map['handling_notes'] as String?,
      handledAt: DateTime.tryParse(
        map['handled_at'] as String? ?? '',
      ),
      handlingPhotoPath: map['handling_photo_path'] as String?,
    );
  }
}
