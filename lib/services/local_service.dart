import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocalService {
  static const _medicalKey = 'resq_medical_profile';

  Future<Map<String, String>> loadMedical() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_medicalKey);

    if (raw == null) {
      return {'blood': '', 'allergies': '', 'contact': ''};
    }

    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {'blood': '', 'allergies': '', 'contact': ''};
    }
  }

  Future<void> saveMedical(Map<String, String> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_medicalKey, jsonEncode(data));
  }
}

class AiService {
  Future<String> ask(String message) async {
    final question = message.trim();

    if (question.isEmpty) {
      return 'Silakan tulis pertanyaan seputar bencana atau keselamatan.';
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'resq-ai',
        body: {
          'message': question,
        },
      ).timeout(const Duration(seconds: 25));

      if (response.status == 200 && response.data is Map) {
        final answer = response.data['answer'];

        if (answer is String && answer.trim().isNotEmpty) {
          return 'AI ResQ ONLINE\n\n${answer.trim()}';
        }
      }

      debugPrint(
        'ResQ AI: respons backend tidak sesuai '
        '(status ${response.status}).',
      );
    } catch (e) {
      debugPrint('ResQ AI gagal menghubungi backend: $e');
    }

    return 'PANDUAN OFFLINE\n\n${_offlineAnswer(question)}';
  }

  String _offlineAnswer(String message) {
    final q = message.toLowerCase();

    final isDisasterTopic = _hasAny(q, [
      'bencana',
      'gempa',
      'lindu',
      'guncangan',
      'banjir',
      'air naik',
      'genangan',
      'tsunami',
      'longsor',
      'tanah bergerak',
      'kebakaran',
      'api di rumah',
      'evakuasi',
      'mitigasi',
      'p3k',
      'pertolongan pertama',
      'luka',
      'berdarah',
      'perdarahan',
      'pingsan',
      'tidak sadar',
      'tak sadarkan diri',
      'tersedak',
      'tercekik makanan',
      'tas siaga',
      'tas darurat',
      'perlengkapan darurat',
      'kesiapsiagaan',
      'darurat',
      'selamat',
      'gunung meletus',
      'erupsi',
      'angin puting beliung',
      'cuaca ekstrem',
      'pertolongan korban',
      'survival',
    ]);

    if (!isDisasterTopic) {
      return 'Maaf, ResQ AI hanya melayani pertanyaan seputar '
          'bencana, kesiapsiagaan, keselamatan, dan pertolongan pertama.';
    }

    if (_hasAny(q, ['gempa', 'lindu', 'guncangan'])) {
      return 'SAAT GEMPA\n'
          '1. Merunduk dan lindungi kepala serta leher.\n'
          '2. Berlindung di bawah meja kokoh jika tersedia.\n'
          '3. Jauhi kaca dan benda yang dapat jatuh.\n'
          '4. Setelah guncangan berhenti, periksa bahaya dan '
          'evakuasi melalui jalur aman jika diperlukan.\n'
          '5. Jangan gunakan lift. Ikuti arahan petugas.';
    }

    if (_hasAny(q, ['banjir', 'air naik', 'genangan'])) {
      return 'SAAT BANJIR\n'
          '1. Pindah ke tempat lebih tinggi jika aman.\n'
          '2. Jauhi arus banjir dan jangan menerobos genangan.\n'
          '3. Hindari kabel atau peralatan listrik yang terkena air.\n'
          '4. Matikan listrik hanya jika aman dilakukan.\n'
          '5. Ikuti arahan petugas setempat.';
    }

    if (_hasAny(q, ['berdarah', 'perdarahan', 'luka terbuka'])) {
      return 'PERTOLONGAN AWAL PERDARAHAN\n'
          '1. Pastikan lokasi aman dan gunakan sarung tangan jika ada.\n'
          '2. Tekan luka langsung dengan kasa atau kain bersih.\n'
          '3. Jika darah menembus kain, tambahkan kain di atasnya '
          'dan teruskan tekanan.\n'
          '4. Untuk perdarahan berat, segera minta bantuan medis.\n'
          'Jangan mencabut benda yang tertancap pada luka.';
    }

    if (_hasAny(q, ['luka bakar', 'tersiram air panas', 'terbakar'])) {
      return 'PERTOLONGAN AWAL LUKA BAKAR\n'
          '1. Jauhkan korban dari sumber panas jika aman.\n'
          '2. Dinginkan luka dengan air mengalir sejuk selama '
          '20 menit jika memungkinkan.\n'
          '3. Jangan gunakan es, pasta gigi, minyak, atau mentega.\n'
          '4. Jangan pecahkan lepuhan atau menarik benda yang '
          'menempel pada luka.\n'
          '5. Cari bantuan medis untuk luka berat, luas, atau '
          'yang mengenai wajah, tangan, alat kelamin, maupun jalan napas.';
    }

    if (_hasAny(q, ['pingsan', 'tidak sadar', 'tak sadarkan diri'])) {
      return 'JIKA SESEORANG TIDAK SADAR\n'
          '1. Pastikan lingkungan aman dan periksa responsnya.\n'
          '2. Minta orang lain menghubungi layanan darurat.\n'
          '3. Periksa apakah korban bernapas normal.\n'
          '4. Jika tidak bernapas normal, segera mulai CPR jika '
          'mampu dan ikuti instruksi petugas darurat.\n'
          '5. Jika bernapas normal, pantau kondisinya. Hindari '
          'memindahkan korban jika dicurigai cedera leher atau '
          'tulang belakang, kecuali ada bahaya langsung.';
    }

    if (_hasAny(q, ['tersedak', 'tercekik makanan'])) {
      return 'JIKA SESEORANG TERSEDAK\n'
          'Jika korban masih dapat batuk kuat, dorong untuk terus batuk.\n'
          'Jika tidak dapat berbicara, batuk, atau bernapas, '
          'segera minta bantuan darurat dan lakukan pertolongan '
          'sesuai pelatihan yang dimiliki.\n'
          'Untuk bayi, gunakan prosedur khusus bayi. Jangan '
          'mengorek mulut secara membabi buta.';
    }

    if (_hasAny(q, ['tas siaga', 'tas darurat', 'perlengkapan darurat'])) {
      return 'ISI TAS SIAGA\n'
          '• Air minum dan makanan tahan lama.\n'
          '• Obat pribadi dan perlengkapan P3K.\n'
          '• Senter dan baterai cadangan.\n'
          '• Peluit dan power bank.\n'
          '• Dokumen penting dalam wadah tahan air.\n'
          '• Masker, pakaian ganti, dan perlengkapan kebersihan.\n'
          'Sesuaikan isi tas dengan kebutuhan keluarga.';
    }

    if (_hasAny(q, ['tsunami', 'gelombang besar'])) {
      return 'WASPADA TSUNAMI\n'
          'Jika merasakan gempa kuat atau lama di daerah pesisir, '
          'segera menjauh dari pantai dan menuju tempat tinggi '
          'atau jalur evakuasi tsunami. Jangan menunggu melihat '
          'gelombang. Ikuti peringatan resmi dan jangan kembali '
          'sebelum dinyatakan aman.';
    }

    if (_hasAny(q, ['longsor', 'tanah bergerak'])) {
      return 'WASPADA TANAH LONGSOR\n'
          'Jauhi lereng yang retak, pohon atau tiang yang miring, '
          'serta aliran material. Jika aman, segera menjauh dari '
          'jalur longsoran dan laporkan kepada petugas. Jangan '
          'melintasi area longsor yang belum dinyatakan aman.';
    }

    if (_hasAny(q, ['kebakaran', 'api di rumah'])) {
      return 'SAAT KEBAKARAN\n'
          '1. Beri peringatan kepada orang di sekitar.\n'
          '2. Segera keluar melalui jalur yang aman.\n'
          '3. Jangan gunakan lift; bergerak rendah jika ada asap.\n'
          '4. Jangan kembali ke bangunan yang terbakar.\n'
          '5. Hubungi pemadam kebakaran atau layanan darurat setempat.';
    }

    return 'Panduan offline untuk pertanyaan ini belum tersedia.\n\n'
        'Coba tanyakan tentang gempa, banjir, tsunami, longsor, '
        'kebakaran, perdarahan, luka bakar, pingsan, tersedak, '
        'atau isi tas siaga.\n\n'
        'Jika internet tersedia, coba lagi agar Gemini dapat '
        'membantu menjawab pertanyaan yang lebih spesifik.';
  }

  bool _hasAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}
