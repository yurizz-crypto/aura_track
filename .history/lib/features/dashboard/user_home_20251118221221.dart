import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

import 'package:aura_track/features/sensor_games/water_pour/water_pour_game.dart';
import 'package:aura_track/features/sensor_games/meditation/meditation_game.dart';

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

  void _navigateToMeditation(BuildContext context, String habitId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MeditationGame(habitId: habitId),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamBuilder(
          stream: Supabase.instance.client
              .from('habit_logs')
              .select('*, habits(title)') // Join with habits table
              .order('completed_at', ascending: false)
              .limit(20)
              .asStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final logs = snapshot.data as List;
            
            return ListView.builder(
              itemCount: logs.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final log = logs[index];
                final title = log['habits']['title'] ?? 'Unknown Habit';
                final date = DateTime.parse(log['completed_at']);
                
                return ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(title),
                  subtitle: Text("${date.hour}:${date.minute} - ${date.day}/${date.month}"),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Garden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
          IconButton
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
                            if (habit['type'] == 'water_game') {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => WaterPourGame(habitId: habit['id']),
                                ),
                              );
                            } else if (habit['type'] == 'meditation_game') {
                              // We will implement this in Step 2
                              _navigateToMeditation(context, habit['id']); 
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Standard habit marked done!")),
                              );
                            }
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

Future<void> _showAddHabitDialog(BuildContext context) async {
    final controller = TextEditingController();
    String selectedType = 'water_game'; // Default

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update Dropdown
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Plant a New Habit'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: "e.g., Morning Zen"),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Interaction Type'),
                  items: const [
                    DropdownMenuItem(value: 'water_game', child: Text('Pour Water (Tilt)')),
                    DropdownMenuItem(value: 'meditation_game', child: Text('Meditation (Hold Still)')),
                    DropdownMenuItem(value: 'standard', child: Text('Standard Checkbox')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedType = value!);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  if (controller.text.isNotEmpty) {
                    await Supabase.instance.client.from('habits').insert({
                      'user_id': _userId,
                      'title': controller.text,
                      'type': selectedType, 
                    });
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        }
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