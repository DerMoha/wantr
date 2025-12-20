import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/revealed_segment.dart';
import '../../core/services/osm_street_service.dart';
import '../../core/services/connectivity_service.dart';
import '../widgets/resource_bar.dart';
import '../widgets/map_controls.dart';
import '../widgets/player_stats_panel.dart';
import 'account_screen.dart';
import 'stats_screen.dart';

/// Main game map screen - shows the map with fog of war
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isFollowingUser = true;
  bool _showStats = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeConnectivity();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeConnectivity() async {
    await _connectivityService.initialize();
    _isOnline = _connectivityService.isOnline;
    
    _connectivitySubscription = _connectivityService.statusStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
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
                    if (_isFollowingUser) {
                      // Already centered - reset rotation to north
                      _mapController.rotate(0);
                    } else if (currentLocation != null) {
                      // Not centered - center on user
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
              
              // Stats panel toggle and navigation
              Positioned(
                left: 16,
                bottom: 120,
                child: Column(
                  children: [
                    _buildAccountButton(),
                    const SizedBox(height: 8),
                    _buildStatsButton(),
                    const SizedBox(height: 8),
                    _buildStatsToggle(),
                  ],
                ),
              ),
              
              // Stats panel (slide in from left)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: _showStats ? 16 : -250,
                bottom: 200,
                child: const PlayerStatsPanel(),
              ),
              
              // Offline banner
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                top: _isOnline ? -100 : MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isOnline ? 0.0 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_off, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You\'re offline. Discoveries will sync soon.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
  /// Only renders when zoom level is high enough to prevent performance issues
  List<Polyline> _buildUndiscoveredPolylines(
    List<OsmStreet> osmStreets,
    Set<String> revealedSegmentIds,
  ) {
    // Don't render undiscovered streets when zoomed out (performance + visual clarity)
    try {
      final currentZoom = _mapController.camera.zoom;
      if (currentZoom < 14) {
        return [];
      }
    } catch (e) {
      // Map controller not ready yet, default to showing streets
    }
    
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
    return _ShellButton(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      ),
      icon: Icons.person_outline,
      color: WantrTheme.textPrimary,
    );
  }

  Widget _buildStatsButton() {
    return _ShellButton(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StatsScreen()),
      ),
      icon: Icons.insights,
      color: WantrTheme.discovered,
    );
  }

  Widget _buildStatsToggle() {
    return _ShellButton(
      onTap: () => setState(() => _showStats = !_showStats),
      icon: _showStats ? Icons.close : Icons.bar_chart,
      color: WantrTheme.textPrimary,
    );
  }

  Widget _buildTrackingIndicator(GameProvider gameProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: WantrTheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: gameProvider.isTracking 
              ? WantrTheme.energy.withOpacity(0.5) 
              : WantrTheme.undiscovered.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: (gameProvider.isTracking 
                      ? WantrTheme.energy 
                      : WantrTheme.textSecondary).withOpacity(_pulseAnimation.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (gameProvider.isTracking)
                      BoxShadow(
                        color: WantrTheme.energy.withOpacity(0.4 * _pulseAnimation.value),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            gameProvider.isTracking ? 'TRACKING' : 'PAUSED',
            style: TextStyle(
              color: gameProvider.isTracking 
                  ? WantrTheme.energy 
                  : WantrTheme.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 12,
            color: WantrTheme.undiscovered,
          ),
          const SizedBox(width: 12),
          Text(
            '${gameProvider.discoveredStreets.length} STREETS',
            style: const TextStyle(
              color: WantrTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const _ShellButton({
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: WantrTheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: WantrTheme.undiscovered.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }
}
