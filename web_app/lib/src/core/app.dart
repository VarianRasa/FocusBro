import 'dart:async';

import 'package:flutter/material.dart';

class FocusBroWebApp extends StatelessWidget {
  const FocusBroWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusBro Web',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF276A5B)),
        useMaterial3: true,
        splashFactory: InkSplash.splashFactory,
      ),
      home: const FocusHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FocusHomePage extends StatefulWidget {
  const FocusHomePage({super.key});

  @override
  State<FocusHomePage> createState() => _FocusHomePageState();
}

class _FocusHomePageState extends State<FocusHomePage> {
  static const _sessionLength = Duration(minutes: 25);
  Timer? _timer;
  var _remaining = _sessionLength;
  var _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
      return;
    }

    if (_remaining == Duration.zero) {
      setState(() => _remaining = _sessionLength);
    }
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= const Duration(seconds: 1)) {
        timer.cancel();
        setState(() {
          _remaining = Duration.zero;
          _isRunning = false;
        });
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remaining = _sessionLength;
      _isRunning = false;
    });
  }

  String get _formattedTime {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('FocusBro')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Make room for focused work',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'Choose one task, then give it your attention for a focused '
                  '25-minute session.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Text(
                        _formattedTime,
                        key: const ValueKey('focus-timer'),
                        style: theme.textTheme.displayLarge,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _toggleTimer,
                            icon: Icon(
                                _isRunning ? Icons.pause : Icons.play_arrow),
                            label: Text(_isRunning
                                ? 'Pause session'
                                : _remaining == Duration.zero
                                    ? 'Start again'
                                    : 'Start a focus session'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _resetTimer,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset'),
                          ),
                        ],
                      ),
                      if (_remaining == Duration.zero)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'Session complete. Take a short break.',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
