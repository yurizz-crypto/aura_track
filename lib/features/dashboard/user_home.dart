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

/// The main dashboard screen for the user.
///
/// Displays the "Sanctuary" (virtual garden), the daily habit lists (Unfinished/Completed),
/// and a monthly calendar view of activity.
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
    _userId = id ?? '';
    _selectedDay = _focusedDay;
    _fetchMonthlyEvents();
  }

  /// Fetches habit completion logs for the currently focused month.
  /// Populates the calendar with dots indicating activity.
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

    if (mounted) setState(() => _events = newEvents);
  }

  /// Returns a stream of the user's profile to update the Garden and Points in real-time.
  Stream<Map<String, dynamic>> _getProfileStream() {
    return Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', _userId)
        .map((event) => event.first);
  }

  /// Helper to check if a specific log timestamp occurred on the current device date.
  bool _isHappeningToday(String completedAtIso) {
    final logDate = DateTime.parse(completedAtIso).toLocal();
    final now = DateTime.now();
    return logDate.year == now.year &&
        logDate.month == now.month &&
        logDate.day == now.day;
  }

  /// Awards 30 points to the user if they have completed 10 interactive habits.
  /// Updates the `last_bonus_date` to prevent double claiming.
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

  /// Deletes a habit.
  ///
  /// If the habit has existing logs, it warns the user that history will be lost
  /// before performing the deletion.
  Future<void> _deleteHabit(String habitId, String habitTitle) async {
    final logCount = await Supabase.instance.client
        .from('habit_logs')
        .count(CountOption.exact)
        .eq('habit_id', habitId);

    if (!mounted) return;

    String content = "Delete '$habitTitle'? This cannot be undone.";
    if (logCount > 0) {
      content = "⚠️ Warning: '$habitTitle' has $logCount completion records.\n\nDeleting this will PERMANENTLY REMOVE all its history.";
    }

    final confirm = await CustomDialogs.showConfirmDialog(
      context,
      title: "Delete Habit?",
      content: content,
      confirmText: "Delete Forever",
      confirmColor: Colors.red,
    );

    if (confirm) {
      try {
        if (logCount > 0) {
          await Supabase.instance.client.from('habit_logs').delete().eq('habit_id', habitId);
        }
        await _habitRepo.deleteHabit(habitId);
        setState(() {});
      } catch (e) {
        if (mounted) AppUtils.showSnackBar(context, "Error deleting: $e", isError: true);
      }
    }
  }

  /// Displays a dialog to rename an existing habit.
  Future<void> _showEditHabitDialog(Map<String, dynamic> habit) async {
    final controller = TextEditingController(text: habit['title']);
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Habit"),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: "Habit Name"),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (controller.text.isEmpty) return;
                    setDialogState(() => isSaving = true);
                    try {
                      await Supabase.instance.client
                          .from('habits')
                          .update({'title': controller.text})
                          .eq('id', habit['id']);

                      if (context.mounted) {
                        Navigator.pop(context);
                        setState(() {});
                        AppUtils.showSnackBar(context, "Habit updated!");
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                      : const Text("Save"),
                )
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenHeight = MediaQuery.of(context).size.height;
    final double gardenHeight = isLandscape ? screenHeight * 0.35 : 260.0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('My Sanctuary'),
          actions: [
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
                      // 1. Garden Background
                      Positioned.fill(
                        child: GardenScene(
                          totalPoints: flowers + (_optimisticBonusClaimed ? 30 : 0),
                          currentStreak: streak,
                          isQuotaMet: isBonusClaimed,
                        ),
                      ),
                      // 2. Level Badge
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
                      // 3. Daily Quota Card Overlay
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

                                  // Count interactive habits done TODAY
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

  /// Renders the card showing progress toward the 10-habit daily quota.
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

  /// Builds the tab view for "Unfinished" vs "Completed" habits.
  /// Separates habits based on whether they have been performed today (Daily) or marked complete (One-time).
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

              final doneTodayIds = logs
                  .where((log) => _isHappeningToday(log['completed_at']))
                  .map((log) => log['habit_id'])
                  .toSet();

              final List<Map<String, dynamic>> unfinished = [];
              final List<Map<String, dynamic>> completed = [];

              for (var habit in allHabits) {
                final isOnce = habit['frequency'] == 'once';
                final isCompletedFlag = habit['is_completed'] == true;

                bool isDone;
                if (isOnce) {
                  isDone = isCompletedFlag;
                } else {
                  isDone = doneTodayIds.contains(habit['id']);
                }

                if (isDone) {
                  completed.add(habit);
                } else {
                  unfinished.add(habit);
                }
              }

              return TabBarView(
                children: [
                  PaginatedHabitList(
                    habits: unfinished,
                    isDone: false,
                    onStart: (h) => _startHabit(context, h),
                    onDelete: (id, title) => _deleteHabit(id, title),
                    onEdit: (h) => _showEditHabitDialog(h),
                  ),
                  PaginatedHabitList(
                    habits: completed,
                    isDone: true,
                    onStart: (h) => _startHabit(context, h),
                    onDelete: (id, title) => _deleteHabit(id, title),
                    onEdit: (h) => _showEditHabitDialog(h),
                  ),
                ],
              );
            });
      },
    );
  }

  /// Builds the monthly calendar view showing activity dots.
  Widget _buildCalendarView() {
    int totalEvents = 0;
    _events.forEach((_, list) => totalEvents += list.length);

    return Column(
      children: [
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
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: TableCalendar(
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
            ),
          ),
        ),
      ],
    );
  }

  /// Navigates to the specific game screen or marks a standard habit as done.
  ///
  /// If the habit is a "One-Time" task, it marks the permanent completion flag.
  void _startHabit(BuildContext context, Map<String, dynamic> habit) async {
    final habitType = habit['type'];
    final habitId = habit['id'];
    final frequency = habit['frequency'];

    if (habitType == 'water_game') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => WaterPourGame(habitId: habitId)));
    } else if (habitType == 'meditation_game') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => MeditationGame(habitId: habitId)));
    } else if (habitType == 'walking_game') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => WalkingHabit(habitId: habitId)));
    } else {
      try {
        await _habitRepo.completeHabitInteraction(habitId, _userId);
        if(mounted) AppUtils.showSnackBar(context, "Habit marked done!");
      } catch(e) {
        if(mounted) AppUtils.showSnackBar(context, "Try again later.", isError: true);
      }
    }

    if (frequency == 'once') {
      try {
        await Supabase.instance.client
            .from('habits')
            .update({'is_completed': true})
            .eq('id', habitId);
      } catch(e) { debugPrint("Failed to mark once-task complete: $e"); }
    }

    setState(() => _fetchMonthlyEvents());
  }

  /// Displays a dialog to create a new habit with frequency and type options.
  Future<void> _showAddHabitDialog(BuildContext context) async {
    final controller = TextEditingController();
    String selectedType = 'water_game';
    String selectedIconAsset = 'check';
    String selectedFrequency = 'daily';

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Plant a New Habit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: controller,
                        decoration: const InputDecoration(labelText: "Habit Name", border: OutlineInputBorder())
                    ),
                    const SizedBox(height: 16),
                    const Text("Frequency:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedFrequency,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily (Resets every day)')),
                        DropdownMenuItem(value: 'once', child: Text('One-Time Task (Stays done)')),
                      ],
                      onChanged: (val) => setDialogState(() => selectedFrequency = val!),
                    ),
                    const SizedBox(height: 16),
                    const Text("Habit Type:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedType,
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
                          IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: () => setDialogState(() => selectedIconAsset = 'check'), color: selectedIconAsset=='check'?Colors.teal:Colors.grey),
                          IconButton(icon: const Icon(Icons.menu_book), onPressed: () => setDialogState(() => selectedIconAsset = 'book'), color: selectedIconAsset=='book'?Colors.teal:Colors.grey),
                          IconButton(icon: const Icon(Icons.fitness_center), onPressed: () => setDialogState(() => selectedIconAsset = 'gym'), color: selectedIconAsset=='gym'?Colors.teal:Colors.grey),
                        ],
                      )
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (controller.text.isEmpty) return;
                    setDialogState(() => isSaving = true);
                    try {
                      await Supabase.instance.client.from('habits').insert({
                        'user_id': _userId,
                        'title': controller.text,
                        'type': selectedType,
                        'frequency': selectedFrequency,
                        'icon_asset': selectedType == 'standard' ? selectedIconAsset : null,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        setState(() {});
                      }
                    } catch (e) {
                      if (context.mounted) setDialogState(() => isSaving = false);
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : const Text('Plant'),
                ),
              ],
            );
          }
      ),
    );
  }
}

/// A reusable widget that displays a list of habits with client-side pagination.
///
/// Supports "Load More" functionality and conditionally renders Edit/Delete buttons
/// based on the completion status of the habits.
class PaginatedHabitList extends StatefulWidget {
  final List<Map<String, dynamic>> habits;
  final bool isDone;
  final Function(Map<String, dynamic>) onStart;
  final Function(String, String) onDelete;
  final Function(Map<String, dynamic>) onEdit;

  const PaginatedHabitList({
    super.key,
    required this.habits,
    required this.isDone,
    required this.onStart,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<PaginatedHabitList> createState() => _PaginatedHabitListState();
}

class _PaginatedHabitListState extends State<PaginatedHabitList> {
  int _displayCount = 10;

  IconData _getIconForHabit(String type, String? iconAsset) {
    if (type == 'water_game') return Icons.water_drop;
    if (type == 'meditation_game') return Icons.self_improvement;
    if (type == 'walking_game') return Icons.directions_run;
    if (iconAsset == 'book') return Icons.menu_book;
    if (iconAsset == 'gym') return Icons.fitness_center;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.habits.isEmpty) {
      return Center(child: Text(widget.isDone ? "Do a habit to see it here!" : "All caught up TODAY!"));
    }

    final visibleHabits = widget.habits.take(_displayCount).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleHabits.length + (widget.habits.length > _displayCount ? 1 : 0),
      itemBuilder: (context, index) {
        // Pagination Button
        if (index == visibleHabits.length) {
          return TextButton(
            onPressed: () {
              setState(() {
                _displayCount += 10;
              });
            },
            child: Text("Load More (${widget.habits.length - _displayCount} remaining)"),
          );
        }

        final habit = visibleHabits[index];
        final isStandard = habit['type'] == 'standard';
        final isOnce = habit['frequency'] == 'once';
        final iconData = _getIconForHabit(habit['type'], habit['icon_asset']);

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isDone ? Colors.green.shade100 : Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: widget.isDone ? Colors.green : Colors.teal),
            ),
            title: Text(habit['title'],
                style: TextStyle(
                    decoration: widget.isDone ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.bold)),
            subtitle: Text(
              "${widget.isDone ? 'Completed' : (isStandard ? 'Standard' : 'Interactive')} • ${isOnce ? 'One-Time' : 'Daily'}",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isDone) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueGrey),
                    onPressed: () => widget.onEdit(habit),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => widget.onDelete(habit['id'], habit['title']),
                  ),
                ],

                // Action Button or Checkmark
                if (widget.isDone)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.check_circle, color: Colors.green),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: () => widget.onStart(habit),
                      child: Text(isStandard ? "Done" : "Play"),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}