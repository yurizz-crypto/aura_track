import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_track/features/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://enrpfyycdznytnjqinew.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVucnBmeXljZHpueXRuanFpbmV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0NjQ5MTksImV4cCI6MjA3OTA0MDkxOX0.WiBmAPijmbXCtBxco4l2q33dbINzCHAAzF3eTTtIKjA',
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
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}