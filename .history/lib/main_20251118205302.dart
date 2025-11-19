import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_track/features/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://enrpfyycdznytnjqinew.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6d2h0Ymh3YnJlbnZnYW9lZ3BpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyOTY5NjUsImV4cCI6MjA3ODg3Mjk2NX0.mmdCTM5wzsdnZviunsQMX2Hn8oR1j6zbF-c4jNOycDs',
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