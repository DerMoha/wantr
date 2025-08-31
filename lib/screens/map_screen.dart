import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {

    // Check  if dark mode is enabled
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String tileUrl = isDarkMode
        ? 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}{r}.png';

    return Scaffold(
      appBar: AppBar(title: const Text("Wantr Map")),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(52.5200, 13.4050), // Use Berlin as startpoint
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: tileUrl,
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.sonding.wantr',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(52.5200, 13.4050),
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
