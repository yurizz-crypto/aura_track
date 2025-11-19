import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_track/features/dashboard/user_home.dart';
import 'package:aura_track/features/dashboard/leaderboard_page.dart';
import 'package:aura_track/features/dashboard/profile_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const UserHome(),
    const LeaderboardPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to leave your garden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_florist), 
            label: 'Garden'
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events), 
            label: 'Leaderboard'
          ),
          NavigationDestination(
            icon: Icon(Icons.person), 
            label: 'Profile'
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 ? null : FloatingActionButton(
        onPressed: _confirmLogout,
        backgroundColor: Colors.red.shade100,
        child: const Icon(Icons.logout, color: Colors.red),
      ),
    );
  }
}