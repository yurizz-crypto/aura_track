import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class WalkingHabit extends StatefulWidget {
  final String habitId;
  const WalkingHabit({super.key, required this.habitId});

  @override
  State<WalkingHabit> createState() => _WalkingHabitState();
}

class _WalkingHabitState extends State<WalkingHabit> {
  final int _targetSteps = 34;

  int _currentStepsCount = 0;
  int? _startStepCount;
  bool _completed = false;
  bool _permissionGranted = false;
  bool _isInitializing = true;
  late StreamSubscription<StepCount> _stepCountSubscription;
  Timer? _stabilizationTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndStart();
  }

  Future<void> _requestPermissionAndStart() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      setState(() => _permissionGranted = true);
      _startPedometer();
    } else {
      setState(() {
        _permissionGranted = false;
        _currentStepsCount = -1;
      });
      if (mounted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Needed"),
        content: const Text("Enable 'Physical Activity' permission in app settings to track steps."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _startPedometer() {
    _stepCountSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) {
        if (_completed) return;

        setState(() {
          if (_startStepCount == null && _stabilizationTimer == null) {
            _isInitializing = true;
            _stabilizationTimer = Timer(const Duration(milliseconds: 500), () {
              _startStepCount = event.steps;
              _isInitializing = false;
              _stabilizationTimer?.cancel();
            });
          }

          if (_startStepCount != null && !_isInitializing) {
            _currentStepsCount = event.steps - _startStepCount!;
          }

          if (_currentStepsCount >= _targetSteps) {
            _finishGame();
          }
        });
      },
      onError: (error) {
        setState(() {
          _currentStepsCount = -1;
          _isInitializing = false;
          _stepCountSubscription.cancel();
        });
        print('Pedometer Error: $error');
      },
      cancelOnError: true,
    );
  }

  void _resetSteps() {
    setState(() {
      _startStepCount = null;
      _currentStepsCount = 0;
      _isInitializing = true;
      _stabilizationTimer?.cancel();
    });
    if (_permissionGranted) {
      _startPedometer();
    }
  }

  Future<void> _finishGame() async {
    if (_completed) return;
    _completed = true;
    _stepCountSubscription.cancel();
    _stabilizationTimer?.cancel();

    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      // FIXED: Added .toUtc()
      await Supabase.instance.client.from('habit_logs').insert({
        'habit_id': widget.habitId,
        'user_id': userId,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      });

      await Supabase.instance.client.rpc('increment_points', params: {'row_id': userId});

    } catch (e) {
      print('Database Update Error: $e');
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Goal Achieved! 🏃"),
          content: const Text("You walked 25 meters and earned a point!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text("Done"),
            )
          ],
        ),
      );
    }
    await Supabase.instance.client.rpc('update_user_streak', params: {'user_uuid': userId});
  }

  @override
  void dispose() {
    _stepCountSubscription.cancel();
    _stabilizationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Walk 25 Meters (~34 Steps)")),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_run, size: 80, color: Colors.teal),
                const SizedBox(height: 20),
                Text(
                  _currentStepsCount == -1
                      ? "Sensor Error - Check Permissions"
                      : _completed ? "Completed!"
                      : _permissionGranted
                      ? (_isInitializing ? "Initializing Sensor..." : "Keep Walking!")
                      : "Grant Permission to Start",
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Text(
                  "Steps: ${_currentStepsCount > 0 ? _currentStepsCount : 0} / $_targetSteps",
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _permissionGranted
                      ? (_isInitializing
                      ? "Warming up (0.5s)..."
                      : "Walk with phone in pocket/hand.")
                      : "Tap 'Start' to request permission.",
                  style: const TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 40),
                LinearProgressIndicator(
                  value: _isInitializing
                      ? null
                      : (_currentStepsCount > 0 ? _currentStepsCount : 0) / _targetSteps,
                  minHeight: 15,
                  backgroundColor: Colors.teal.shade50,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _permissionGranted ? null : _requestPermissionAndStart,
                      child: const Text("Start"),
                    ),
                    if (_permissionGranted)
                      TextButton(
                        onPressed: _resetSteps,
                        child: const Text("Reset"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}