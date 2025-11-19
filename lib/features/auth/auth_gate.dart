import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_track/features/auth/login_page.dart';
import 'package:aura_track/features/admin_panel/admin_dashboard.dart';
import 'package:aura_track/features/dashboard/user_home.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 1. Waiting for initial auth check
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.data?.session;

        // 2. No session -> Login Page
        if (session == null) {
          return const LoginPage();
        }

        // 3. Logged in -> Check Role
        // We use maybeSingle() instead of single() to avoid crashing if profile is missing
        return FutureBuilder<Map<String, dynamic>?>(
          future: Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', session.user.id)
              .maybeSingle(), 
          builder: (context, roleSnapshot) {
            // Show loader while fetching role
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // If there is an error or no profile found, default to 'user'
            // This fixes the "Stuck in Loading" bug
            final data = roleSnapshot.data;
            final role = data != null ? data['role'] : 'user';

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