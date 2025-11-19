import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text("Community Garden")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: const Text(
              "Compete by completing Interactive Habits! (Standard habits do not award points)",
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('profiles')
                  .stream(primaryKey: ['id'])
                  .eq('role', 'user'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading leaderboard: ${snapshot.error}'));
                }

                final users = snapshot.data!;
                final sortedUsers = users
                    .where((user) => user['role'] == 'user')
                    .toList()
                  ..sort((a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0));

                return ListView.builder(
                  itemCount: sortedUsers.length,
                  itemBuilder: (context, index) {
                    final user = sortedUsers[index];
                    final isMe = user['id'] == currentUserId;
                    final isHotStreak = (user['current_streak'] ?? 0) >= 7;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index == 0 ? Colors.amber : Colors.teal,
                        child: Text("#${index + 1}"),
                      ),
                      title: Text(
                        user['username'] ?? "Anonymous Gardener",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isHotStreak ? Colors.orange : Colors.black,
                          shadows: isHotStreak ? [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.8),
                              blurRadius: 5,
                              spreadRadius: 2,
                            ),
                          ] : null,
                        ),
                      ),
                      subtitle: Text("${user['points'] ?? 0} flowers bloomed"),
                      tileColor: isMe ? Colors.teal.shade100 : null,
                      trailing: index < 3 ? const Icon(Icons.emoji_events, color: Colors.orange) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}