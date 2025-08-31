import 'package:flutter/material.dart';

// TODO: get fluttermap and gps in here
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wantr")),
      body: const Center(
        child: Text("Map goes here"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Open dialog to add a new post
        },
        child: const Icon(Icons.add_location),
      ),
    );
  }
}
