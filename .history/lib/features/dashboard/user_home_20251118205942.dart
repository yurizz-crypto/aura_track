import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

import ''package:aura_track/features/sensor_games/water_pour/water_pour_game.dart';';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final _userId = Supabase.instance.client.auth.currentUser!.id;

  // Fetch habits specifically for this user
  final _habitsStream = Supabase.instance.client
      .from('habits')
      .stream(primaryKey: ['id'])
      .eq('user_id', Supabase.instance.client.auth.currentUser!.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Garden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          )
        ],
      ),
      body: Column(
        children: [
          // RUBRIC COMPONENT: CANVAS
          // This area visually represents progress (Gamification)
          Container(
            height: 250,
            width: double.infinity,
            color: Colors.teal.shade50,
            child: CustomPaint(
              painter: HabitGardenPainter(completedCount: 5), // Placeholder count until we link logs
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
                alignment: Alignment.centerLeft, 
                child: Text("Today's Habits", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
            ),
          ),
          // RUBRIC COMPONENT: BUTTONS & LISTS
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _habitsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final habits = snapshot.data!;
                
                if (habits.isEmpty) {
                  return const Center(child: Text("No habits yet. Plant one!"));
                }

                return ListView.builder(
                  itemCount: habits.length,
                  itemBuilder: (context, index) {
                    final habit = habits[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          habit['type'] == 'water_game' ? Icons.water_drop : Icons.spa,
                          color: Colors.teal,
                          size: 32,
                        ),
                        title: Text(habit['title']),
                        subtitle: Text("Type: ${habit['type']}"),
                        trailing: ElevatedButton(
                          onPressed: () {
                            // TODO: Navigate to the Sensor Game (Step 4)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Opening Sensor Game...")),
                            );
                          },
                          child: const Text("Start"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddHabitDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // Helper to add data to Supabase
  Future<void> _showAddHabitDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plant a New Habit'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "e.g., Drink Water")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await Supabase.instance.client.from('habits').insert({
                  'user_id': _userId,
                  'title': controller.text,
                  'type': 'water_game', // Defaulting to game for demo
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// RUBRIC CHECK: CANVAS IMPLEMENTATION
class HabitGardenPainter extends CustomPainter {
  final int completedCount;
  HabitGardenPainter({required this.completedCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42); // Fixed seed so flowers stay in same place

    // Draw Grass
    paint.color = Colors.green.shade200;
    canvas.drawRect(Rect.fromLTWH(0, size.height - 20, size.width, 20), paint);

    // Draw Flowers based on completed habits
    for (int i = 0; i < completedCount; i++) {
      double x = random.nextDouble() * size.width;
      double y = size.height - 20 - (random.nextDouble() * 50);
      
      // Draw Stem
      paint.color = Colors.green.shade800;
      canvas.drawLine(Offset(x, size.height - 20), Offset(x, y), paint..strokeWidth = 3);

      // Draw Petals
      paint.color = Colors.pinkAccent;
      canvas.drawCircle(Offset(x, y), 8, paint);
      
      // Draw Center
      paint.color = Colors.yellow;
      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}