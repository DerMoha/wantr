import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/outpost.dart';
import '../../core/models/revealed_segment.dart';
import '../../core/models/app_settings.dart';
import '../../core/services/osm_street_service.dart';
import '../../core/services/connectivity_service.dart';
import '../widgets/resource_bar.dart';
import '../widgets/map_controls.dart';
import '../widgets/player_stats_panel.dart';
import '../widgets/build_outpost_dialog.dart';
import '../widgets/outpost_details_panel.dart';
import '../widgets/welcome_dialog.dart';
import '../widgets/help_guide_panel.dart';
import 'account_screen.dart';
import 'stats_screen.dart';

/// Main game map screen - "The Cartographer's Chronicle"
/// Features fog of war mechanics with an explorer's atlas aesthetic
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

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  bool _isFollowingUser = true;
  bool _showStats = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeConnectivity();
    _checkFirstLaunch();

    // Pulse animation for markers
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow animation for player marker
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  Future<void> _checkFirstLaunch() async {
    final settingsBox = await Hive.openBox<dynamic>('app_settings');
    AppSettings? settings = settingsBox.get('settings');

    if (settings == null) {
      settings = AppSettings();
      await settingsBox.put('settings', settings);
    }

    if (!settings.hasSeenOnboarding && mounted) {
      // Short delay to let the map load first
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showWelcomeDialog(settings);
      }
    }
  }

  void _showWelcomeDialog(AppSettings settings) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WelcomeDialog(
        onComplete: () async {
          settings.hasSeenOnboarding = true;
          await settings.save();
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showHelpGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HelpGuidePanel(),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _initializeConnectivity() async {
    await _connectivityService.initialize();
    _isOnline = _connectivityService.isOnline;

    _connectivitySubscription =
        _connectivityService.statusStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
  }

  Future<void> _initializeLocation() async {
    final gameProvider = context.read<GameProvider>();
    await gameProvider.startTracking();

    if (gameProvider.currentLocation != null) {
      _mapController.move(gameProvider.currentLocation!, 16.0);
    }
  }

  void _showBuildOutpostDialog() {
    showDialog(
      context: context,
      builder: (context) => const BuildOutpostDialog(),
    );
  }

  void _showOutpostDetails(Outpost outpost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => OutpostDetailsPanel(outpost: outpost),
    );
  }

  Future<void> _collectAllResources() async {
    final gameProvider = context.read<GameProvider>();
    final totals = await gameProvider.collectAllOutposts();

    if (!mounted) return;

    // Build summary message
    final collected = <String>[];
    if (totals['gold']! > 0) collected.add('+${totals['gold']} gold');
    if (totals['tradeGoods']! > 0) collected.add('+${totals['tradeGoods']} goods');
    if (totals['materials']! > 0) collected.add('+${totals['materials']} materials');
    if (totals['energy']! > 0) collected.add('+${totals['energy']} energy');

    if (collected.isEmpty) return;

    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Collected: ${collected.join(', ')}',
          style: GoogleFonts.crimsonPro(),
        ),
        backgroundColor: WantrTheme.energy,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          final currentLocation = gameProvider.currentLocation;
          final osmStreets = gameProvider.osmService.cachedStreets;
          final revealedSegmentIds =
              gameProvider.revealedSegments.map((s) => s.id).toSet();

          return Stack(
            children: [
              // Map Layer
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      currentLocation ?? const LatLng(52.52, 13.405),
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
                  // Base map layer - dark maritime style
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.wantr.app',
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),

                  // OSM Streets - Undiscovered segments (fog)
                  PolylineLayer(
                    polylines: _buildUndiscoveredPolylines(
                        osmStreets, revealedSegmentIds),
                  ),

                  // Revealed segments layer (gold progression)
                  PolylineLayer(
                    polylines: _buildRevealedSegmentPolylines(
                        gameProvider.revealedSegments),
                  ),

                  // Current walk path (ink trail effect)
                  if (gameProvider.currentWalkPath.isNotEmpty)
                    ..._buildWalkTrail(gameProvider)
                        .map((w) => RepaintBoundary(child: w)),

                  // Trail breadcrumbs
                  if (gameProvider.currentWalkPath.isNotEmpty)
                    ..._buildBreadcrumbs(gameProvider)
                        .map((w) => RepaintBoundary(child: w)),

                  // Outpost markers (tappable)
                  MarkerLayer(
                    markers: gameProvider.outposts.map((outpost) {
                      return Marker(
                        point: outpost.location,
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => _showOutpostDetails(outpost),
                          child: _OutpostMarker(
                            icon: outpost.icon,
                            hasResources: outpost.hasResourcesToCollect,
                            pulseAnimation: _pulseAnimation,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Player marker with animated glow
                  if (currentLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentLocation,
                          width: 32,
                          height: 32,
                          child: AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, child) {
                              return _PlayerMarker(
                                glowOpacity: _glowAnimation.value,
                              );
                            },
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

              // Map controls (right side)
              Positioned(
                right: 16,
                bottom: 140,
                child: MapControls(
                  onCenterPressed: () {
                    if (currentLocation != null) {
                      // Always center on user and reset rotation
                      _mapController.move(currentLocation, _mapController.camera.zoom);
                      _mapController.rotate(0);
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
                  onHelpPressed: _showHelpGuide,
                  isFollowing: _isFollowingUser,
                ),
              ),

              // Navigation buttons (left side)
              Positioned(
                left: 16,
                bottom: 140,
                child: Column(
                  children: [
                    _NavigationButton(
                      icon: Icons.person_outline,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountScreen()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _NavigationButton(
                      icon: Icons.auto_graph,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StatsScreen()),
                      ),
                      isHighlighted: true,
                    ),
                    const SizedBox(height: 10),
                    _NavigationButton(
                      icon: _showStats ? Icons.close : Icons.menu_book_outlined,
                      onTap: () => setState(() => _showStats = !_showStats),
                    ),
                  ],
                ),
              ),

              // Stats panel (slide in from left)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                left: _showStats ? 16 : -240,
                bottom: 220,
                child: const PlayerStatsPanel(),
              ),

              // Offline banner
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                top: _isOnline ? -100 : MediaQuery.of(context).padding.top + 80,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isOnline ? 0.0 : 1.0,
                  child: _OfflineBanner(
                    pendingSyncCount: gameProvider.cloudSyncService.pendingSyncCount,
                  ),
                ),
              ),

              // Tracking indicator (bottom)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: _TrackingIndicator(
                    isTracking: gameProvider.isTracking,
                    streetCount: gameProvider.discoveredStreets.length,
                    pulseAnimation: _pulseAnimation,
                    pendingSyncCount: gameProvider.cloudSyncService.pendingSyncCount,
                  ),
                ),
              ),

              // Collect All FAB (only shows when resources ready)
              if (gameProvider.anyOutpostHasResources)
                Positioned(
                  right: 16,
                  bottom: 160,
                  child: FloatingActionButton.small(
                    heroTag: 'collect_all',
                    onPressed: () => _collectAllResources(),
                    backgroundColor: WantrTheme.energy,
                    foregroundColor: WantrTheme.background,
                    elevation: 4,
                    child: const Icon(Icons.download_done, size: 20),
                  ),
                ),

              // Build outpost FAB
              Positioned(
                right: 16,
                bottom: 90,
                child: Stack(
                  children: [
                    FloatingActionButton(
                      heroTag: 'build_outpost',
                      onPressed: currentLocation != null
                          ? () => _showBuildOutpostDialog()
                          : null,
                      backgroundColor: currentLocation != null
                          ? WantrTheme.brass
                          : WantrTheme.undiscovered,
                      foregroundColor: WantrTheme.background,
                      elevation: 4,
                      child: const Icon(Icons.add_location_alt),
                    ),
                    // Ready count badge
                    if (gameProvider.outpostsWithResourcesCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: WantrTheme.energy,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: WantrTheme.background,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            '${gameProvider.outpostsWithResourcesCount}',
                            style: GoogleFonts.jetBrainsMono(
                              color: WantrTheme.background,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build polylines for undiscovered street segments (fog)
  List<Polyline> _buildUndiscoveredPolylines(
    List<OsmStreet> osmStreets,
    Set<String> revealedSegmentIds,
  ) {
    try {
      final currentZoom = _mapController.camera.zoom;
      if (currentZoom < 14) return [];
    } catch (e) {
      // Map controller not ready
    }

    final polylines = <Polyline>[];

    for (final street in osmStreets) {
      for (int i = 0; i < street.points.length - 1; i++) {
        final segmentId = '${street.id}_$i';

        if (!revealedSegmentIds.contains(segmentId)) {
          polylines.add(Polyline(
            points: [street.points[i], street.points[i + 1]],
            color: WantrTheme.fogPurple.withAlpha(60),
            strokeWidth: 3.0,
          ));
        }
      }
    }

    return polylines;
  }

  /// Build polylines for revealed segments with cartographic styling
  List<Polyline> _buildRevealedSegmentPolylines(List<RevealedSegment> segments) {
    return segments.map((segment) {
      Color color;
      double strokeWidth;

      if (!segment.discoveredByMe) {
        // Teammate discovery - emerald
        color = WantrTheme.streetTeamGreen;
        strokeWidth = 3.5;
      } else {
        // My discovery - brass/gold progression
        color = switch (segment.state) {
          SegmentState.legendary => WantrTheme.streetLegendary,
          SegmentState.mastered => WantrTheme.streetGold,
          SegmentState.discovered => WantrTheme.discovered,
          SegmentState.teamDiscovered => WantrTheme.streetTeamGreen,
          SegmentState.undiscovered => WantrTheme.streetGray,
        };

        strokeWidth = switch (segment.state) {
          SegmentState.legendary => 5.5,
          SegmentState.mastered => 4.5,
          SegmentState.discovered => 3.5,
          SegmentState.teamDiscovered => 3.5,
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

  /// Build walk trail with fade effect (fades after ~20 meters)
  List<Widget> _buildWalkTrail(GameProvider gameProvider) {
    final path = gameProvider.currentWalkPath;
    if (path.length < 2) return [];

    // Calculate distance-limited trail (approximately 20 meters)
    // Work backwards from the end of the path
    final List<LatLng> fadingPath = [];
    double accumulatedDistance = 0;
    const maxDistance = 20.0; // meters
    
    fadingPath.add(path.last);
    
    for (int i = path.length - 2; i >= 0 && accumulatedDistance < maxDistance; i--) {
      final dist = _calculateDistance(path[i], path[i + 1]);
      accumulatedDistance += dist;
      fadingPath.insert(0, path[i]);
    }
    
    if (fadingPath.length < 2) return [];
    
    // Create gradient polylines with fading opacity
    final List<Polyline> outerGlowLines = [];
    final List<Polyline> middleGlowLines = [];
    final List<Polyline> innerCoreLines = [];
    
    double runningDistance = 0;
    
    for (int i = 0; i < fadingPath.length - 1; i++) {
      final segmentDist = _calculateDistance(fadingPath[i], fadingPath[i + 1]);
      
      // Calculate opacity based on distance from end (player position)
      // Distance from end = total accumulated distance - running distance
      final distanceFromEnd = accumulatedDistance - runningDistance;
      final fadeRatio = (distanceFromEnd / maxDistance).clamp(0.0, 1.0);
      final opacity = 1.0 - fadeRatio; // 1.0 at player, 0.0 at 20m back
      
      final segmentPoints = [fadingPath[i], fadingPath[i + 1]];
      
      // Outer glow
      outerGlowLines.add(Polyline(
        points: segmentPoints,
        color: WantrTheme.brass.withOpacity(0.25 * opacity),
        strokeWidth: 12.0,
      ));
      
      // Middle glow
      middleGlowLines.add(Polyline(
        points: segmentPoints,
        color: WantrTheme.brass.withOpacity(0.5 * opacity),
        strokeWidth: 6.0,
      ));
      
      // Inner core
      innerCoreLines.add(Polyline(
        points: segmentPoints,
        color: WantrTheme.brassLight.withOpacity(opacity),
        strokeWidth: 2.5,
      ));
      
      runningDistance += segmentDist;
    }

    return [
      PolylineLayer(polylines: outerGlowLines),
      PolylineLayer(polylines: middleGlowLines),
      PolylineLayer(polylines: innerCoreLines),
    ];
  }
  
  /// Calculate distance between two points in meters
  double _calculateDistance(LatLng a, LatLng b) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, a, b);
  }

  /// Build breadcrumb markers along the trail (within 20m, with fade)
  List<Widget> _buildBreadcrumbs(GameProvider gameProvider) {
    final path = gameProvider.currentWalkPath;
    if (path.length < 2) return [];

    // Calculate distance-limited breadcrumbs (same 20m as trail)
    final List<LatLng> fadingPath = [];
    final List<double> distances = []; // Distance from end for each point
    double accumulatedDistance = 0;
    const maxDistance = 20.0;
    
    fadingPath.add(path.last);
    distances.add(0);
    
    for (int i = path.length - 2; i >= 0 && accumulatedDistance < maxDistance; i--) {
      final dist = _calculateDistance(path[i], path[i + 1]);
      accumulatedDistance += dist;
      fadingPath.insert(0, path[i]);
      distances.insert(0, accumulatedDistance);
    }

    final List<Marker> markers = [];
    // Place breadcrumbs every ~5 meters
    double lastBreadcrumbDist = 0;
    const breadcrumbSpacing = 5.0;
    
    for (int i = 0; i < fadingPath.length; i++) {
      final distFromEnd = i < distances.length ? distances[i] : 0.0;
      
      // Only place breadcrumb if we've moved enough since last one
      if (i == 0 || (distFromEnd - lastBreadcrumbDist).abs() >= breadcrumbSpacing) {
        lastBreadcrumbDist = distFromEnd;
        
        // Calculate opacity based on distance from player
        final fadeRatio = (distFromEnd / maxDistance).clamp(0.0, 1.0);
        final opacity = 1.0 - fadeRatio;
        
        markers.add(
          Marker(
            point: fadingPath[i],
            width: 6,
            height: 6,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    color: WantrTheme.brass.withOpacity(0.4 * _pulseAnimation.value * opacity),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: WantrTheme.brass.withOpacity(0.2 * _pulseAnimation.value * opacity),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    return [MarkerLayer(markers: markers)];
  }
}

/// Player position marker styled as a brass compass point
class _PlayerMarker extends StatelessWidget {
  final double glowOpacity;

  const _PlayerMarker({required this.glowOpacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            WantrTheme.brass,
            WantrTheme.brassDark,
          ],
        ),
        border: Border.all(
          color: WantrTheme.parchment,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: WantrTheme.brass.withOpacity(glowOpacity),
            blurRadius: 16,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: WantrTheme.shadowDeep.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WantrTheme.parchment,
            boxShadow: [
              BoxShadow(
                color: WantrTheme.parchment.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outpost marker styled as a flag/banner
class _OutpostMarker extends StatelessWidget {
  final String icon;
  final bool hasResources;
  final Animation<double>? pulseAnimation;

  const _OutpostMarker({
    required this.icon,
    this.hasResources = false,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WantrTheme.parchment,
            WantrTheme.parchmentDark,
          ],
        ),
        border: Border.all(
          color: hasResources ? WantrTheme.energy : WantrTheme.brass,
          width: hasResources ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: WantrTheme.brass.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: WantrTheme.shadowDeep.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          icon,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );

    // Add glow effect when resources are ready
    if (hasResources && pulseAnimation != null) {
      return AnimatedBuilder(
        animation: pulseAnimation!,
        builder: (context, child) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: WantrTheme.energy.withOpacity(0.4 * pulseAnimation!.value),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(child: marker),
          );
        },
      );
    }

    return marker;
  }
}

/// Navigation button with cartographic styling
class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isHighlighted;

  const _NavigationButton({
    required this.icon,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              WantrTheme.surface.withOpacity(0.95),
              WantrTheme.backgroundAlt.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? WantrTheme.brass.withOpacity(0.6)
                : WantrTheme.brass.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: WantrTheme.shadowDeep.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            if (isHighlighted)
              BoxShadow(
                color: WantrTheme.brass.withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Icon(
          icon,
          color: isHighlighted ? WantrTheme.brass : WantrTheme.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}

/// Tracking indicator styled as a cartographer's status badge
class _TrackingIndicator extends StatelessWidget {
  final bool isTracking;
  final int streetCount;
  final Animation<double> pulseAnimation;
  final int pendingSyncCount;

  const _TrackingIndicator({
    required this.isTracking,
    required this.streetCount,
    required this.pulseAnimation,
    required this.pendingSyncCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WantrTheme.surface.withOpacity(0.95),
            WantrTheme.backgroundAlt.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isTracking
              ? WantrTheme.tracking.withOpacity(0.5)
              : WantrTheme.brass.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: WantrTheme.shadowDeep.withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated status indicator
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: (isTracking
                          ? WantrTheme.tracking
                          : WantrTheme.textMuted)
                      .withOpacity(pulseAnimation.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (isTracking)
                      BoxShadow(
                        color: WantrTheme.tracking.withOpacity(0.4 * pulseAnimation.value),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 10),

          Text(
            isTracking ? 'CHARTING' : 'PAUSED',
            style: GoogleFonts.cormorant(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isTracking ? WantrTheme.tracking : WantrTheme.textMuted,
              letterSpacing: 2.0,
            ),
          ),

          const SizedBox(width: 14),

          // Decorative separator
          Container(
            width: 1,
            height: 14,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  WantrTheme.brass.withOpacity(0.0),
                  WantrTheme.brass.withOpacity(0.4),
                  WantrTheme.brass.withOpacity(0.0),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          Text(
            '$streetCount',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: WantrTheme.brass,
            ),
          ),

          const SizedBox(width: 6),

          Text(
            'STREETS',
            style: GoogleFonts.crimsonPro(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: WantrTheme.textMuted,
              letterSpacing: 1.0,
            ),
          ),

          // Pending sync indicator
          if (pendingSyncCount > 0) ...[
            const SizedBox(width: 14),

            // Decorative separator
            Container(
              width: 1,
              height: 14,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    WantrTheme.brass.withOpacity(0.0),
                    WantrTheme.brass.withOpacity(0.4),
                    WantrTheme.brass.withOpacity(0.0),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            Icon(
              Icons.cloud_upload_outlined,
              size: 14,
              color: WantrTheme.copper,
            ),

            const SizedBox(width: 4),

            Text(
              '$pendingSyncCount',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: WantrTheme.copper,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Offline banner with cartographic styling
class _OfflineBanner extends StatelessWidget {
  final int pendingSyncCount;

  const _OfflineBanner({required this.pendingSyncCount});

  @override
  Widget build(BuildContext context) {
    final message = pendingSyncCount > 0
        ? '$pendingSyncCount ${pendingSyncCount == 1 ? 'discovery' : 'discoveries'} waiting to sync'
        : 'Charting offline. Will sync when connected.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WantrTheme.copper.withOpacity(0.9),
            WantrTheme.copperLight.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: WantrTheme.parchment.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WantrTheme.shadowDeep.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: WantrTheme.parchment,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.crimsonPro(
                color: WantrTheme.parchment,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
