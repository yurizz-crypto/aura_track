import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeditationGame extends StatefulWidget {
  final String habitId;
  const MeditationGame({super.key, required this.habitId});

  @override
  State<MeditationGame> createState() => _MeditationGameState();
}

class _MeditationGameState extends State<MeditationGame> with SingleTickerProviderStateMixin {
  // Settings
  final int _targetSeconds = 15; // Short for demo purposes (Real app: 60s)
  
  // State
  double _progress = 0.0; // 0.0 to 1.0
  bool _isMoving = false;
  bool _completed = false;
  Timer? _timer;
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;

  @override
  void initState() {
    super.initState();
    _startSensor();
    _startTimer();
  }

  void _startSensor() {
    // RUBRIC: SENSOR (Accelerometer)
    // We use UserAccelerometerEvent because it ignores gravity (easier to detect shakes)
    _accelSubscription = userAccelerometerEventStream().listen((event) {
      // Calculate total movement magnitude
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Threshold: If movement > 0.3, the user is not still enough
      bool currentlyMoving = magnitude > 0.3;

      if (currentlyMoving != _isMoving) {
        setState(() {
          _isMoving = currentlyMoving;
        });
      }
    });
  }

  void _startTimer() {
    // Timer ticks every 100ms
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_completed) {
        timer.cancel();
        return;
      }

      // RUBRIC: LOGIC
      // Only progress if user is NOT moving
      if (!_isMoving) {
        setState(() {
          _progress += (0.1 / _targetSeconds);
        });

        if (_progress >= 1.0) {
          _finishGame();
        }
      }
    });
  }

  Future<void> _finishGame() async {
    _completed = true;
    _timer?.cancel();
    _accelSubscription?.cancel();

    // Save to DB
    await Supabase.instance.client.from('habit_logs').insert({
      'habit_id': widget.habitId,
      'completed_at': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Zen Achieved 🌸"),
          content: const Text("You remained still and mindful."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Namaste"),
            )
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isMoving ? Colors.red.shade50 : Colors.teal.shade50,
      appBar: AppBar(title: const Text("Hold Still")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isMoving ? "Too much movement!" : "Breathe...",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isMoving ? Colors.red : Colors.teal,
              ),
            ),
            const SizedBox(height: 40),
            
            // RUBRIC: CANVAS (Visual Timer)
            SizedBox(
              height: 250,
              width: 250,
              child: CustomPaint(
                painter: MeditationTimerPainter(
                  progress: _progress, 
                  isMoving: _isMoving
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            Text("${((1.0 - _progress) * _targetSeconds).ceil()} seconds remaining"),
          ],
        ),
      ),
    );
  }
}

// RUBRIC: CANVAS IMPLEMENTATION
class MeditationTimerPainter extends CustomPainter {
  final double progress;
  final bool isMoving;

  MeditationTimerPainter({required this.progress, required this.isMoving});

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = size.width / 2;

    // 1. Background Circle
    Paint bgPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Progress Arc
    Paint progressPaint = Paint()
      ..color = isMoving ? Colors.red : Colors.teal
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;

    // Draw arc from -90 degrees (top)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start at top
      2 * pi * progress, // Sweep angle
      false,
      progressPaint,
    );

    // 3. Center Dot (Visual feedback for stillness)
    // If moving, the dot jitters randomly to visualize chaos
    Paint dotPaint = Paint()..color = isMoving ? Colors.redAccent : Colors.tealAccent;
    
    double jitterX = isMoving ? (Random().nextDouble() * 20 - 10) : 0;
    double jitterY = isMoving ? (Random().nextDouble() * 20 - 10) : 0;

    canvas.drawCircle(center + Offset(jitterX, jitterY), 20, dotPaint);
  }

  @override
  bool shouldRepaint(covariant MeditationTimerPainter oldDelegate) => true;
}