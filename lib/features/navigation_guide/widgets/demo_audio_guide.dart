import 'dart:async';

import 'package:flutter/material.dart';

class DemoAudioGuide extends StatefulWidget {
  const DemoAudioGuide({super.key});
  @override
  State<DemoAudioGuide> createState() => _DemoAudioGuideState();
}

class _DemoAudioGuideState extends State<DemoAudioGuide>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _seconds = 0;
  bool _playing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _pause() {
    _timer?.cancel();
    if (mounted) setState(() => _playing = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _toggle() {
    if (_playing) {
      _pause();
      return;
    }
    setState(() {
      if (_seconds >= 60) _seconds = 0;
      _playing = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= 60) _pause();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Demo audio guide',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('UI preview only. No audio recording is playing.'),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _seconds / 60,
            semanticsLabel: 'Demo playback progress',
          ),
          const SizedBox(height: 8),
          Text(
            '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')} / 01:00',
            key: const ValueKey('audio-progress'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _toggle,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              label: Text(_playing ? 'Pause demo' : 'Play demo'),
            ),
          ),
        ],
      ),
    ),
  );
}
