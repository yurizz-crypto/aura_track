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
                  return Center(child: Text('Something went wrong: Restart the app.'));
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
                    final avatarUrl = user['avatar_url'];

                    return ListTile(
                      // FIXED: Leading contains Row with Rank Circle AND Avatar
                      leading: SizedBox(
                        width: 90, // Fixed width to fit both circles
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // 1. The "Trophy" / Rank Circle
                            CircleAvatar(
                              radius: 14, // Slightly smaller to fit nicely
                              backgroundColor: index == 0 ? Colors.amber : Colors.teal,
                              foregroundColor: Colors.white,
                              child: Text(
                                "#${index + 1}",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8), // Gap between rank and avatar

                            // 2. The User Avatar
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? Text(
                                (user['username'] ?? "A")[0].toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                              )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        user['username'] ?? "Anonymous Gardener",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isHotStreak ? Colors.deepOrange : Colors.black,
                        ),
                      ),
                      subtitle: Text("${user['points'] ?? 0} flowers bloomed"),
                      tileColor: isMe ? Colors.teal.shade50 : null,
                      trailing: index < 3 ? const Icon(Icons.emoji_events, color: Colors.amber) : null,
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