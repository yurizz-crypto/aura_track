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
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  double _tiltX = 0.0;

  double _fillLevel = 0.0;
  bool _isPouring = false;
  bool _completed = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _audioPlayer.audioCache.prefix = 'lib/assets/sound/';
    _effectPlayer.audioCache.prefix = 'lib/assets/sound/';
    _startListeningToSensor();
  }

  void _startListeningToSensor() {
    _accelSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      if (_completed) return;

      setState(() {
        _tiltX = event.x;
        bool nowPouring = _tiltX.abs() > 5.0;

        if (nowPouring && !_isPouring) {
          _isPouring = true;
          _playPourSound();
        } else if (!nowPouring && _isPouring) {
          _isPouring = false;
          _stopPourSound();
        }

        if (_isPouring) {
          _fillGlass();
        }
      });
    });
  }

  Future<void> _playPourSound() async {
    try {
      await _effectPlayer.play(AssetSource('water_flow.mp3'));
    } catch(e) {
      // Nothing
    }
  }

  Future<void> _stopPourSound() async {
    try {
      await _effectPlayer.stop();
    } catch(e) {}
  }

  void _fillGlass() {
    if (_fillLevel < 1.0) {
      setState(() {
        double flowRate = (_tiltX.abs() - 4.0) / 500.0;
        if (flowRate < 0.005) flowRate = 0.005;
        _fillLevel += flowRate;
        _fillLevel = _fillLevel.clamp(0.0, 1.0);
      });
    } else {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    if (_completed) return;

    _completed = true;
    _isPouring = false;
    _accelSubscription?.cancel();
    _stopPourSound();

    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      await Supabase.instance.client.from('habit_logs').insert({
        'habit_id': widget.habitId,
        'user_id': userId,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      });

      await Supabase.instance.client.rpc('increment_points', params: {'row_id': userId});
    } catch (e) {
      print('Something went wrong. Try again later.');
    }

    try {
      await _audioPlayer.play(AssetSource('success.mp3'));
    } catch (e) {
      // Nothing
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
    _accelSubscription?.cancel();
    _audioPlayer.dispose();
    _effectPlayer.dispose();
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
                  _completed ? "Full! (+1 Point)" : "Tilt phone sideways to pour!",
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  height: canvasSize,
                  width: canvasSize * glassAspect,
                  child: CustomPaint(
                    painter: WaterGlassPainter(
                        fillLevel: _fillLevel > 1.0 ? 1.0 : _fillLevel,
                        isPouring: _isPouring,
                        tiltX: _tiltX
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text("Fill Level: ${(_fillLevel * 100).clamp(0, 100).toInt()}%"),
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
  final double tiltX;

  WaterGlassPainter({
    required this.fillLevel,
    required this.isPouring,
    required this.tiltX
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
    glassPath.moveTo(10, 0);
    glassPath.lineTo(30, size.height);
    glassPath.lineTo(size.width - 30, size.height);
    glassPath.lineTo(size.width - 10, 0);

    canvas.drawPath(glassPath, glassPaint);

    if (fillLevel > 0) {
      double waterHeight = size.height * fillLevel;
      double topY = size.height - waterHeight;

      Path waterPath = Path();
      waterPath.moveTo(10 + (20 * (1-fillLevel)), topY);
      waterPath.lineTo(30, size.height);
      waterPath.lineTo(size.width - 30, size.height);
      waterPath.lineTo(size.width - 10 - (20 * (1-fillLevel)), topY);

      canvas.drawPath(waterPath, waterPaint);
    }

    if (isPouring) {
      final Paint streamPaint = Paint()
        ..color = Colors.blue.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round;

      double startX = tiltX > 0 ? 0 : size.width;
      double endX = size.width / 2;

      canvas.drawLine(
          Offset(startX, -100),
          Offset(endX, size.height - (size.height * fillLevel)),
          streamPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaterGlassPainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel || oldDelegate.isPouring != isPouring;
  }
}