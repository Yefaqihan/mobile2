import 'dart:async';
import 'package:flutter/material.dart';
import '../services/local_service.dart';
import '../widgets/resq_widgets.dart';

class SurvivalScreen extends StatefulWidget {
  const SurvivalScreen({super.key});
  @override
  State<SurvivalScreen> createState() => _SurvivalScreenState();
}

class _SurvivalScreenState extends State<SurvivalScreen> {
  final _ai = AiService();
  final _message = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  bool _isThinking = false;
  final List<Map<String, String>> _chat = [
    {
      'role': 'ai',
      'text':
          'Hai! Aku bisa bantu tips mitigasi dan persiapan darurat. Apa yang ingin kamu ketahui?'
    }
  ];
  final _items = const [
    {'name': 'Air minum', 'icon': Icons.water_drop, 'points': 3},
    {'name': 'Senter', 'icon': Icons.flashlight_on, 'points': 3},
    {'name': 'Plester & P3K', 'icon': Icons.medical_services, 'points': 3},
    {'name': 'Peluit', 'icon': Icons.campaign, 'points': 2},
    {'name': 'Power bank', 'icon': Icons.battery_charging_full, 'points': 2},
    {'name': 'Vas bunga', 'icon': Icons.local_florist, 'points': 0},
    {'name': 'Bantal besar', 'icon': Icons.bed, 'points': 0},
    {'name': 'Dokumen penting', 'icon': Icons.badge, 'points': 3}
  ];
  final Set<String> _picked = {};

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Timer? _timer;
  int _seconds = 15;
  bool _playing = false, _finished = false;
  @override
  void dispose() {
    _message.dispose();
    _chatScrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();

    if (text.isEmpty || _isThinking) return;

    _message.clear();

    setState(() {
      _chat.add({'role': 'user', 'text': text});
      _isThinking = true;
    });

    _scrollToBottom();

    try {
      final answer = await _ai.ask(text);

      if (!mounted) return;

      setState(() {
        _chat.add({'role': 'ai', 'text': answer});
        _isThinking = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _chat.add({
          'role': 'ai',
          'text':
              'Maaf, terjadi kesalahan saat menyiapkan jawaban. Silakan coba lagi.'
        });
        _isThinking = false;
      });

      _scrollToBottom();
    }
  }

  void _startGame() {
    _timer?.cancel();
    setState(() {
      _picked.clear();
      _seconds = 15;
      _playing = true;
      _finished = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        setState(() {
          _seconds = 0;
          _playing = false;
          _finished = true;
        });
      } else {
        setState(() => _seconds--);
      }
    });
  }

  int get _score => _items
      .where((item) => _picked.contains(item['name']))
      .fold<int>(0, (sum, item) => sum + (item['points'] as int));
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 28), children: [
        const Text('AI & SURVIVAL HUB',
            style: TextStyle(
                color: resqOrange,
                letterSpacing: 1.5,
                fontSize: 11,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Bekal pengetahuan.',
            style: TextStyle(
                color: resqBlue, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        const SectionTitle('Chatbot Siaga',
            subtitle:
                'Jawaban edukasi simulasi, bukan pengganti petugas atau dokter.'),
        const SizedBox(height: 10),
        ResQCard(
            child: Column(children: [
          SizedBox(
              height: 220,
              child: ListView.builder(
                  controller: _chatScrollController,
                  itemCount: _chat.length,
                  itemBuilder: (context, index) {
                    final item = _chat[index];
                    final user = item['role'] == 'user';
                    return Align(
                        alignment:
                            user ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(maxWidth: 270),
                            decoration: BoxDecoration(
                                color: user ? resqBlue : resqBg,
                                borderRadius: BorderRadius.circular(14)),
                            child: Text(item['text']!,
                                style: TextStyle(
                                    color: user ? Colors.white : resqBlue,
                                    height: 1.35))));
                  })),
          if (_isThinking)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: resqOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ResQ AI sedang menyiapkan jawaban...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _message,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                        hintText: 'Tanya tentang mitigasi...',
                        filled: true,
                        fillColor: resqBg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none)))),
            const SizedBox(width: 8),
            IconButton.filled(
                onPressed: _send,
                style: IconButton.styleFrom(backgroundColor: resqOrange),
                icon: const Icon(Icons.send_rounded))
          ])
        ])),
        const SizedBox(height: 24),
        const SectionTitle('Survival Bag Builder',
            subtitle: 'Pilih barang esensial sebelum waktu habis.'),
        const SizedBox(height: 10),
        ResQCard(
            child: Column(children: [
          Row(children: [
            const Expanded(
                child: Text('TAS SIAGA • 15 DETIK',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: resqBlue))),
            Text('00:${_seconds.toString().padLeft(2, '0')}',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _seconds <= 5 ? resqRed : resqOrange))
          ]),
          const SizedBox(height: 12),
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.65),
              itemBuilder: (context, i) {
                final item = _items[i];
                final name = item['name'] as String;
                final selected = _picked.contains(name);
                return InkWell(
                    onTap: !_playing
                        ? null
                        : () => setState(() {
                              if (selected) {
                                _picked.remove(name);
                              } else {
                                _picked.add(name);
                              }
                            }),
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: selected
                                ? resqOrange.withValues(alpha: .12)
                                : resqBg,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: selected
                                    ? resqOrange
                                    : Colors.transparent)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item['icon'] as IconData,
                                  color: selected ? resqOrange : resqBlue),
                              const SizedBox(height: 5),
                              Text(name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12))
                            ])));
              }),
          const SizedBox(height: 12),
          if (_finished)
            Text(
                'Skor kamu: $_score / 19. ${_score >= 14 ? 'Siap siaga!' : 'Coba lagi untuk melengkapi tas.'}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: resqBlue)),
          PrimaryButton(
              label: _playing
                  ? 'Pilih barang di atas'
                  : (_finished ? 'Main lagi' : 'Mulai tantangan'),
              icon: Icons.backpack_outlined,
              onPressed: _playing ? null : _startGame)
        ])),
      ]);
}
