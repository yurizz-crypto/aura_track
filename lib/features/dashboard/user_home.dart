import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import 'package:aura_track/features/sensor_games/water_pour/water_pour_game.dart';
import 'package:aura_track/features/sensor_games/meditation/meditation_game.dart';
import 'package:aura_track/features/sensor_games/walking/walking_habit.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with SingleTickerProviderStateMixin {
  final _userId = Supabase.instance.client.auth.currentUser!.id;
  bool _showCalendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _getHabitsStream() {
    return Supabase.instance.client
        .from('habits')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId);
  }

  Future<List<Map<String, dynamic>>> _getTodayLogs() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Supabase.instance.client
        .from('habit_logs')
        .select('habit_id')
        .eq('user_id', _userId)
        .gte('completed_at', '$todayStr 00:00:00');
  }
    
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Sanctuary'),
          actions: [
            IconButton(
              icon: Icon(_showCalendar ? Icons.list : Icons.calendar_month),
              onPressed: () => setState(() => _showCalendar = !_showCalendar),
            )
          ],
          bottom: _showCalendar ? null : const TabBar(
            tabs: [
              Tab(text: "Unfinished"),
              Tab(text: "Completed Today"),
            ],
          ),
        ),
        body: Column(
          children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: FutureBuilder<Map<String, dynamic>>(
                future: Supabase.instance.client
                    .from('profiles')
                    .select('points, current_streak')
                    .eq('id', _userId)
                    .single()
                    .catchError((_) => {'points': 0, 'current_streak': 0}), 
                builder: (context, snapshot) {
                  final data = snapshot.data ?? {'points': 0, 'current_streak': 0};
                  int flowerCount = data['points'] ?? 0;
                  int streak = data['current_streak'] ?? 0;
                  
                  return AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: BetterGardenPainter(
                          totalPoints: flowerCount, 
                          currentStreak: streak,
                          animationValue: _glowController.value,
                        ), 
                      );
                    },
                  );
                },
              ),
            ),

            Expanded(
              child: _showCalendar 
                ? _buildCalendarView() 
                : _buildHabitTabs(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddHabitDialog(context),
          label: const Text("Plant Seed"),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildHabitTabs() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getHabitsStream(),
      builder: (context, habitSnapshot) {
        if (!habitSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final allHabits = habitSnapshot.data!;

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getTodayLogs(),
          builder: (context, logSnapshot) {
            if (logSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator()); 
            }
            if (!logSnapshot.hasData) {
              return const Center(child: Text("Error fetching daily status."));
            }

            final completedIds = logSnapshot.data!.map((log) => log['habit_id']).toSet();
            
            final unfinishedHabits = allHabits.where((h) => !completedIds.contains(h['id'])).toList();
            final completedHabits = allHabits.where((h) => completedIds.contains(h['id'])).toList();

            return TabBarView(
              children: [
                _buildHabitListView(context, unfinishedHabits, isDone: false),
                _buildHabitListView(context, completedHabits, isDone: true),
              ],
            );
          }
        );
      },
    );
  }
  
  Widget _buildHabitListView(BuildContext context, List<Map<String, dynamic>> habits, {required bool isDone}) {
    if (habits.isEmpty) {
      return Center(child: Text(isDone ? "Good job! All seeds planted." : "Nothing to do today. 🥳"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final isStandard = habit['type'] == 'standard';

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDone ? Colors.green.shade100 : Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                habit['type'] == 'water_game' ? Icons.water_drop : 
                habit['type'] == 'meditation_game' ? Icons.self_improvement :
                habit['type'] == 'walking_game' ? Icons.directions_run : Icons.check,
                color: isDone ? Colors.green : Colors.teal,
              ),
            ),
            title: Text(habit['title'], style: TextStyle(
              decoration: isDone ? TextDecoration.lineThrough : null,
              fontWeight: FontWeight.bold
            )),
            subtitle: Text(isDone ? "Completed Today" : "Interaction: ${habit['type'].toString().replaceAll('_', ' ')}"),
            trailing: isDone 
              ? const Icon(Icons.check_circle, color: Colors.green)
              : ElevatedButton(
                  onPressed: () => _startHabit(context, habit),
                  child: Text(isStandard ? "Mark as Done" : "Start"),
                ),
          ),
        );
      },
    );
  }
  
  Widget _buildCalendarView() {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(height: 10),
        if (_selectedDay != null)
          Expanded(
            child: FutureBuilder(
              future: Supabase.instance.client
                  .from('habit_logs')
                  .select('*, habits(title)')
                  .gte('completed_at', DateFormat('yyyy-MM-dd').format(_selectedDay!))
                  .lt('completed_at', DateFormat('yyyy-MM-dd').format(_selectedDay!.add(const Duration(days: 1)))),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final logs = snapshot.data as List;
                if (logs.isEmpty) return Center(child: Text("No blooms on ${DateFormat.yMMMd().format(_selectedDay!)}."));
                
                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      leading: const Icon(Icons.spa, size: 16, color: Colors.pink),
                      title: Text(log['habits']['title'] ?? 'Habit'),
                    );
                  },
                );
              },
            ),
          )
      ],
    );
  }
  
  void _startHabit(BuildContext context, Map<String, dynamic> habit) async {
    final habitType = habit['type'];
    final habitId = habit['id'];
    final userId = Supabase.instance.client.auth.currentUser!.id;

    if (habitType == 'water_game') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => WaterPourGame(habitId: habitId)));
    } else if (habitType == 'meditation_game') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => MeditationGame(habitId: habitId)));
    } else if (habitType == 'walking_game') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => WalkingHabit(habitId: habitId)));
    } else {
      await Supabase.instance.client.from('habit_logs').insert({
        'habit_id': habitId,
        'user_id': userId, 
        'completed_at': DateTime.now().toIso8601String(),
      });
      await Supabase.instance.client.rpc('update_user_streak', params: {'user_uuid': userId});
    }
    
    setState(() {}); 
  }

  Future<void> _showAddHabitDialog(BuildContext context) async {
    final controller = TextEditingController();
    String selectedType = 'water_game'; 
    final userId = Supabase.instance.client.auth.currentUser!.id;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder( 
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Plant a New Habit'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controller, decoration: const InputDecoration(labelText: "Habit Name")),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'water_game', child: Text('Pour Water (Interactive)')),
                    DropdownMenuItem(value: 'meditation_game', child: Text('Meditation (Interactive)')),
                    DropdownMenuItem(value: 'walking_game', child: Text('Walking (Interactive)')),
                    DropdownMenuItem(value: 'standard', child: Text('Standard (No Points)')),
                  ],
                  onChanged: (val) => setState(() => selectedType = val!),
                ),
                const SizedBox(height: 10),
                const Text("Note: Only Interactive habits earn Leaderboard points!", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.isNotEmpty) {
                    await Supabase.instance.client.from('habits').insert({
                      'user_id': userId,
                      'title': controller.text,
                      'type': selectedType, 
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      this.setState(() {}); 
                    }
                  }
                },
                child: const Text('Plant'),
              ),
            ],
          );
        }
      ),
    );
  }
}

class BetterGardenPainter extends CustomPainter {
  final int totalPoints; 
  final int currentStreak;
  final double animationValue;

  BetterGardenPainter({
    this.totalPoints = 0, 
    required this.currentStreak,
    this.animationValue = 0.0,
  }); 

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = Random(totalPoints);
    final isGlowing = currentStreak >= 7;

    final Rect rect = Offset.zero & size;
    final Gradient gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.lightBlue.shade100, Colors.white],
    );
    paint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    paint.shader = null;
    paint.color = Colors.green.shade300;
    final Path hillPath = Path();
    hillPath.moveTo(0, size.height);
    hillPath.lineTo(0, size.height - 30);
    hillPath.quadraticBezierTo(size.width * 0.25, size.height - 60, size.width * 0.5, size.height - 40);
    hillPath.quadraticBezierTo(size.width * 0.75, size.height - 20, size.width, size.height - 50);
    hillPath.lineTo(size.width, size.height);
    canvas.drawPath(hillPath, paint);

    int flowerCount = min(totalPoints ~/ 10, 15);

    for (int i = 0; i < flowerCount; i++) {
      double x = size.width * (0.1 + (i % 5) * 0.15); 
      double y = size.height - 30 - (random.nextDouble() * 20); 

      if (i >= 5) x += size.width * 0.05;
      if (i >= 10) x -= size.width * 0.1;

      _drawFlower(canvas, x, y, Colors.primaries[i % Colors.primaries.length], isGlowing);
    }
  }

  void _drawFlower(Canvas canvas, double x, double y, Color color, bool isGlowing) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    if (isGlowing) {
      double glowRadius = 12.0 + (animationValue * 6.0);
      double glowOpacity = 0.4 + (animationValue * 0.4);

      paint.maskFilter = const MaskFilter.blur(BlurStyle.outer, 5.0);
      paint.color = Colors.amber.withOpacity(glowOpacity);
      canvas.drawCircle(Offset(x, y - 40), glowRadius, paint);
      paint.maskFilter = null;
    }

    paint.color = Colors.green.shade800;
    paint.strokeWidth = 3;
    canvas.drawLine(Offset(x, y), Offset(x, y - 40), paint);

    paint.color = color;
    for (int i = 0; i < 5; i++) {
      double angle = (i * 72) * pi / 180;
      double petalX = x + cos(angle) * 10;
      double petalY = (y - 40) + sin(angle) * 10;
      canvas.drawCircle(Offset(petalX, petalY), 6, paint);
    }
    
    paint.color = Colors.yellow;
    canvas.drawCircle(Offset(x, y - 40), 4, paint);
  }

  @override
  bool shouldRepaint(covariant BetterGardenPainter oldDelegate) {
     return oldDelegate.totalPoints != totalPoints || 
            oldDelegate.currentStreak != currentStreak ||
            oldDelegate.animationValue != animationValue;
  }
}