import 'dart:convert';
import 'package:http/http.dart' as http;

class OfficialDisasterNews {
  final String title;
  final String summary;
  final String location;
  final String date;
  final String sourceUrl;
  final String category;

  const OfficialDisasterNews({
    required this.title,
    required this.summary,
    required this.location,
    required this.date,
    required this.sourceUrl,
    required this.category,
  });
}

class OfficialDisasterService {
  static const String _url =
      'https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json';

  Future<OfficialDisasterNews> getLatestEarthquake() async {
    final response =
        await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Data BMKG tidak dapat dimuat.');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final Map<String, dynamic> earthquake = data['Infogempa']['gempa'];

    final String magnitude = earthquake['Magnitude']?.toString() ?? '-';
    final String location = earthquake['Wilayah']?.toString() ?? 'Indonesia';
    final String date = earthquake['Tanggal']?.toString() ?? '';
    final String time = earthquake['Jam']?.toString() ?? '';
    final String depth = earthquake['Kedalaman']?.toString() ?? '-';
    final String potential = earthquake['Potensi']?.toString() ?? '';

    return OfficialDisasterNews(
      title: 'Gempa Bumi M$magnitude',
      summary: 'Kedalaman: $depth. $potential',
      location: location,
      date: '$date $time WIB',
      sourceUrl: 'https://www.bmkg.go.id/gempabumi',
      category: 'Gempa Bumi',
    );
  }
}
