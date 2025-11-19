import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:auratrack/features/dashboard/user_home.dart';
import 'package:auratrack/features/admin_panel/admin_dashboard.dart';

import 'package:aura_track/features/auth/login_page.dart';
import 'package:app_links/au';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 1. If waiting for connection, show loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.data?.session;

        // 2. If no session, show Login Page
        if (session == null) {
          return const LoginPage();
        }

        // 3. If logged in, check Role (Admin vs User)
        return FutureBuilder<Map<String, dynamic>>(
          future: Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', session.user.id)
              .single(),
          builder: (context, roleSnapshot) {
            if (!roleSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final role = roleSnapshot.data?['role'] ?? 'user';

            if (role == 'admin') {
              return const AdminDashboard();
            } else {
              return const UserHome();
            }
          },
        );
      },
    );
  }
}