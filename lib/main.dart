import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/app_provider.dart';
import 'screens/auth_screen.dart';
import 'widgets/resq_widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  var supabaseReady = false;

  try {
    await dotenv.load(fileName: '.env');

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabasePublishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
    debugPrint('SUPABASE URL AKTIF: $supabaseUrl');
    debugPrint(
      'SUPABASE KEY TERISI: ${supabasePublishableKey.isNotEmpty}',
    );

    if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );

      supabaseReady = true;
    }
  } catch (e) {
    debugPrint('Supabase gagal diinisialisasi: $e');
  }

  runApp(ResQApp(supabaseReady: supabaseReady));
}

class ResQApp extends StatelessWidget {
  const ResQApp({super.key, required this.supabaseReady});

  final bool supabaseReady;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'ResQ',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('id', 'ID'),
          Locale('en', 'US'),
        ],
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: resqBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: resqOrange,
            primary: resqOrange,
            secondary: resqBlue,
          ),
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: resqBg,
            foregroundColor: resqBlue,
            elevation: 0,
            centerTitle: false,
          ),
        ),
        home: supabaseReady ? const AuthGate() : const SupabaseSetupScreen(),
      ),
    );
  }
}

class SupabaseSetupScreen extends StatelessWidget {
  const SupabaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: resqOrange,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'ResQ perlu konfigurasi Supabase',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: resqBlue,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Pastikan SUPABASE_URL dan '
                  'SUPABASE_PUBLISHABLE_KEY sudah diatur, '
                  'lalu jalankan ulang aplikasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
