import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import 'package:aura_track/core/services/auth_service.dart';
import 'package:aura_track/core/services/habit_repository.dart';
import 'package:aura_track/common/utils/app_utils.dart';
import 'package:aura_track/common/widgets/confirmation_dialog.dart';
import 'package:aura_track/common/widgets/garden_scene.dart';

import 'package:aura_track/features/sensor_games/water_pour/water_pour_game.dart';
import 'package:aura_track/features/sensor_games/meditation/meditation_game.dart';
import 'package:aura_track/features/sensor_games/walking/walking_habit.dart';

/// The primary dashboard for authenticated users.
///
/// Features:
/// 1. **Digital Garden:** Visualizes user progress (points/streaks) via [GardenScene].
/// 2. **Habit Tracker:** Lists daily habits (todo/done) and interactive games.
/// 3. **Calendar:** Shows a history of completed habits.
/// 4. **Gamification:** Handles daily quotas and bonus point claiming.
class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final _authService = AuthService();
  final _habitRepo = HabitRepository();

  late final String _userId;

  bool _showCalendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};

  bool _isClaimingLoading = false;
  bool _optimisticBonusClaimed = false;

  @override
  void initState() {
    super.initState();
    final id = _authService.currentUserId;
    if (id == null) {
      _userId = '';
    } else {
      _userId = id;
    }

    _selectedDay = _focusedDay;
    _fetchMonthlyEvents();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Fetches habit logs for the currently focused month to populate the calendar dots.
  /// Events are grouped by date in the [_events] map.
  Future<void> _fetchMonthlyEvents() async {
    if (_userId.isEmpty) return;

    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    final response = await Supabase.instance.client
        .from('habit_logs')
        .select('completed_at')
        .eq('user_id', _userId)
        .gte('completed_at', startOfMonth.toIso8601String())
        .lte('completed_at', endOfMonth.toIso8601String());

    Map<DateTime, List<dynamic>> newEvents = {};
    for (var log in response) {
      DateTime date = DateTime.parse(log['completed_at']).toLocal();
      DateTime dayKey = DateTime.utc(date.year, date.month, date.day);
      if (newEvents[dayKey] == null) newEvents[dayKey] = [];
      newEvents[dayKey]!.add(log);
    }

    if (mounted) {
      setState(() {
        _events = newEvents;
      });
    }
  }

  /// Listens to real-time updates for the user's profile (points, streaks).
  Stream<Map<String, dynamic>> _getProfileStream() {
    return Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', _userId)
        .map((event) => event.first);
  }

  /// Helper to check if a specific log timestamp occurred today.
  bool _isHappeningToday(String completedAtIso) {
    final logDate = DateTime.parse(completedAtIso).toLocal();
    final now = DateTime.now();
    return logDate.year == now.year &&
        logDate.month == now.month &&
        logDate.day == now.day;
  }

  /// Awards 30 bonus points when the daily interactive quota is met.
  /// Updates `last_bonus_date` to prevent double claiming.
  Future<void> _claimDailyBonus(int currentPoints) async {
    setState(() => _isClaimingLoading = true);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await Supabase.instance.client.from('profiles').update({
        'points': currentPoints + 30,
        'last_bonus_date': today,
      }).eq('id', _userId);

      if (mounted) {
        setState(() {
          _isClaimingLoading = false;
          _optimisticBonusClaimed = true;
        });
        AppUtils.showSnackBar(context, "🎉 30 Points Claimed! Daily Quota Met.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClaimingLoading = false);
        AppUtils.showSnackBar(context, "Claim failed. Please try again.", isError: true);
      }
    }
  }

  /// Deletes a custom habit.
  /// Prevents deletion if the habit has existing completion logs to preserve history.
  Future<void> _deleteHabit(String habitId, String habitTitle) async {
    final logCount = await Supabase.instance.client
        .from('habit_logs')
        .count(CountOption.exact)
        .eq('habit_id', habitId);

    if (!mounted) return;

    if (logCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Cannot Delete"),
          content: Text("'$habitTitle' is part of your history. You cannot delete active habits that have records."),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
        ),
      );
      return;
    }

    final confirm = await CustomDialogs.showConfirmDialog(
      context,
      title: "Delete Habit?",
      content: "Delete '$habitTitle'? This cannot be undone.",
      confirmText: "Delete",
      confirmColor: Colors.red,
    );

    if (confirm) {
      await _habitRepo.deleteHabit(habitId);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenHeight = MediaQuery.of(context).size.height;
    // Dynamic height for the garden area
    final double gardenHeight = isLandscape ? screenHeight * 0.35 : 260.0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('My Sanctuary'),
          actions: [
            // Toggle between List view and Calendar view
            IconButton(
              icon: Icon(_showCalendar ? Icons.list : Icons.calendar_month),
              onPressed: () => setState(() => _showCalendar = !_showCalendar),
            )
          ],
          bottom: _showCalendar
              ? null
              : const TabBar(
            tabs: [
              Tab(text: "Unfinished"),
              Tab(text: "Completed"),
            ],
          ),
        ),
        body: Column(
          children: [
            // 1. Garden Section (Top)
            SizedBox(
              height: gardenHeight,
              width: double.infinity,
              child: StreamBuilder<Map<String, dynamic>>(
                stream: _getProfileStream(),
                builder: (context, profileSnapshot) {
                  final profile = profileSnapshot.data ?? {};
                  final int flowers = profile['points'] ?? 0;
                  final int streak = profile['current_streak'] ?? 0;
                  final String? lastBonus = profile['last_bonus_date'];

                  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  final bool isBonusClaimed = (lastBonus == todayStr) || _optimisticBonusClaimed;

                  return Stack(
                    children: [
                      // Background Garden Animation
                      Positioned.fill(
                        child: GardenScene(
                          totalPoints: flowers + (_optimisticBonusClaimed ? 30 : 0),
                          currentStreak: streak,
                          isQuotaMet: isBonusClaimed,
                        ),
                      ),
                      // Level Badge Overlay
                      Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                                "Level ${(flowers / 50).floor()} • ${flowers % 50}/50 Blooms",
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                            ),
                          )
                      ),
                      // Daily Quota Card Overlay
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _habitRepo.getHabitsStream(_userId),
                            builder: (context, habitSnapshot) {
                              final habits = habitSnapshot.data ?? [];
                              final interactiveHabitIds = habits
                                  .where((h) => h['type'] != 'standard')
                                  .map((h) => h['id'])
                                  .toSet();

                              return StreamBuilder<List<Map<String, dynamic>>>(
                                stream: _habitRepo.getRecentLogsStream(_userId),
                                builder: (context, logsSnapshot) {
                                  final allLogs = logsSnapshot.data ?? [];

                                  // Filter logs to count only Interactive habits done today
                                  final interactiveTodayLogs = allLogs.where((log) {
                                    bool isToday = _isHappeningToday(log['completed_at']);
                                    bool isInteractive = interactiveHabitIds.contains(log['habit_id']);
                                    return isToday && isInteractive;
                                  }).toList();

                                  final int count = interactiveTodayLogs.length;
                                  return _buildQuotaCard(count, isBonusClaimed, flowers);
                                },
                              );
                            }
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // 2. Habit List or Calendar (Bottom)
            Expanded(
              child: _showCalendar ? _buildCalendarView() : _buildHabitTabs(),
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

  /// Builds the quota progress card or the "Claim Bonus" button.
  Widget _buildQuotaCard(int count, bool isClaimed, int currentPoints) {
    if (isClaimed) {
      return Card(
        color: Colors.white.withOpacity(0.95),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text("Daily Quota Met! Great work.",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)
              ),
            ],
          ),
        ),
      );
    }

    // Show Claim button if 10+ interactive habits completed
    if (count >= 10) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isClaimingLoading ? null : () => _claimDailyBonus(currentPoints),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.all(16),
            elevation: 8,
            shadowColor: Colors.amberAccent,
          ),
          icon: _isClaimingLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.card_giftcard, size: 28),
          label: const Text("Claim 30 Point Bonus!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }

    // Otherwise show progress bar
    double progress = (count / 10.0).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Interactive Goal: $count/10", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            color: Colors.teal,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      ),
    );
  }

  /// Builds the TabView for "Unfinished" vs "Completed" habits.
  Widget _buildHabitTabs() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _habitRepo.getHabitsStream(_userId),
      builder: (context, habitSnapshot) {
        if (!habitSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        final allHabits = habitSnapshot.data ?? [];

        return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _habitRepo.getRecentLogsStream(_userId),
            builder: (context, logSnapshot) {
              final logs = logSnapshot.data ?? [];

              // Identify which habits have been done today
              final completedIds = logs
                  .where((log) => _isHappeningToday(log['completed_at']))
                  .map((log) => log['habit_id'])
                  .toSet();

              final unfinishedHabits = allHabits.where((h) => !completedIds.contains(h['id'])).toList();
              final completedHabits = allHabits.where((h) => completedIds.contains(h['id'])).toList();

              return TabBarView(
                children: [
                  _buildHabitListView(context, unfinishedHabits, isDone: false),
                  _buildHabitListView(context, completedHabits, isDone: true),
                ],
              );
            });
      },
    );
  }

  /// Generic list builder for a list of habits.
  Widget _buildHabitListView(BuildContext context, List<Map<String, dynamic>> habits, {required bool isDone}) {
    if (habits.isEmpty) {
      return Center(child: Text(isDone ? "Keep growing! Do a habit." : "All caught up! Great job. 🌸"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final isStandard = habit['type'] == 'standard';
        final iconData = _getIconForHabit(habit['type'], habit['icon_asset']);

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
              child: Icon(iconData, color: isDone ? Colors.green : Colors.teal),
            ),
            title: Text(habit['title'],
                style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null, fontWeight: FontWeight.bold)),
            subtitle: Text(isDone ? "Completed Today" : (isStandard ? "Standard Habit" : "Interactive Game")),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDone)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _deleteHabit(habit['id'], habit['title']),
                  ),
                if (isDone)
                  const Icon(Icons.check_circle, color: Colors.green)
                else
                  ElevatedButton(
                    onPressed: () => _startHabit(context, habit),
                    child: Text(isStandard ? "Done" : "Play"),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForHabit(String type, String? iconAsset) {
    if (type == 'water_game') return Icons.water_drop;
    if (type == 'meditation_game') return Icons.self_improvement;
    if (type == 'walking_game') return Icons.directions_run;

    switch (iconAsset) {
      case 'book': return Icons.menu_book;
      case 'gym': return Icons.fitness_center;
      case 'bed': return Icons.bed;
      case 'sun': return Icons.sunny;
      default: return Icons.check_circle_outline;
    }
  }

  /// Builds the calendar view showing dots for days with activity.
  Widget _buildCalendarView() {
    int totalEvents = 0;
    _events.forEach((_, list) => totalEvents += list.length);

    return Column(
      children: [
        // Calendar Header Stats
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text("$totalEvents", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                      const Text("Habits this Month", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Container(height: 30, width: 1, color: Colors.teal.shade200),
                  const Column(
                    children: [
                      Text("Keep Going!", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                      Text("Consistency is key", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: (day) {
                    final key = DateTime.utc(day.year, day.month, day.day);
                    return _events[key] ?? [];
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                    _fetchMonthlyEvents();
                  },
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    markerDecoration: BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                  ),
                ),
                // Selected Day Details
                if (_selectedDay != null) ...[
                  const Divider(),
                  FutureBuilder(
                    future: Supabase.instance.client
                        .from('habit_logs')
                        .select('*, habits(title)')
                        .gte('completed_at', DateFormat('yyyy-MM-dd').format(_selectedDay!))
                        .lt('completed_at', DateFormat('yyyy-MM-dd').format(_selectedDay!.add(const Duration(days: 1)))),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final logs = snapshot.data as List;
                      if (logs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text("No blooms on ${DateFormat.yMMMd().format(_selectedDay!)}."),
                        );
                      }

                      return Column(
                        children: logs.map((log) {
                          return ListTile(
                            leading: const Icon(Icons.spa, size: 16, color: Colors.pink),
                            title: Text(log['habits']['title'] ?? 'Habit'),
                            subtitle: Text(DateFormat('hh:mm a').format(DateTime.parse(log['completed_at']).toLocal())),
                          );
                        }).toList(),
                      );
                    },
                  )
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Launches a sensor game or completes a standard habit immediately.
  void _startHabit(BuildContext context, Map<String, dynamic> habit) async {
    final habitType = habit['type'];
    final habitId = habit['id'];

    if (habitType == 'water_game') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => WaterPourGame(habitId: habitId)));
    } else if (habitType == 'meditation_game') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => MeditationGame(habitId: habitId)));
    } else if (habitType == 'walking_game') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => WalkingHabit(habitId: habitId)));
    } else {
      // Standard habits complete instantly
      try {
        await _habitRepo.completeHabitInteraction(habitId, _userId);
        if(mounted) AppUtils.showSnackBar(context, "Habit marked done!");
      } catch(e) {
        if(mounted) AppUtils.showSnackBar(context, "Try again later.", isError: true);
      }
    }

    // Refresh stats
    setState(() {
      _fetchMonthlyEvents();
    });
  }

  /// Shows a form dialog to create a new habit.
  Future<void> _showAddHabitDialog(BuildContext context) async {
    final controller = TextEditingController();
    String selectedType = 'water_game';
    String selectedIconAsset = 'check';

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {

            Widget buildIconOption(String key, IconData icon) {
              final isSelected = selectedIconAsset == key;
              return GestureDetector(
                onTap: () => setDialogState(() => selectedIconAsset = key),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.teal.withOpacity(0.2) : Colors.transparent,
                    border: isSelected ? Border.all(color: Colors.teal, width: 2) : Border.all(color: Colors.grey.shade300),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: isSelected ? Colors.teal : Colors.grey),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Plant a New Habit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                            labelText: "Habit Name",
                            border: OutlineInputBorder()
                        )
                    ),
                    const SizedBox(height: 16),
                    const Text("Habit Type:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'water_game', child: Text('Interactive: Pour Water')),
                        DropdownMenuItem(value: 'meditation_game', child: Text('Interactive: Meditation')),
                        DropdownMenuItem(value: 'walking_game', child: Text('Interactive: Walking')),
                        DropdownMenuItem(value: 'standard', child: Text('Standard: Checkbox')),
                      ],
                      onChanged: (val) => setDialogState(() => selectedType = val!),
                    ),

                    if (selectedType == 'standard') ...[
                      const SizedBox(height: 20),
                      const Text("Choose Icon:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 15,
                        runSpacing: 10,
                        children: [
                          buildIconOption('check', Icons.check_circle_outline),
                          buildIconOption('book', Icons.menu_book),
                          buildIconOption('gym', Icons.fitness_center),
                          buildIconOption('bed', Icons.bed),
                          buildIconOption('sun', Icons.sunny),
                        ],
                      )
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel')
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (controller.text.isEmpty) return;

                    setDialogState(() => isSaving = true);

                    try {
                      // Insert new habit into DB
                      await Supabase.instance.client.from('habits').insert({
                        'user_id': _userId,
                        'title': controller.text,
                        'type': selectedType,
                        'icon_asset': selectedType == 'standard' ? selectedIconAsset : null,
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        setState(() {});
                        AppUtils.showSnackBar(context, "Seed planted successfully! 🌱");
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppUtils.showSnackBar(context, "Failed to plant: ${e.toString().split('\n').first}", isError: true);
                        setDialogState(() => isSaving = false);
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Plant'),
                ),
              ],
            );
          }
      ),
    );
  }
}