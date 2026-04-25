import 'package:flutter/material.dart';

/// Entry point — full implementation in Sprint 9.
/// Dependencies are locked in pubspec.yaml.
void main() {
  runApp(const _PlaceholderApp());
}

class _PlaceholderApp extends StatelessWidget {
  const _PlaceholderApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'PharmaLearn',
      home: Scaffold(
        body: Center(child: Text('PharmaLearn — Sprint 9 WIP')),
      ),
    );
  }
}
