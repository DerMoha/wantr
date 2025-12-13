import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/revealed_segment.dart';
import '../../core/services/osm_street_service.dart';
import '../widgets/resource_bar.dart';
import '../widgets/map_controls.dart';
import '../widgets/player_stats_panel.dart';
import 'account_screen.dart';

/// Main game map screen - shows the map with fog of war
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _isFollowingUser = true;
  bool _showStats = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final gameProvider = context.read<GameProvider>();
    await gameProvider.startTracking();
    
    // Center on user location when available
    if (gameProvider.currentLocation != null) {
      _mapController.move(gameProvider.currentLocation!, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          final currentLocation = gameProvider.currentLocation;
          final osmStreets = gameProvider.osmService.cachedStreets;
          final revealedSegmentIds = gameProvider.revealedSegments.map((s) => s.id).toSet();
          
          return Stack(
            children: [
              // Map Layer
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: currentLocation ?? const LatLng(52.52, 13.405), // Berlin default
                  initialZoom: 16.0,
                  minZoom: 10.0,
                  maxZoom: 19.0,
                  backgroundColor: WantrTheme.background,
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      setState(() => _isFollowingUser = false);
                    }
                  },
                ),
                children: [
                  // Base map layer - dark style
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.wantr.app',
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),
                  
                  // OSM Streets - Undiscovered segments (gray fog)
                  PolylineLayer(
                    polylines: _buildUndiscoveredPolylines(osmStreets, revealedSegmentIds),
                  ),
                  
                  // Revealed segments layer (gold/yellow based on walk count)
                  PolylineLayer(
                    polylines: _buildRevealedSegmentPolylines(gameProvider.revealedSegments),
                  ),
                  
                  // Current walk path
                  if (gameProvider.currentWalkPath.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: gameProvider.currentWalkPath,
                          color: WantrTheme.accent,
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),
                  
                  // Outpost markers
                  MarkerLayer(
                    markers: gameProvider.outposts.map((outpost) {
                      return Marker(
                        point: outpost.location,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: WantrTheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: WantrTheme.discovered,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: WantrTheme.discovered.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              outpost.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  // Player marker
                  if (currentLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentLocation,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: WantrTheme.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: WantrTheme.textPrimary,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: WantrTheme.accent.withOpacity(0.5),
                                  blurRadius: 12,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              
              // Resource bar at top
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: ResourceBar(),
                ),
              ),
              
              // Map controls
              Positioned(
                right: 16,
                bottom: 120,
                child: MapControls(
                  onCenterPressed: () {
                    if (currentLocation != null) {
                      _mapController.move(currentLocation, 16.0);
                      setState(() => _isFollowingUser = true);
                    }
                  },
                  onZoomIn: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  onZoomOut: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  isFollowing: _isFollowingUser,
                ),
              ),
              
              // Stats panel toggle
              Positioned(
                left: 16,
                bottom: 120,
                child: Column(
                  children: [
                    _buildAccountButton(),
                    const SizedBox(height: 8),
                    _buildStatsToggle(),
                  ],
                ),
              ),
              
              // Stats panel (slide in from left)
              if (_showStats)
                const Positioned(
                  left: 16,
                  bottom: 180,
                  child: PlayerStatsPanel(),
                ),
              
              // Tracking indicator
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildTrackingIndicator(gameProvider),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build polylines for undiscovered street segments (gray fog)
  List<Polyline> _buildUndiscoveredPolylines(
    List<OsmStreet> osmStreets,
    Set<String> revealedSegmentIds,
  ) {
    final polylines = <Polyline>[];
    
    for (final street in osmStreets) {
      for (int i = 0; i < street.points.length - 1; i++) {
        final segmentId = '${street.id}_$i';
        
        // Only show as gray if this segment hasn't been revealed
        if (!revealedSegmentIds.contains(segmentId)) {
          polylines.add(Polyline(
            points: [street.points[i], street.points[i + 1]],
            color: WantrTheme.streetGray.withAlpha(100),
            strokeWidth: 3.0,
          ));
        }
      }
    }
    
    return polylines;
  }
  
  /// Build polylines for revealed segments
  /// Yellow = my discoveries, Green = teammate discoveries
  /// Gold/Legendary progression only for my own discoveries
  List<Polyline> _buildRevealedSegmentPolylines(List<RevealedSegment> segments) {
    return segments.map((segment) {
      Color color;
      double strokeWidth;
      
      if (!segment.discoveredByMe) {
        // Teammate discovery - green
        color = WantrTheme.streetTeamGreen;
        strokeWidth = 4.0;
      } else {
        // My discovery - yellow/gold progression
        color = switch (segment.state) {
          SegmentState.legendary => WantrTheme.streetLegendary,
          SegmentState.mastered => WantrTheme.streetGold,
          SegmentState.discovered => WantrTheme.streetYellow,
          SegmentState.teamDiscovered => WantrTheme.streetTeamGreen,
          SegmentState.undiscovered => WantrTheme.streetGray,
        };
        
        strokeWidth = switch (segment.state) {
          SegmentState.legendary => 6.0,
          SegmentState.mastered => 5.0,
          SegmentState.discovered => 4.0,
          SegmentState.teamDiscovered => 4.0,
          SegmentState.undiscovered => 2.0,
        };
      }
      
      return Polyline(
        points: segment.points,
        color: color,
        strokeWidth: strokeWidth,
      );
    }).toList();
  }

  Widget _buildAccountButton() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      ),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: WantrTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: WantrTheme.undiscovered,
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.person_outline,
          color: WantrTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildStatsToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showStats = !_showStats),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: WantrTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: WantrTheme.undiscovered,
            width: 1,
          ),
        ),
        child: Icon(
          _showStats ? Icons.close : Icons.bar_chart,
          color: WantrTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTrackingIndicator(GameProvider gameProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: WantrTheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gameProvider.isTracking 
              ? WantrTheme.energy 
              : WantrTheme.undiscovered,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: gameProvider.isTracking 
                  ? WantrTheme.energy 
                  : WantrTheme.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            gameProvider.isTracking ? 'Tracking' : 'Paused',
            style: TextStyle(
              color: gameProvider.isTracking 
                  ? WantrTheme.energy 
                  : WantrTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${gameProvider.discoveredStreets.length} streets',
            style: const TextStyle(
              color: WantrTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
