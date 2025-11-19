import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart'; // Rubric: Sensors
import 'package:audioplayers/audioplayers.dart'; // Rubric: Sound
import 'package:supabase_flutter/supabase_flutter.dart';

class WaterPourGame extends StatefulWidget {
  final String habitId;
  
  const WaterPourGame({super.key, required this.habitId});

  @override
  State<WaterPourGame> createState() => _WaterPourGameState();
}

class _WaterPourGameState extends State<WaterPourGame> with SingleTickerProviderStateMixin {
  // Sensor State
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  double _tiltAngle = 0.0;
  
  // Game State
  double _fillLevel = 0.0; // 0.0 to 1.0 (100%)
  bool _isPouring = false;
  bool _completed = false;
  
  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startListeningToSensor();
  }

  void _startListeningToSensor() {
    // RUBRIC: INVISIBLE COMPONENT (SENSOR)
    // We listen to the Gyroscope to detect physical phone rotation
    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      setState(() {
        // Detect tilt on the X-axis (tilting phone forward/backward)
        _tiltAngle = event.x;
        
        // If tilted significantly (> 1.5 rad/s), we consider it "pouring"
        if (_tiltAngle.abs() > 1.0 && !_completed) {
          _isPouring = true;
          _fillGlass();
        } else {
          _isPouring = false;
        }
      });
    });
  }

  void _fillGlass() {
    if (_fillLevel < 1.0) {
      // Increment fill level
      setState(() {
        _fillLevel += 0.005; // Adjust speed of filling here
      });
    } else {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    if (_completed) return;
    
    _completed = true;
    _gyroSubscription?.cancel(); // Stop sensor to save battery

    // RUBRIC: INVISIBLE COMPONENT (SOUND)
    // Play success sound (ensure you have a 'success.mp3' in assets or use a URL)
    try {
       await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
       // Fail silently if no asset found, avoids crash
    }

    // Update Database (Habit Completed)
    await Supabase.instance.client.from('habit_logs').insert({
      'habit_id': widget.habitId,
      'completed_at': DateTime.now().toIso8601String(),
    });

    // Show Success Message & Exit
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Hydrated! 💧"),
          content: const Text("Good job keeping your habit."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close Dialog
                Navigator.of(context).pop(); // Back to Home
              },
              child: const Text("Finish"),
            )
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tilt to Pour")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _completed ? "Full!" : "Tilt your phone to pour water!",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 40),
            
            // RUBRIC: CANVAS IMPLEMENTATION
            // Custom Drawing of the Glass and Water
            SizedBox(
              height: 300,
              width: 200,
              child: CustomPaint(
                painter: WaterGlassPainter(
                  fillLevel: _fillLevel,
                  isPouring: _isPouring,
                  tiltAngle: _tiltAngle
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Text("Fill Level: ${(_fillLevel * 100).toInt()}%"),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// THE CANVAS PAINTER (Rubric: User Interface - Canvas)
// ---------------------------------------------------------
class WaterGlassPainter extends CustomPainter {
  final double fillLevel;
  final bool isPouring;
  final double tiltAngle;

  WaterGlassPainter({
    required this.fillLevel, 
    required this.isPouring, 
    required this.tiltAngle
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glassPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final Paint waterPaint = Paint()
      ..color = Colors.blue.shade400.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // 1. Draw the Glass Container
    // A simple trapezoid shape
    final Path glassPath = Path();
    glassPath.moveTo(20, 0); // Top Left
    glassPath.lineTo(40, size.height); // Bottom Left
    glassPath.lineTo(size.width - 40, size.height); // Bottom Right
    glassPath.lineTo(size.width - 20, 0); // Top Right
    // Do not close, top is open
    
    canvas.drawPath(glassPath, glassPaint);

    // 2. Draw the Water inside
    if (fillLevel > 0) {
      double waterHeight = size.height * fillLevel;
      double topY = size.height - waterHeight;

      // Calculate width at the top of the water (trapezoid math)
      // Interpolating width based on height
      
      Rect waterRect = Rect.fromLTRB(
        40, // Simplified padding
        topY, 
        size.width - 40, 
        size.height
      );
      
      canvas.drawRect(waterRect, waterPaint);
    }

    // 3. Draw "Pouring" Stream (Visual Feedback for Sensor)
    if (isPouring) {
      final Paint streamPaint = Paint()
        ..color = Colors.blue.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0;

      // Draw a line coming from "above"
      canvas.drawLine(
        Offset(size.width / 2, -50), 
        Offset(size.width / 2, size.height - (size.height * fillLevel)), 
        streamPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaterGlassPainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel || oldDelegate.isPouring != isPouring;
  }
}