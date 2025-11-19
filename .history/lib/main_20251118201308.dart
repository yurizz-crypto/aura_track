import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:auratrack/features/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Replace these with your actual Supabase API keys
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const AuraTrackApp());
}

class AuraTrackApp extends StatelessWidget {
  const AuraTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuraTrack',
      theme: ThemeData(
        primarySwatch: Colors.teal, // "Aura" theme colors
        useMaterial3: true,
      ),
      home: const AuthGate(), // The Gatekeeper
    );
  }
}