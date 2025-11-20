import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aura_track/core/services/habit_repository.dart';
import 'package:aura_track/core/services/auth_service.dart';
import 'package:aura_track/common/widgets/confirmation_dialog.dart';

/// A sensor-based habit where the user must walk ~25m to earn points.
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

  final _habitRepo = HabitRepository();
  final _authService = AuthService();

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
      if (mounted) _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Needed"),
        content: const Text("Enable 'Physical Activity' permission to track steps."),
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
          // 1. Wait for initial stream event to stabilize baseline
          if (_startStepCount == null && _stabilizationTimer == null) {
            _isInitializing = true;
            _stabilizationTimer = Timer(const Duration(milliseconds: 500), () {
              _startStepCount = event.steps;
              _isInitializing = false;
              _stabilizationTimer?.cancel();
            });
          }
          // 2. Calculate relative steps walked in this session
          if (_startStepCount != null && !_isInitializing) {
            _currentStepsCount = event.steps - _startStepCount!;
          }
          // 3. Check for completion
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
    if (_permissionGranted) _startPedometer();
  }

  Future<void> _finishGame() async {
    if (_completed) return;
    _completed = true;
    _stepCountSubscription.cancel();
    _stabilizationTimer?.cancel();

    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      await _habitRepo.completeHabitInteraction(widget.habitId, userId);

      if (mounted) {
        await CustomDialogs.showSuccessDialog(
            context,
            title: "Goal Achieved! 🏃",
            content: "You walked 25 meters and earned a point!"
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Game Error: $e');
    }
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
                      : _completed ? "Completed!" : _permissionGranted
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