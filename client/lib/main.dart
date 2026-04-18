import 'package:flutter/material.dart';

/// Placeholder entrypoint until the app shell and database land in
/// subsequent commits (split for reviewable history).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Cestovni')),
        body: const Center(child: Text('Bootstrap')),
      ),
    ),
  );
}
