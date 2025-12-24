/// This is the main entry point of the Flutter application.
/// This file is responsible for setting up the app's root widget and managing the main UI.
/// It defines the structure and behavior of the app's home page and floating action buttons.


// Dart import statements bring in external libraries or packages into the current file.
// The 'material.dart' package provides a set of visual, structural, platform, and interactive widgets
// following the Material Design guidelines.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';


// The main() function is the entry point of every Dart application.
// In Flutter, main() calls runApp(), which takes the given widget and makes it the root of the widget tree.
// Passing MyApp() to runApp() tells Flutter to inflate and display the MyApp widget when the app starts.
void main() {
  runApp(const MyApp());
}


/// MyApp is a StatelessWidget, which means it describes part of the user interface by building a constellation of other widgets.
/// StatelessWidgets are immutable and should be used when the UI does not depend on any mutable state.
/// MyApp is stateless because it only sets up the app's theme and home page, which do not change dynamically.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// The build method is called whenever the widget needs to be rendered.
/// It describes the part of the UI represented by this widget.
/// The BuildContext argument provides information about the location of this widget in the widget tree,
/// which can be used to access theme data, localization, and other inherited widgets.
/// Flutter rebuilds widgets when their configuration changes or when setState is called on a StatefulWidget.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The title property sets the title of the application.
      // On some platforms, this may be used as the window title or task description.
      title: 'Parent Companion',

      // The theme property defines the overall visual theme of the app.
      // It controls colors, fonts, and other design aspects.
      theme: ThemeData(
        // The colorScheme defines the colors used throughout the app.
        // Using ColorScheme.fromSeed generates a color scheme based on a seed color.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),

      // The home property specifies the default route of the app,
      // which is displayed when the app starts.
      home: const MyHomePage(title: 'Parent Companion'),
    );
  }
}


/// MyHomePage is a StatefulWidget, which means it has mutable state that can change over time.
/// This widget needs state because it tracks user interactions like button presses and toggle states,
/// which affect the UI dynamically.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  /// The title field is marked as final, meaning it cannot be changed after being set.
  /// Data is passed into widgets via constructor parameters like this,
  /// allowing widgets to receive configuration information.
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}


/// The State class holds the mutable state for a StatefulWidget.
/// Separating the widget from its state allows Flutter to rebuild widgets efficiently while preserving state.
/// The leading underscore in Dart means this class is private to the library,
/// preventing it from being accessed outside this file.
class _MyHomePageState extends State<MyHomePage> {
  /// _player handles audio playback for the looping noise tracks.
  late final AudioPlayer _player;
  final ScrollController _timelineController = ScrollController();
  double _hoursSpan = 24;

  /// _isFabExpanded tracks whether the floating action button options are expanded or not.
  /// This boolean state controls the visibility and animation of additional buttons.
  bool _isFabExpanded = false;

  /// _activeNoise stores which noise type (white or brown) is currently active.
  /// It is nullable because no noise may be active at times.
  /// This state controls the UI to indicate which noise is playing.
  _NoiseType? _activeNoise;
  final List<_Event> _events = [];

  /// Initializes the looping audio player.
  @override
  void initState() {
    super.initState();
    _player = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timelineController.hasClients) {
        _timelineController.jumpTo(_timelineController.position.maxScrollExtent);
      }
    });
    _timelineController.addListener(_handleTimelineScroll);
  }


  /// _toggleNoise toggles the active xnoise type and starts/stops playback accordingly.
  /// It closes the expanded FAB options after selection.
  Future<void> _toggleNoise(_NoiseType type) async {
    final nextNoise = _activeNoise == type ? null : type;
    setState(() {
      _activeNoise = nextNoise;
      _isFabExpanded = false;
    });
    await _handleNoiseChange(nextNoise);
  }

  void _addEvent(_ActivityType activity) {
    final now = DateTime.now();
    setState(() {
      _events.add(_Event(activity: activity, time: now));
      _events.removeWhere((e) => now.difference(e.time) > const Duration(hours: 24));
    });
  }

  void _handleTimelineScroll() {
    if (!_timelineController.hasClients) return;
    if (_timelineController.offset <= 30) {
      setState(() {
        _hoursSpan += 24;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_timelineController.hasClients) {
          _timelineController.jumpTo(
            _timelineController.offset + _TimelinePainter.pxPerHour * 24,
          );
        }
      });
    }
  }

  /// Starts or stops the looping audio when the active noise changes.
  Future<void> _handleNoiseChange(_NoiseType? nextNoise) async {
    if (nextNoise == null) {
      await _player.stop();
      return;
    }

    // Ensure we don't overlap noises when switching.
    await _player.stop();

    final source = switch (nextNoise) {
      _NoiseType.white => AssetSource('audio/white_noise.wav'),
      _NoiseType.brown => AssetSource('audio/brown_noise.wav'),
    };

    await _player.play(source);
  }

  @override
  void dispose() {
    _player.dispose();
    _timelineController.removeListener(_handleTimelineScroll);
    _timelineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold provides a basic visual layout structure for the app,
    // including app bar, body, floating action button, and more.
    return Scaffold(
      // AppBar is the top toolbar that typically contains the title and actions.
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      // The body is the main content area of the screen.
      // Center centers its child widget within itself.
      // Column arranges its children vertically.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F9FF), Color(0xFFFDF7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Activity Timeline',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E2E42),
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Last 24 hours of activity',
                  style: TextStyle(color: Color(0xFF6F7390)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _TimelinePainter.canvasHeight,
                        child: _Timeline(
                          events: _events,
                          controller: _timelineController,
                          hoursSpanHours: _hoursSpan,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _EventButton(
                            color: _activityColors[_ActivityType.bottle]!,
                            icon: _buildActivityIcon(_ActivityType.bottle, 18),
                            onPressed: () => _addEvent(_ActivityType.bottle),
                          ),
                          _EventButton(
                            color: _activityColors[_ActivityType.diaper]!,
                            icon: _buildActivityIcon(_ActivityType.diaper, 18),
                            onPressed: () => _addEvent(_ActivityType.diaper),
                          ),
                          _EventButton(
                            color: _activityColors[_ActivityType.poop]!,
                            icon: _buildActivityIcon(_ActivityType.poop, 18),
                            onPressed: () => _addEvent(_ActivityType.poop),
                          ),
                          _EventButton(
                            color: _activityColors[_ActivityType.nap]!,
                            icon: _buildActivityIcon(_ActivityType.nap, 18),
                            onPressed: () => _addEvent(_ActivityType.nap),
                          ),
                          _EventButton(
                            color: _activityColors[_ActivityType.shower]!,
                            icon: _buildActivityIcon(_ActivityType.shower, 18),
                            onPressed: () => _addEvent(_ActivityType.shower),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // floatingActionButtonLocation controls where the floating action button is placed on the screen.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Stack is used here to allow multiple floating action buttons to overlap and be positioned relative to each other.
      // This enables the expanding/collapsing effect of multiple FAB options.
      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomRight,
        children: [
          // AnimatedSlide provides a sliding animation for its child.
          // When _isFabExpanded is true, the offset is zero (no slide),
          // otherwise it slides down slightly.
          AnimatedSlide(
            offset: _isFabExpanded ? Offset.zero : const Offset(0, 0.2),
            duration: const Duration(milliseconds: 200),
            // AnimatedOpacity animates the opacity of its child.
            // It fades in when _isFabExpanded is true, and fades out when false.
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isFabExpanded ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 72.0),
                child: _ExpandingAction(
                  label: _activeNoise == _NoiseType.white ? 'Stop White Noise' : 'White Noise',
                  icon: _activeNoise == _NoiseType.white ? Icons.volume_off : Icons.volume_up,
                  onPressed: () => _toggleNoise(_NoiseType.white),
                  heroTag: 'noise_white',
                ),
              ),
            ),
          ),
          // Another AnimatedSlide and AnimatedOpacity pair for the brown noise button.
          AnimatedSlide(
            offset: _isFabExpanded ? Offset.zero : const Offset(0, 0.2),
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isFabExpanded ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 132.0),
                child: _ExpandingAction(
                  label: _activeNoise == _NoiseType.brown ? 'Stop Brown Noise' : 'Brown Noise',
                  icon: _activeNoise == _NoiseType.brown ? Icons.volume_off : Icons.volume_up,
                  onPressed: () => _toggleNoise(_NoiseType.brown),
                  heroTag: 'noise_brown',
                ),
              ),
            ),
          ),
          // The main FloatingActionButton controls the expansion and collapse of the additional FAB options.
          // AnimatedRotation smoothly rotates the plus icon when toggling.
          // The icon rotates 45 degrees (0.125 turns) when expanded to indicate the close action.
          FloatingActionButton(
            onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
            tooltip: _isFabExpanded ? 'Close options' : 'Show options',
            child: AnimatedRotation(
              turns: _isFabExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

/// _NoiseType is an enum representing the types of noise available.
/// Enums in Dart define a fixed set of constant values.
/// Using enums here is preferable to strings because it provides type safety and prevents invalid values.
enum _NoiseType { white, brown }

/// _ExpandingAction is a stateless widget representing one of the expanding floating action buttons.
/// It exists to encapsulate the UI and behavior of the labeled button with an icon.
/// This widget is stateless because it only depends on the parameters passed to it and does not manage any internal state.
/// It helps keep the code modular and reusable.
class _ExpandingAction extends StatelessWidget {
  /// The label displayed next to the button.
  final String label;

  /// The icon displayed inside the floating action button.
  final IconData icon;

  /// The callback function executed when the button is pressed.
  final VoidCallback onPressed;

  /// The heroTag is used for hero animations and must be unique among FABs.
  final String heroTag;

  const _ExpandingAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    // Padding adds space below the entire row to separate it from other elements.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      // Row arranges the label and button horizontally.
      // mainAxisSize.min makes the row only as wide as its children.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Container styles the label with background color, padding, margin, and rounded corners.
          // The semi-transparent black background improves readability on various backgrounds.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          // FloatingActionButton.small provides a smaller FAB for compact UI.
          // It uses the passed icon and onPressed callback.
          FloatingActionButton.small(
            heroTag: heroTag,
            onPressed: onPressed,
            child: Icon(icon),
          ),
        ],
      ),
    );
  }
}

enum _ActivityType { bottle, diaper, poop, nap, shower }

const _activityColors = <_ActivityType, Color>{
  _ActivityType.bottle: Color(0xFF6BA6FF),
  _ActivityType.diaper: Color(0xFFFFC85B),
  _ActivityType.poop: Color(0xFFB07C57),
  _ActivityType.nap: Color(0xFFB48CFF),
  _ActivityType.shower: Color(0xFF6ED3C2),
};

const _activityIcons = <_ActivityType, IconData?>{
  _ActivityType.bottle: Icons.local_drink_outlined,
  _ActivityType.diaper: Icons.baby_changing_station,
  _ActivityType.poop: null, // uses custom asset
  _ActivityType.nap: Icons.nightlight_round,
  _ActivityType.shower: Icons.shower_outlined,
};

Widget _buildActivityIcon(_ActivityType type, double size) {
  final iconData = _activityIcons[type];
  final color = _activityColors[type]!;
  if (iconData != null) {
    return Icon(iconData, color: color, size: size);
  }
  if (type == _ActivityType.poop) {
    return Image.asset(
      'assets/images/poop.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
  return Icon(Icons.circle, color: color, size: size);
}

class _Event {
  _Event({required this.activity, required this.time});

  final _ActivityType activity;
  final DateTime time;
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.events,
    required this.controller,
    required this.hoursSpanHours,
  });

  final List<_Event> events;
  final ScrollController controller;
  final double hoursSpanHours;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final filtered = events
        .where((e) => now.difference(e.time) <= const Duration(hours: 24))
        .toList();

    return SizedBox(
      height: _TimelinePainter.canvasHeight,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _TimelinePainter.topPadding - 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: _ActivityType.values
                  .map(
                    (type) => SizedBox(
                      height: _TimelinePainter.rowHeight,
                      width: 44,
                          child: Center(child: _buildActivityIcon(type, 20)),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: controller,
              child: ClipRect(
                child: CustomPaint(
                  size: Size(
                    _TimelinePainter.widthForHours(hoursSpanHours),
                    _TimelinePainter.canvasHeight,
                  ),
                  painter: _TimelinePainter(filtered, now, hoursSpanHours),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter(this.events, this.now, this.hoursSpanHours)
      : chartWidth = widthForHours(hoursSpanHours);

  final List<_Event> events;
  final DateTime now;
  final double hoursSpanHours;
  final double chartWidth;

  static const double rowHeight = 44;
  static const double laneHeight = rowHeight - 10;
  static const double topPadding = 20;
  static const double bottomPadding = 8;
  static const double leftPadding = 16;
  static const double rightPadding = 12;
  static const double pxPerHour = 50;
  static double widthForHours(double hours) =>
      leftPadding + rightPadding + pxPerHour * hours;
  static double get canvasHeight =>
      topPadding + rowHeight * _ActivityType.values.length + bottomPadding;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;

    // Draw lane backgrounds.
    for (var i = 0; i < _ActivityType.values.length; i++) {
      final laneTop = topPadding + i * rowHeight;
      final laneRect = Rect.fromLTWH(
        leftPadding,
        laneTop,
        chartWidth - leftPadding - rightPadding,
        laneHeight,
      );
      final laneColor = _activityColors[_ActivityType.values[i]]!;
      final laneRRect = RRect.fromRectAndRadius(laneRect, const Radius.circular(10));
      canvas.drawRRect(
        laneRRect,
        Paint()..color = laneColor.withOpacity(0.06),
      );
      canvas.drawRRect(
        laneRRect,
        Paint()
          ..color = laneColor.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Draw hour markers.
    final end = now.add(const Duration(hours: 2));
    final timeBase = DateTime(end.year, end.month, end.day, end.hour); // snap to hour
    final start = timeBase.subtract(Duration(hours: hoursSpanHours.toInt()));
    final displayBase = start;
    final spanHoursInt = hoursSpanHours.toInt();
    for (var h = 0; h <= spanHoursInt; h++) {
      final t = start.add(Duration(hours: h));
      final x = _xForTime(t, start);
      // Only draw the hour label (no vertical grid lines).
      final labelTime = displayBase.add(Duration(hours: h));
      final hh = labelTime.hour.toString().padLeft(2, '0');
      const mm = '00';
      _drawText(
        canvas,
        '$hh:$mm',
        Offset(x - 18, 0),
        color: const Color(0xFF6F7390),
      );
      paint.color = Colors.grey.shade400; // reset
    }

    // Draw events.
    for (final event in events.where((e) => e.time.isAfter(start))) {
      final idx = _ActivityType.values.indexOf(event.activity);
      final laneTop = topPadding + idx * rowHeight;
      final y = laneTop + laneHeight / 2;
      final x = _xForTime(event.time, start);
      canvas.drawCircle(
        Offset(x, y),
        6,
        Paint()..color = _activityColors[event.activity]!,
      );
    }
  }

  double _xForTime(DateTime time, DateTime start) {
    final totalMs = Duration(hours: hoursSpanHours.toInt()).inMilliseconds.toDouble();
    final offsetMs = time.difference(start).inMilliseconds.toDouble().clamp(0, totalMs);
    final usableWidth = chartWidth - leftPadding - rightPadding;
    return leftPadding + (offsetMs / totalMs) * usableWidth;
  }

  void _drawText(Canvas canvas, String text, Offset offset, {Color color = Colors.black54}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 12, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  String _labelFor(_ActivityType type) {
    switch (type) {
      case _ActivityType.bottle:
        return 'Bottle';
      case _ActivityType.diaper:
        return 'Diaper';
      case _ActivityType.poop:
        return 'Poop';
      case _ActivityType.nap:
        return 'Nap';
      case _ActivityType.shower:
        return 'Shower';
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.events != events || oldDelegate.now != now;
  }
}

class _EventButton extends StatelessWidget {
  const _EventButton({
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final Color color;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.16),
        foregroundColor: const Color(0xFF2E2E42),
        shadowColor: Colors.transparent,
        padding: EdgeInsets.zero,
        minimumSize: const Size(52, 44),
        fixedSize: const Size(52, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: icon),
          ),
        ],
      ),
    );
  }
}
