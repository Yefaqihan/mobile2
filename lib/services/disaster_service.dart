import 'dart:convert';
import 'package:http/http.dart' as http;

class EarthquakeInfo {
  const EarthquakeInfo(
      {required this.magnitude,
      required this.location,
      required this.date,
      required this.depth,
      required this.potential,
      required this.coordinates});
  final String magnitude, location, date, depth, potential, coordinates;

  factory EarthquakeInfo.fromJson(Map<String, dynamic> json) {
    final gempa = (json['Infogempa'] as Map<String, dynamic>?)?['gempa']
            as Map<String, dynamic>? ??
        {};
    return EarthquakeInfo(
        magnitude: '${gempa['Magnitude'] ?? '-'}',
        location: '${gempa['Wilayah'] ?? 'Lokasi tidak tersedia'}',
        date: '${gempa['Tanggal'] ?? ''} ${gempa['Jam'] ?? ''}',
        depth: '${gempa['Kedalaman'] ?? '-'}',
        potential: '${gempa['Potensi'] ?? 'Informasi potensi tidak tersedia'}',
        coordinates: '${gempa[' koordinat'] ?? gempa['Coordinates'] ?? '-'}');
  }
}

class DisasterService {
  static final Uri _url =
      Uri.parse('https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json');
  Future<EarthquakeInfo> fetchLatestEarthquake() async {
    final response = await http.get(_url).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200)
      throw Exception('BMKG tidak dapat diakses (${response.statusCode}).');
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>)
      throw const FormatException('Format data BMKG tidak sesuai.');
    return EarthquakeInfo.fromJson(data);
  }
}
