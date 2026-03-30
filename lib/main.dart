import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String supabaseUrl;
  String supabaseAnonKey;

  if (kIsWeb) {
    // Web: dart-define or fallback to hardcoded values
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    supabaseUrl = envUrl.isNotEmpty
        ? envUrl
        : 'https://yiznvpkpfexlthzysfrb.supabase.co';
    supabaseAnonKey = envKey.isNotEmpty
        ? envKey
        : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlpem52cGtwZmV4bHRoenlzZnJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3Mjc5NjgsImV4cCI6MjA4OTMwMzk2OH0.SC_zy_CUzGQfrLmMG7OVfHsz0ys7pHHId4ps0Zw8pms';
  } else {
    // Mobile: load from .env file
    await dotenv.load(fileName: '.env');
    supabaseUrl = dotenv.env['SUPABASE_URL']!;
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
  }

  await initializeDateFormatting('ja');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: HeroEggApp(),
    ),
  );
}
