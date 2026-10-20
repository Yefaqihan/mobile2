import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/disaster_service.dart';
import '../widgets/resq_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = DisasterService();
  late Future<EarthquakeInfo> _earthquake;
  @override
  void initState() {
    super.initState();
    _earthquake = _service.fetchLatestEarthquake();
  }

  void _refresh() =>
      setState(() => _earthquake = _service.fetchLatestEarthquake());
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 28), children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('RESQ / SIAGA',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                        color: resqOrange)),
                const SizedBox(height: 6),
                const Text('Pantau sekitar kamu.',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: resqBlue))
              ])),
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child:
                  const Icon(Icons.notifications_none_rounded, color: resqBlue))
        ]),
        const SizedBox(height: 20),
        ResQCard(
          color: resqBlue,
          child: Row(children: [
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SIAP SEBELUM TERJADI',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('Kenali jalur aman.\nSiapkan tas siaga.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            height: 1.25,
                            fontWeight: FontWeight.w800))
                  ]),
            ),
            Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                    color: resqOrange, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.health_and_safety_rounded,
                    size: 34, color: Colors.white))
          ]),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Peta siaga',
            subtitle:
                'Lokasi demo shelter — verifikasi titik resmi di wilayahmu.'),
        const SizedBox(height: 12),
        ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
                height: 260,
                child: FlutterMap(
                    options: const MapOptions(
                        initialCenter: LatLng(-7.7971, 110.3705),
                        initialZoom: 12),
                    children: [
                      TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.resq.app'),
                      MarkerLayer(markers: const [
                        Marker(
                            point: LatLng(-7.7971, 110.3705),
                            width: 44,
                            height: 44,
                            child: Icon(Icons.location_on,
                                size: 42, color: resqOrange)),
                        Marker(
                            point: LatLng(-7.7833, 110.3670),
                            width: 44,
                            height: 44,
                            child: Icon(Icons.health_and_safety,
                                size: 36, color: resqBlue)),
                        Marker(
                            point: LatLng(-7.8110, 110.3600),
                            width: 44,
                            height: 44,
                            child: Icon(Icons.health_and_safety,
                                size: 36, color: resqBlue)),
                      ])
                    ]))),
        const SizedBox(height: 8),
        const Text(
            'Titik pada peta hanya contoh untuk demo, bukan data shelter resmi.',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
        const SizedBox(height: 24),
        Row(children: [
          const Expanded(
              child: SectionTitle('Info gempa BMKG',
                  subtitle: 'Data gempa terbaru dari feed resmi')),
          IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, color: resqBlue))
        ]),
        const SizedBox(height: 10),
        FutureBuilder<EarthquakeInfo>(
            future: _earthquake,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const ResQCard(
                    child: Center(
                        child: Padding(
                            padding: EdgeInsets.all(18),
                            child:
                                CircularProgressIndicator(color: resqOrange))));
              if (snapshot.hasError)
                return ResQCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Icon(Icons.cloud_off_rounded,
                          color: resqOrange, size: 30),
                      const SizedBox(height: 8),
                      const Text('Data BMKG belum dapat dimuat.'),
                      const SizedBox(height: 4),
                      Text('${snapshot.error}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blueGrey)),
                      TextButton(
                          onPressed: _refresh, child: const Text('Coba lagi'))
                    ]));
              final e = snapshot.data!;
              return ResQCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: resqOrange.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('M ${e.magnitude}',
                              style: const TextStyle(
                                  color: resqOrange,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(e.location,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: resqBlue)))
                    ]),
                    const SizedBox(height: 14),
                    _detail('Waktu', e.date),
                    _detail('Kedalaman', e.depth),
                    _detail('Potensi', e.potential)
                  ]));
            }),
        const SizedBox(height: 22),
        const SectionTitle('Mode demonstrasi'),
        const SizedBox(height: 10),
        ResQCard(
            child: Consumer<AppProvider>(
                builder: (context, app, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Developer Override',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: resqBlue)),
                          const Text(
                              'Gunakan untuk demo layar darurat tanpa menunggu sensor.'),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: app.developerOverride,
                              activeColor: resqOrange,
                              title: const Text('Aktifkan simulasi'),
                              onChanged: app.setDeveloperOverride),
                          if (app.developerOverride)
                            SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                    onPressed: app.triggerEmergency,
                                    icon:
                                        const Icon(Icons.warning_amber_rounded),
                                    label: const Text('Simulasikan darurat')))
                        ]))),
      ]);
  Widget _detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 95,
            child: Text(label, style: const TextStyle(color: Colors.blueGrey))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)))
      ]));
}
