/// This is the main entry point of the Flutter application.
/// This file is responsible for setting up the app's root widget and managing the main UI.
/// It defines the structure and behavior of the app's home page and floating action buttons.


// Dart import statements bring in external libraries or packages into the current file.
// The 'material.dart' package provides a set of visual, structural, platform, and interactive widgets
// following the Material Design guidelines.
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';


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
  _PageTab _selectedTab = _PageTab.timeline;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final List<_CalendarEvent> _calendarEvents = [];
  final List<_Vaccine> _vaccines = [];
  final List<_Measurement> _measurements = [];

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
    _loadPersistedData();
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
    _persistState();
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

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabName = prefs.getString(_prefsKeySelectedTab);
      final eventsJson = prefs.getString(_prefsKeyEvents);
      final calendarJson = prefs.getString(_prefsKeyCalendar);
      final vaccineJson = prefs.getString(_prefsKeyVaccines);
      final measurementJson = prefs.getString(_prefsKeyMeasurements);

      setState(() {
        if (tabName != null) {
          _selectedTab = _PageTab.values.firstWhere(
            (t) => t.name == tabName,
            orElse: () => _PageTab.timeline,
          );
        }
        if (eventsJson != null) {
          final decoded = (jsonDecode(eventsJson) as List)
              .map((e) => _Event.fromMap(e as Map<String, dynamic>))
              .toList();
          _events
            ..clear()
            ..addAll(decoded);
        }
        if (calendarJson != null) {
          final decoded = (jsonDecode(calendarJson) as List)
              .map((e) => _CalendarEvent.fromMap(e as Map<String, dynamic>))
              .toList();
          _calendarEvents
            ..clear()
            ..addAll(decoded);
        }
        if (vaccineJson != null) {
          final decoded = (jsonDecode(vaccineJson) as List)
              .map((e) => _Vaccine.fromMap(e as Map<String, dynamic>))
              .toList();
          _vaccines
            ..clear()
            ..addAll(decoded);
        }
        if (measurementJson != null) {
          final decoded = (jsonDecode(measurementJson) as List)
              .map((e) => _Measurement.fromMap(e as Map<String, dynamic>))
              .toList();
          _measurements
            ..clear()
            ..addAll(decoded);
        }
      });
    } catch (_) {
      // ignore corrupt persistence
    }
  }

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyEvents,
        jsonEncode(_events.map((e) => e.toMap()).toList()),
      );
      await prefs.setString(
        _prefsKeyCalendar,
        jsonEncode(_calendarEvents.map((e) => e.toMap()).toList()),
      );
      await prefs.setString(
        _prefsKeyVaccines,
        jsonEncode(_vaccines.map((v) => v.toMap()).toList()),
      );
      await prefs.setString(
        _prefsKeyMeasurements,
        jsonEncode(_measurements.map((m) => m.toMap()).toList()),
      );
      await prefs.setString(_prefsKeySelectedTab, _selectedTab.name);
    } catch (_) {
      // ignore write errors
    }
  }

  Map<_ActivityType, int> _eventCountsLast24Hours() {
    final now = DateTime.now();
    final counts = {for (final type in _ActivityType.values) type: 0};
    for (final event in _events) {
      if (now.difference(event.time) <= const Duration(hours: 24)) {
        counts[event.activity] = (counts[event.activity] ?? 0) + 1;
      }
    }
    return counts;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
  }

  Future<void> _promptAddVaccine() async {
    DateTime? selectedDate = DateTime.now();
    bool administered = false;
    final nameController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<_Vaccine>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Add Vaccine',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Vaccine name',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g., DTaP booster',
                      filled: true,
                      fillColor: const Color(0xFFF5F6F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setLocalState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF5F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(selectedDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E2E42),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Notes (optional)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Additional details...',
                      filled: true,
                      fillColor: const Color(0xFFF5F6F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Checkbox(
                        value: administered,
                        onChanged: (val) => setLocalState(() => administered = val ?? false),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Already administered',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final title = nameController.text.trim().isEmpty
                            ? 'Vaccine'
                            : nameController.text.trim();
                        Navigator.of(ctx).pop(
                          _Vaccine(
                            name: title,
                            date: selectedDate ?? DateTime.now(),
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                            administered: administered,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2EB872),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );

    if (result == null) return;
    setState(() {
      _vaccines.add(result);
    });
    _persistState();
  }

  Future<void> _promptAddCalendarEvent() async {
    DateTime? selectedDate = DateTime.now();
    _CalendarEventType selectedType = _CalendarEventType.doctor;
    final titleController = TextEditingController(text: 'Doctor visit');
    final notesController = TextEditingController();

    final result = await showDialog<_CalendarEvent>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Add Appointment',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Date',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setLocalState(() => selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF5F6F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E2E42),
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Type',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<_CalendarEventType>(
                      value: selectedType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF5F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      items: _CalendarEventType.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                _calendarEventTypeLabel(t),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E2E42),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (t) => setLocalState(() => selectedType = t ?? selectedType),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Title',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Pediatrician checkup',
                        filled: true,
                        fillColor: const Color(0xFFF5F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Notes (optional)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Additional details...',
                        filled: true,
                        fillColor: const Color(0xFFF5F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final eventTitle = titleController.text.trim().isEmpty
                              ? _calendarEventTypeLabel(selectedType)
                              : titleController.text.trim();
                          Navigator.of(ctx).pop(
                            _CalendarEvent(
                              date: selectedDate ?? DateTime.now(),
                              title: eventTitle,
                              type: selectedType,
                              notes: notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E8BFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Add Appointment'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _calendarEvents.add(result);
    });
    _persistState();
  }

  Future<void> _promptAddMeasurement() async {
    DateTime? selectedDate = DateTime.now();
    final heightController = TextEditingController();
    final weightController = TextEditingController();
    final commentController = TextEditingController();

    final result = await showDialog<_Measurement>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Add Measurement',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocalState(() => selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF5F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(selectedDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E2E42),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Height (cm)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: heightController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'e.g., 70',
                      filled: true,
                      fillColor: const Color(0xFFF5F6F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Weight (kg)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: weightController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'e.g., 6.5',
                      filled: true,
                      fillColor: const Color(0xFFF5F6F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Comment (optional)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: commentController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Notes or context...',
                      filled: true,
                      fillColor: const Color(0xFFF5F6F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final height = double.tryParse(heightController.text.trim());
                        final weight = double.tryParse(weightController.text.trim());
                        if (height == null && weight == null) {
                          Navigator.of(ctx).pop();
                          return;
                        }
                        Navigator.of(ctx).pop(
                          _Measurement(
                            date: selectedDate ?? DateTime.now(),
                            heightCm: height,
                            weightKg: weight,
                            comment: commentController.text.trim().isEmpty
                                ? null
                                : commentController.text.trim(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E8BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );

    if (result == null) return;
    setState(() {
      _measurements.add(result);
    });
    _persistState();
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
    final counts = _eventCountsLast24Hours();
    // Scaffold provides a basic visual layout structure for the app,
    // including app bar, body, floating action button, and more.
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 92,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(18)),
                gradient: LinearGradient(
                  colors: [Color(0xFF5E8BFF), Color(0xFF9248F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.child_care_outlined,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Parent Companion',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E2E42),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Monitor your little one's routine",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6F7390),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                _PageSelector(
                  selected: _selectedTab,
                  onSelected: (tab) {
                    setState(() => _selectedTab = tab);
                    _persistState();
                  },
                ),
                const SizedBox(height: 20),
                ..._buildPageContent(counts),
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

  List<Widget> _buildPageContent(Map<_ActivityType, int> counts) {
    if (_selectedTab == _PageTab.timeline) {
      return [
        Text(
          'Activity Timeline',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2E2E42),
              ),
        ),
        const SizedBox(height: 4),
        const SizedBox(height: 16),
        _buildTimelineCard(),
        const SizedBox(height: 16),
        _buildSummaryCard(counts),
      ];
    }

    if (_selectedTab == _PageTab.calendar) {
      return [
        Text(
          'Calendar',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2E2E42),
              ),
        ),
        const SizedBox(height: 4),
        const SizedBox(height: 16),
        _buildCalendarCard(),
      ];
    }

    if (_selectedTab == _PageTab.vaccines) {
      return _buildVaccineContent();
    }

    if (_selectedTab == _PageTab.growth) {
      return _buildGrowthContent();
    }

    final label = _tabLabel(_selectedTab);
    return [_buildPlaceholderCard(title: label, description: 'This view is coming soon. Stay tuned!')];
  }

  Widget _buildTimelineCard() {
    return Container(
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
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: _ActivityType.values
                .map(
                  (type) => _EventButton(
                    color: _activityColors[type]!,
                    icon: _buildActivityIcon(type, 18),
                    onPressed: () => _addEvent(type),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<_ActivityType, int> counts) {
    return Container(
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
          Text(
            'Last 24 hours summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2E2E42),
                ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _ActivityType.values.map((type) {
                  final count = counts[type] ?? 0;
                  final accent = _activityColors[type]!;
                  return SizedBox(
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _activityCardBackgrounds[type] ?? accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildActivityIcon(type, 22),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: accent.withOpacity(0.95),
                                ),
                              ),
                              Text(
                                _activityLabel(type),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: accent.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildVaccineContent() {
    final completed = _vaccines.where((v) => v.administered).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final upcoming = _vaccines.where((v) => !v.administered).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vaccine Tracker',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2E2E42),
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '${completed.length} completed · ${upcoming.length} upcoming',
                style: const TextStyle(color: Color(0xFF6F7390), fontSize: 14),
              ),
            ],
          ),
          SizedBox(
            width: 160,
            child: _PrimaryGradientButton(
              onPressed: _promptAddVaccine,
              label: 'Add Vaccine',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildVaccineSection(
        title: 'Upcoming Vaccines',
        icon: Icons.schedule,
        iconColor: const Color(0xFFFFA22C),
        vaccines: upcoming,
      ),
      const SizedBox(height: 14),
      _buildVaccineSection(
        title: 'Completed Vaccines',
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF2EB872),
        vaccines: completed,
      ),
    ];
  }

  Widget _buildVaccineSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_Vaccine> vaccines,
  }) {
    return Container(
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
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E2E42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (vaccines.isEmpty)
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Icon(Icons.remove_circle_outline, size: 40, color: Color(0xFFC2C6D6)),
                    SizedBox(height: 6),
                    Text(
                      'No vaccines recorded yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6F7390)),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: vaccines
                  .map(
                    (v) => GestureDetector(
                      onTap: () {
                        setState(() {
                          final idx = _vaccines.indexOf(v);
                          if (idx != -1) _vaccines[idx] = v.toggleAdministered();
                        });
                        _persistState();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: v.administered
                                ? const Color(0xFF2EB872).withOpacity(0.4)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              v.administered ? Icons.check_circle : Icons.pending_outlined,
                              color: v.administered ? const Color(0xFF2EB872) : iconColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E2E42),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(v.date),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6F7390),
                                    ),
                                  ),
                                  if (v.notes != null && v.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      v.notes!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF4B4F67),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: v.administered
                                    ? const Color(0xFF2EB872).withOpacity(0.15)
                                    : iconColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                v.administered ? 'Done' : 'Tap to check',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: v.administered
                                      ? const Color(0xFF2EB872)
                                      : iconColor.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGrowthContent() {
    final sorted = [..._measurements]..sort((a, b) => a.date.compareTo(b.date));
    final latestHeight = sorted.reversed.firstWhere(
      (m) => m.heightCm != null,
      orElse: () => _Measurement(date: DateTime.now()),
    );
    final latestWeight = sorted.reversed.firstWhere(
      (m) => m.weightKg != null,
      orElse: () => _Measurement(date: DateTime.now()),
    );

    return [
      _buildGrowthSummaryCard(
        measurementCount: sorted.length,
        latestHeight: latestHeight.heightCm,
        latestWeight: latestWeight.weightKg,
      ),
      const SizedBox(height: 16),
      _buildGrowthChartCard(
        title: 'Height Growth',
        icon: Icons.straighten,
        color: const Color(0xFF5E8BFF),
        points: sorted
            .where((m) => m.heightCm != null)
            .map((m) => _GrowthPoint(date: m.date, value: m.heightCm!))
            .toList(),
        unit: 'cm',
      ),
      const SizedBox(height: 12),
      _buildGrowthChartCard(
        title: 'Weight Growth',
        icon: Icons.fitness_center,
        color: const Color(0xFFB048F5),
        points: sorted
            .where((m) => m.weightKg != null)
            .map((m) => _GrowthPoint(date: m.date, value: m.weightKg!))
            .toList(),
        unit: 'kg',
      ),
      const SizedBox(height: 12),
      _buildMeasurementHistory(sorted),
    ];
  }

  Widget _buildGrowthSummaryCard({
    required int measurementCount,
    double? latestHeight,
    double? latestWeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxWidth < 420;
        return Container(
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
              if (isTight) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.show_chart, color: Color(0xFF5E8BFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Growth Tracker',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E2E42),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$measurementCount measurement${measurementCount == 1 ? '' : 's'} recorded',
                            style: const TextStyle(color: Color(0xFF6F7390)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PrimaryGradientButton(
                  onPressed: _promptAddMeasurement,
                  label: 'Add Measurement',
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.show_chart, color: Color(0xFF5E8BFF)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Growth Tracker',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2E2E42),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$measurementCount measurement${measurementCount == 1 ? '' : 's'} recorded',
                              style: const TextStyle(color: Color(0xFF6F7390)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 170,
                      child: _PrimaryGradientButton(
                        onPressed: _promptAddMeasurement,
                        label: 'Add Measurement',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _GrowthStatCard(
                      title: 'Latest Height',
                      value: latestHeight != null ? latestHeight.toStringAsFixed(1) : '--',
                      unit: 'cm',
                      color: const Color(0xFFE8F1FF),
                      icon: Icons.straighten,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GrowthStatCard(
                      title: 'Latest Weight',
                      value: latestWeight != null ? latestWeight.toStringAsFixed(1) : '--',
                      unit: 'kg',
                      color: const Color(0xFFF3E8FF),
                      icon: Icons.monitor_weight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrowthChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<_GrowthPoint> points,
    required String unit,
  }) {
    return Container(
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
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E2E42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'No data yet',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: _GrowthChart(
                points: points,
                color: color,
                unit: unit,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeasurementHistory(List<_Measurement> measurements) {
    final sorted = [...measurements]..sort((a, b) => b.date.compareTo(a.date));
    return Container(
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
          Row(
            children: const [
              Icon(Icons.history, color: Color(0xFF5E8BFF)),
              SizedBox(width: 8),
              Text(
                'Measurement History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E2E42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  'No measurements recorded yet',
                  style: TextStyle(color: Color(0xFF6F7390)),
                ),
              ),
            )
          else
            Column(
              children: sorted
                  .map(
                    (m) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF3F6FF), Color(0xFFF9F3FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E4F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _formatFullDate(m.date),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E2E42),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF6F7390)),
                                onPressed: () {
                                  setState(() {
                                    _measurements.remove(m);
                                  });
                                  _persistState();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (m.heightCm != null) ...[
                                const Icon(Icons.straighten, color: Color(0xFF5E8BFF)),
                                const SizedBox(width: 4),
                                Text(
                                  '${m.heightCm!.toStringAsFixed(1)} cm',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E2E42),
                                  ),
                                ),
                              ],
                              if (m.heightCm != null && m.weightKg != null) const SizedBox(width: 14),
                              if (m.weightKg != null) ...[
                                const Icon(Icons.fitness_center, color: Color(0xFFB048F5)),
                                const SizedBox(width: 4),
                                Text(
                                  '${m.weightKg!.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E2E42),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (m.comment != null && m.comment!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              m.comment!,
                              style: const TextStyle(color: Color(0xFF4B4F67)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7; // 0 = Sun
    final totalCells = firstWeekday + daysInMonth;
    final monthLabel = '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year.toString()}';
    final monthEvents = _calendarEvents
        .where(
          (e) => e.date.year == _currentMonth.year && e.date.month == _currentMonth.month,
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Column(
                children: [
                  Text(
                    monthLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E2E42),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${monthEvents.length} event${monthEvents.length == 1 ? '' : 's'} this month',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6F7390),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _CalendarHeaderCell(label: 'Sun'),
              _CalendarHeaderCell(label: 'Mon'),
              _CalendarHeaderCell(label: 'Tue'),
              _CalendarHeaderCell(label: 'Wed'),
              _CalendarHeaderCell(label: 'Thu'),
              _CalendarHeaderCell(label: 'Fri'),
              _CalendarHeaderCell(label: 'Sat'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((totalCells / 7).ceil() * 7),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - firstWeekday + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
              final hasEvent = monthEvents.any((e) => _isSameDay(e.date, date));
              final isToday = _isSameDay(date, DateTime.now());
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: hasEvent ? const Color(0xFFE8F1FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isToday ? const Color(0xFF5E8BFF) : Colors.grey.shade300,
                    width: isToday ? 1.6 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2E2E42).withOpacity(hasEvent ? 0.95 : 0.8),
                        ),
                      ),
                    ),
                    if (hasEvent)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E8BFF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Event',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _PrimaryGradientButton(
            onPressed: _promptAddCalendarEvent,
            label: 'Add appointment',
          ),
          const SizedBox(height: 8),
          if (monthEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...monthEvents.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5E8BFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${e.date.day.toString().padLeft(2, '0')}/${e.date.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E2E42),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_calendarEventTypeLabel(e.type)} — ${e.title}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF2E2E42),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (e.notes != null && e.notes!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              e.notes!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6F7390),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard({required String title, required String description}) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2E2E42),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6F7390),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEvent {
  _CalendarEvent({
    required this.date,
    required this.title,
    required this.type,
    this.notes,
  });

  final DateTime date;
  final String title;
  final _CalendarEventType type;
  final String? notes;

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'title': title,
        'type': type.name,
        'notes': notes,
      };

  static _CalendarEvent fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? _CalendarEventType.doctor.name;
    final type = _CalendarEventType.values
        .firstWhere((t) => t.name == typeName, orElse: () => _CalendarEventType.doctor);
    return _CalendarEvent(
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      title: map['title'] as String? ?? 'Event',
      type: type,
      notes: map['notes'] as String?,
    );
  }
}

class _Measurement {
  _Measurement({
    required this.date,
    this.heightCm,
    this.weightKg,
    this.comment,
  });

  final DateTime date;
  final double? heightCm;
  final double? weightKg;
  final String? comment;

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'heightCm': heightCm,
        'weightKg': weightKg,
        'comment': comment,
      };

  static _Measurement fromMap(Map<String, dynamic> map) {
    return _Measurement(
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      comment: map['comment'] as String?,
    );
  }
}

class _Vaccine {
  _Vaccine({
    required this.name,
    required this.date,
    this.notes,
    this.administered = false,
  });

  final String name;
  final DateTime date;
  final String? notes;
  final bool administered;

  _Vaccine toggleAdministered() => _Vaccine(
        name: name,
        date: date,
        notes: notes,
        administered: !administered,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'date': date.toIso8601String(),
        'notes': notes,
        'administered': administered,
      };

  static _Vaccine fromMap(Map<String, dynamic> map) {
    return _Vaccine(
      name: map['name'] as String? ?? 'Vaccine',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      notes: map['notes'] as String?,
      administered: map['administered'] as bool? ?? false,
    );
  }
}

enum _CalendarEventType { doctor, test, vaccine, other }

class _CalendarHeaderCell extends StatelessWidget {
  const _CalendarHeaderCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF6F7390),
          ),
        ),
      ),
    );
  }
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5E8BFF), Color(0xFF9248F5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowthStatCard extends StatelessWidget {
  const _GrowthStatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Icon(icon, color: const Color(0xFF5E8BFF)),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E2E42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2E2E42),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(color: Color(0xFF6F7390)),
          ),
        ],
      ),
    );
  }
}

class _GrowthPoint {
  _GrowthPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.points, required this.color, required this.unit});

  final List<_GrowthPoint> points;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _GrowthChartPainter(points: points, color: color, unit: unit),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  _GrowthChartPainter({required this.points, required this.color, required this.unit});

  final List<_GrowthPoint> points;
  final Color color;
  final String unit;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    final minY = 0.0;
    final maxY = sorted.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final yRange = (maxY - minY).abs() < 0.1 ? (maxY == 0 ? 1 : maxY) : (maxY - minY);
    final minX = sorted.first.date.millisecondsSinceEpoch.toDouble();
    final maxX = sorted.last.date.millisecondsSinceEpoch.toDouble();
    final xRange = maxX == minX ? 1 : (maxX - minX);

    const padding = EdgeInsets.fromLTRB(36, 16, 16, 32);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;

    // Y axis and ticks.
    const tickCount = 4;
    for (var i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final y = padding.top + chartHeight - t * chartHeight;
      final value = minY + yRange * t;
      final tp = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(1),
          style: const TextStyle(fontSize: 11, color: Color(0xFF6F7390)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
      canvas.drawLine(Offset(padding.left, y), Offset(size.width - padding.right, y),
          axisPaint..color = Colors.grey.shade300);
    }

    // X labels.
    for (var i = 0; i < sorted.length; i++) {
      final x =
          padding.left + ((sorted[i].date.millisecondsSinceEpoch - minX) / xRange) * chartWidth;
      final dateLabel = _formatShortDate(sorted[i].date);
      final tp = TextPainter(
        text: TextSpan(
          text: dateLabel,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6F7390)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - padding.bottom + 6));
    }

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < sorted.length; i++) {
      final px = padding.left +
          ((sorted[i].date.millisecondsSinceEpoch - minX) / xRange) * chartWidth;
      final py = padding.top + chartHeight - ((sorted[i].value - minY) / yRange) * chartHeight;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, linePaint);

    // Points
    for (final p in sorted) {
      final px = padding.left + ((p.date.millisecondsSinceEpoch - minX) / xRange) * chartWidth;
      final py = padding.top + chartHeight - ((p.value - minY) / yRange) * chartHeight;
      canvas.drawCircle(
        Offset(px, py),
        5,
        Paint()..color = color,
      );
    }

    // Unit label
    final unitPainter = TextPainter(
      text: TextSpan(
        text: unit,
        style: const TextStyle(fontSize: 12, color: Color(0xFF6F7390), fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    unitPainter.paint(canvas, Offset(size.width - padding.right - unitPainter.width, padding.top));
  }

  String _formatShortDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

/// _NoiseType is an enum representing the types of noise available.
/// Enums in Dart define a fixed set of constant values.
/// Using enums here is preferable to strings because it provides type safety and prevents invalid values.
enum _NoiseType { white, brown }

enum _PageTab { timeline, calendar, vaccines, growth }

const _prefsKeyEvents = 'prefs_events';
const _prefsKeyCalendar = 'prefs_calendar';
const _prefsKeyVaccines = 'prefs_vaccines';
const _prefsKeyMeasurements = 'prefs_measurements';
const _prefsKeySelectedTab = 'prefs_selected_tab';

String _calendarEventTypeLabel(_CalendarEventType type) {
  switch (type) {
    case _CalendarEventType.doctor:
      return 'Doctor';
    case _CalendarEventType.test:
      return 'Test';
    case _CalendarEventType.vaccine:
      return 'Vaccine';
    case _CalendarEventType.other:
      return 'Other';
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'yyyy-mm-dd';
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

String _formatDisplayDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatFullDate(DateTime date) {
  return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
}

class _PageSelector extends StatelessWidget {
  const _PageSelector({required this.selected, required this.onSelected});

  final _PageTab selected;
  final ValueChanged<_PageTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F4FF), Color(0xFFF9F3FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: _PageTab.values.map((tab) {
          final isActive = tab == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _tabLabel(tab),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: const Color(0xFF1F2430),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

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

enum _ActivityType { bottle, diaper, poop, nap, shower, tummyTime, pumping, medication }

const _activityColors = <_ActivityType, Color>{
  _ActivityType.bottle: Color(0xFF6BA6FF),
  _ActivityType.diaper: Color(0xFFFFC85B),
  _ActivityType.poop: Color(0xFFB07C57),
  _ActivityType.nap: Color(0xFFB48CFF),
  _ActivityType.shower: Color(0xFF6ED3C2),
  _ActivityType.tummyTime: Color(0xFFFF9EC7),
  _ActivityType.pumping: Color(0xFF5BC8F6),
  _ActivityType.medication: Color(0xFF74C27F),
};

const _activityCardBackgrounds = <_ActivityType, Color>{
  _ActivityType.bottle: Color(0xFFE8F1FF),
  _ActivityType.diaper: Color(0xFFFFF4DB),
  _ActivityType.poop: Color(0xFFF1E1D3),
  _ActivityType.nap: Color(0xFFF1E8FF),
  _ActivityType.shower: Color(0xFFE4FFF7),
  _ActivityType.tummyTime: Color(0xFFFFE8F2),
  _ActivityType.pumping: Color(0xFFE8F7FF),
  _ActivityType.medication: Color(0xFFE9F7EB),
};

const _activityIcons = <_ActivityType, IconData?>{
  _ActivityType.bottle: Icons.local_drink_outlined,
  _ActivityType.diaper: Icons.baby_changing_station,
  _ActivityType.poop: null, // uses custom asset
  _ActivityType.nap: Icons.nightlight_round,
  _ActivityType.shower: Icons.shower_outlined,
  _ActivityType.tummyTime: Icons.self_improvement,
  _ActivityType.pumping: Icons.opacity,
  _ActivityType.medication: Icons.medication_outlined,
};

String _tabLabel(_PageTab tab) {
  switch (tab) {
    case _PageTab.timeline:
      return 'Timeline';
    case _PageTab.calendar:
      return 'Calendar';
    case _PageTab.vaccines:
      return 'Vaccines';
    case _PageTab.growth:
      return 'Growth';
  }
}

String _activityLabel(_ActivityType type) {
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
    case _ActivityType.tummyTime:
      return 'Tummy Time';
    case _ActivityType.pumping:
      return 'Pumping';
    case _ActivityType.medication:
      return 'Medication';
  }
}

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

  Map<String, dynamic> toMap() => {
        'activity': activity.name,
        'time': time.toIso8601String(),
      };

  static _Event fromMap(Map<String, dynamic> map) {
    final activityName = map['activity'] as String? ?? _ActivityType.bottle.name;
    final activity =
        _ActivityType.values.firstWhere((a) => a.name == activityName, orElse: () => _ActivityType.bottle);
    return _Event(
      activity: activity,
      time: DateTime.tryParse(map['time'] as String? ?? '') ?? DateTime.now(),
    );
  }
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
      case _ActivityType.tummyTime:
        return 'Tummy Time';
      case _ActivityType.pumping:
        return 'Pumping';
      case _ActivityType.medication:
        return 'Medication';
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
