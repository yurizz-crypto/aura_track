import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WaterPourGame extends StatefulWidget {
  final String habitId;
  
  const WaterPourGame({super.key, required this.habitId});

  @override
  State<WaterPourGame> createState() => _WaterPourGameState();
}

class _WaterPourGameState extends State<WaterPourGame> with SingleTickerProviderStateMixin {
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  double _tiltAngle = 0.0;
  
  double _fillLevel = 0.0;
  bool _isPouring = false;
  bool _completed = false;
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startListeningToSensor();
  }

  void _startListeningToSensor() {
    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      setState(() {
        final orientation = MediaQuery.of(context).orientation;
        _tiltAngle = orientation == Orientation.portrait ? event.x : event.y;
        
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
      setState(() {
        _fillLevel += 0.02;
      });
    } else {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    if (_completed) return;
    
    _completed = true;
    _gyroSubscription?.cancel();
    
    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      await Supabase.instance.client.from('habit_logs').insert({
        'habit_id': widget.habitId,
        'user_id': userId,
        'completed_at': DateTime.now().toIso8601String(),
      });
      
      await Supabase.instance.client.rpc('increment_points', params: {'row_id': userId});
    } catch (e) {
      print('Database Update Error: $e');
    }

    try {
      await _audioPlayer.play(AssetSource('/assets/sounds/success.mp3'));
    } catch (e) {
      // Fail silently
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Hydrated! 💧"),
          content: const Text("Good job keeping your habit and earning points!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text("Finish"),
            )
          ],
        ),
      );
    }
    await Supabase.instance.client.rpc('update_user_streak', params: {'user_uuid': userId});
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final canvasSize = (screenSize.height < screenSize.width ? screenSize.height : screenSize.width) * 0.6;
    final glassAspect = 0.66; 

    return Scaffold(
      appBar: AppBar(title: const Text("Tilt to Pour")),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _completed ? "Full! (+1 Point)" : "Tilt your phone to pour water!",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 40),
                
                SizedBox(
                  height: canvasSize,
                  width: canvasSize * glassAspect,
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
        ),
      ),
    );
  }
}

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

    final Path glassPath = Path();
    glassPath.moveTo(20, 0);
    glassPath.lineTo(40, size.height);
    glassPath.lineTo(size.width - 40, size.height);
    glassPath.lineTo(size.width - 20, 0);
    
    canvas.drawPath(glassPath, glassPaint);

    if (fillLevel > 0) {
      double waterHeight = size.height * fillLevel;
      double topY = size.height - waterHeight;

      Rect waterRect = Rect.fromLTRB(
        40,
        topY, 
        size.width - 40, 
        size.height
      );
      
      canvas.drawRect(waterRect, waterPaint);
    }

    if (isPouring) {
      final Paint streamPaint = Paint()
        ..color = Colors.blue.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0;

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