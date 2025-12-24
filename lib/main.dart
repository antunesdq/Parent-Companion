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
  /// _counter keeps track of how many times the button has been pressed.
  /// It is part of the state because it changes in response to user actions,
  /// and the UI needs to update to reflect the new value.
  int _counter = 0;

  /// _isFabExpanded tracks whether the floating action button options are expanded or not.
  /// This boolean state controls the visibility and animation of additional buttons.
  bool _isFabExpanded = false;

  /// _activeNoise stores which noise type (white or brown) is currently active.
  /// It is nullable because no noise may be active at times.
  /// This state controls the UI to indicate which noise is playing.
  _NoiseType? _activeNoise;

  /// Initializes the looping audio player.
  @override
  void initState() {
    super.initState();
    _player = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  }

  /// _incrementCounter increases the _counter state by one.
  /// Calling setState tells Flutter that the state has changed and the UI should be rebuilt to reflect the update.
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  /// _toggleNoise toggles the active noise type and starts/stops playback accordingly.
  /// It closes the expanded FAB options after selection.
  Future<void> _toggleNoise(_NoiseType type) async {
    final nextNoise = _activeNoise == type ? null : type;
    setState(() {
      _activeNoise = nextNoise;
      _isFabExpanded = false;
    });
    await _handleNoiseChange(nextNoise);
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
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
