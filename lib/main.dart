import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const WantrApp());
}

class WantrApp extends StatelessWidget {
  const WantrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explorer',
      theme: ThemeData.dark(),
      home: const MapScreen(), // Startbildschirm
    );
  }
}
