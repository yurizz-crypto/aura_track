import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_track/common/widgets/user_avatar.dart';
import 'package:aura_track/features/dashboard/visit_garden_page.dart';

/// Displays a ranked list of users based on their total "bloomed flowers" (points).
/// Highlights the top 7 with unique colors and gives the top 3 animated names.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  void _visitGarden(BuildContext context, Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisitGardenPage(
          userId: user['id'],
          username: user['username'] ?? "Anonymous",
        ),
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0: return Colors.amber;                 // Gold
      case 1: return const Color(0xFFC0C0C0);      // Silver
      case 2: return const Color(0xFFCD7F32);      // Bronze
      case 3: return Colors.purpleAccent;
      case 4: return Colors.deepPurpleAccent;
      case 5: return Colors.indigoAccent;
      case 6: return Colors.blueAccent;
      default: return Colors.teal;
    }
  }

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
              "Tap on a gardener to visit their Sanctuary! 🌱",
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
                  return const Center(child: Text('Something went wrong: Restart the app.'));
                }

                final users = snapshot.data!;
                // Sort by points descending
                final sortedUsers = users
                    .where((user) => user['role'] == 'user')
                    .toList()
                  ..sort((a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0));

                return ListView.builder(
                  itemCount: sortedUsers.length,
                  itemBuilder: (context, index) {
                    final user = sortedUsers[index];
                    final isMe = user['id'] == currentUserId;
                    final isTop3 = index < 3;
                    final rankColor = _getRankColor(index);

                    return ListTile(
                      onTap: () => _visitGarden(context, user),
                      leading: SizedBox(
                        width: 90,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Rank Badge with Unique Background Color
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: rankColor,
                              foregroundColor: Colors.white,
                              child: Text(
                                "#${index + 1}",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Avatar
                            UserAvatar(
                              avatarUrl: user['avatar_url'],
                              username: user['username'] ?? 'A',
                              radius: 20,
                            ),
                          ],
                        ),
                      ),
                      title: isTop3
                      // Dynamic Color Changing Name for Top 3
                          ? RainbowText(
                        text: user['username'] ?? "Anonymous Gardener",
                        baseStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      )
                          : Text(
                        user['username'] ?? "Anonymous Gardener",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text("${user['points'] ?? 0} flowers bloomed"),
                      tileColor: isMe ? Colors.teal.shade50 : null,
                      trailing: index < 3
                          ? Icon(Icons.emoji_events, color: rankColor)
                          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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

/// A widget that animates text color with a rainbow gradient effect.
class RainbowText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;

  const RainbowText({
    super.key,
    required this.text,
    required this.baseStyle
  });

  @override
  State<RainbowText> createState() => _RainbowTextState();
}

class _RainbowTextState extends State<RainbowText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.indigo,
                Colors.purple,
                Colors.red,
              ],
              tileMode: TileMode.mirror,
              // Animate the stops to create the moving effect
              stops: [
                (_controller.value * 0.1) % 1.0,
                (_controller.value * 0.1 + 0.15) % 1.0,
                (_controller.value * 0.1 + 0.3) % 1.0,
                (_controller.value * 0.1 + 0.45) % 1.0,
                (_controller.value * 0.1 + 0.6) % 1.0,
                (_controller.value * 0.1 + 0.75) % 1.0,
                (_controller.value * 0.1 + 0.9) % 1.0,
                (_controller.value * 0.1 + 1.0) % 1.0,
              ],
              transform: GradientRotation(_controller.value * 6.28),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.baseStyle.copyWith(color: Colors.white), // Color is ignored due to ShaderMask, but required
          ),
        );
      },
    );
  }
}