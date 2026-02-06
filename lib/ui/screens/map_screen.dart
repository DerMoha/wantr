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
  LatLng? _lastFollowedLocation;
  bool _showStats = false;
  bool _isOnline = true;
  bool _isTogglingTracking = false;

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
      builder: (dialogContext) => WelcomeDialog(
        onComplete: () async {
          final navigator = Navigator.of(dialogContext);
          settings.hasSeenOnboarding = true;
          await settings.save();
          if (mounted && navigator.mounted) {
            navigator.pop();
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

    _connectivitySubscription = _connectivityService.statusStream.listen((
      isOnline,
    ) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
  }

  Future<void> _initializeLocation() async {
    final gameProvider = context.read<GameProvider>();
    await gameProvider.startTracking();

    if (!mounted) return;

    final location = gameProvider.currentLocation;
    if (location != null) {
      _mapController.move(location, 16.0);
      _lastFollowedLocation = location;
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTogglingTracking) return;

    final gameProvider = context.read<GameProvider>();
    final wasTracking = gameProvider.isTracking;

    setState(() => _isTogglingTracking = true);

    try {
      if (wasTracking) {
        await gameProvider.stopTracking();
      } else {
        await gameProvider.startTracking();
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingTracking = false);
      }
    }

    if (!mounted) return;

    final didStart = gameProvider.isTracking;
    final didStop = !gameProvider.isTracking;

    if (!wasTracking && didStart) {
      HapticFeedback.mediumImpact();
    } else if (wasTracking && didStop) {
      HapticFeedback.lightImpact();
    }
  }

  /// Keep map centered on the user while follow-mode is enabled.
  void _followUserIfNeeded(LatLng currentLocation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isFollowingUser) return;

      final previousFollowedLocation = _lastFollowedLocation;
      if (previousFollowedLocation != null) {
        final movedMeters = _calculateDistance(
          previousFollowedLocation,
          currentLocation,
        );
        if (movedMeters < 5) {
          return; // Avoid jittery recentering for tiny GPS movement.
        }
      }

      try {
        _mapController.move(currentLocation, _mapController.camera.zoom);
        _lastFollowedLocation = currentLocation;
      } catch (_) {
        // Map camera may not be ready on first frame.
      }
    });
  }

  int _countDiscoveredStreets(GameProvider gameProvider) {
    return gameProvider.revealedSegments
        .map((segment) => segment.streetId)
        .toSet()
        .length;
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
    if (totals['tradeGoods']! > 0) {
      collected.add('+${totals['tradeGoods']} goods');
    }
    if (totals['materials']! > 0) {
      collected.add('+${totals['materials']} materials');
    }
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
          final revealedSegmentIds = gameProvider.revealedSegments
              .map((s) => s.id)
              .toSet();
          final discoveredStreetCount = _countDiscoveredStreets(gameProvider);

          if (_isFollowingUser && currentLocation != null) {
            _followUserIfNeeded(currentLocation);
          }

          return Stack(
            children: [
              // Map Layer
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: currentLocation ?? const LatLng(52.52, 13.405),
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
                      osmStreets,
                      revealedSegmentIds,
                    ),
                  ),

                  // Revealed segments layer (gold progression)
                  PolylineLayer(
                    polylines: _buildRevealedSegmentPolylines(
                      gameProvider.revealedSegments,
                    ),
                  ),

                  // Current walk path (ink trail effect)
                  if (gameProvider.currentWalkPath.isNotEmpty)
                    ..._buildWalkTrail(
                      gameProvider,
                    ).map((w) => RepaintBoundary(child: w)),

                  // Trail breadcrumbs
                  if (gameProvider.currentWalkPath.isNotEmpty)
                    ..._buildBreadcrumbs(
                      gameProvider,
                    ).map((w) => RepaintBoundary(child: w)),

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
                child: SafeArea(child: ResourceBar()),
              ),

              // Right-side controls stack (map controls + actions)
              Positioned(
                right: 16,
                bottom: 90,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MapControls(
                      onCenterPressed: () {
                        if (currentLocation != null) {
                          // Always center on user and reset rotation
                          _mapController.move(
                            currentLocation,
                            _mapController.camera.zoom,
                          );
                          _lastFollowedLocation = currentLocation;
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
                    const SizedBox(height: 12),
                    if (gameProvider.anyOutpostHasResources) ...[
                      FloatingActionButton.small(
                        heroTag: 'collect_all',
                        onPressed: () => _collectAllResources(),
                        backgroundColor: WantrTheme.energy,
                        foregroundColor: WantrTheme.background,
                        elevation: 4,
                        child: const Icon(Icons.download_done, size: 20),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Stack(
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
                  ],
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
                        MaterialPageRoute(
                          builder: (_) => const AccountScreen(),
                        ),
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
                    pendingSyncCount:
                        gameProvider.cloudSyncService.pendingSyncCount,
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
                    isLocating: gameProvider.isLocating,
                    hasAccurateLocation: gameProvider.hasAccurateLocation,
                    accuracyMeters: gameProvider.locationAccuracyMeters,
                    streetCount: discoveredStreetCount,
                    pulseAnimation: _pulseAnimation,
                    pendingSyncCount:
                        gameProvider.cloudSyncService.pendingSyncCount,
                    isBusy: _isTogglingTracking,
                    onTap: _toggleTracking,
                  ),
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
          polylines.add(
            Polyline(
              points: [street.points[i], street.points[i + 1]],
              color: WantrTheme.fogPurple.withAlpha(60),
              strokeWidth: 3.0,
            ),
          );
        }
      }
    }

    return polylines;
  }

  /// Build polylines for revealed segments with cartographic styling
  List<Polyline> _buildRevealedSegmentPolylines(
    List<RevealedSegment> segments,
  ) {
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

    for (
      int i = path.length - 2;
      i >= 0 && accumulatedDistance < maxDistance;
      i--
    ) {
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
      outerGlowLines.add(
        Polyline(
          points: segmentPoints,
          color: WantrTheme.brass.withOpacity(0.25 * opacity),
          strokeWidth: 12.0,
        ),
      );

      // Middle glow
      middleGlowLines.add(
        Polyline(
          points: segmentPoints,
          color: WantrTheme.brass.withOpacity(0.5 * opacity),
          strokeWidth: 6.0,
        ),
      );

      // Inner core
      innerCoreLines.add(
        Polyline(
          points: segmentPoints,
          color: WantrTheme.brassLight.withOpacity(opacity),
          strokeWidth: 2.5,
        ),
      );

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

    for (
      int i = path.length - 2;
      i >= 0 && accumulatedDistance < maxDistance;
      i--
    ) {
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
      if (i == 0 ||
          (distFromEnd - lastBreadcrumbDist).abs() >= breadcrumbSpacing) {
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
                    color: WantrTheme.brass.withOpacity(
                      0.4 * _pulseAnimation.value * opacity,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: WantrTheme.brass.withOpacity(
                          0.2 * _pulseAnimation.value * opacity,
                        ),
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
          colors: [WantrTheme.brass, WantrTheme.brassDark],
        ),
        border: Border.all(color: WantrTheme.parchment, width: 3),
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
          colors: [WantrTheme.parchment, WantrTheme.parchmentDark],
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
      child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
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
                  color: WantrTheme.energy.withOpacity(
                    0.4 * pulseAnimation!.value,
                  ),
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
  final bool isLocating;
  final bool hasAccurateLocation;
  final double? accuracyMeters;
  final int streetCount;
  final Animation<double> pulseAnimation;
  final int pendingSyncCount;
  final bool isBusy;
  final VoidCallback onTap;

  const _TrackingIndicator({
    required this.isTracking,
    required this.isLocating,
    required this.hasAccurateLocation,
    required this.accuracyMeters,
    required this.streetCount,
    required this.pulseAnimation,
    required this.pendingSyncCount,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trackingReady = isTracking && hasAccurateLocation && !isLocating;
    final locatingNow = isTracking && !trackingReady;

    final statusColor = trackingReady
        ? WantrTheme.tracking
        : locatingNow
        ? WantrTheme.warning
        : WantrTheme.brass;

    final icon = trackingReady
        ? Icons.gps_fixed_rounded
        : locatingNow
        ? Icons.gps_not_fixed_rounded
        : Icons.play_arrow_rounded;

    final title = isBusy
        ? 'UPDATING'
        : trackingReady
        ? 'TRACKING'
        : locatingNow
        ? 'LOCATING'
        : 'START TRACKING';

    final subtitle = trackingReady
        ? accuracyMeters != null
              ? 'GPS lock ±${accuracyMeters!.round()}m'
              : 'GPS lock active'
        : locatingNow
        ? 'Finding accurate position...'
        : 'Tap to begin charting';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                WantrTheme.surface.withOpacity(0.96),
                Color.lerp(
                  WantrTheme.backgroundAlt,
                  statusColor,
                  locatingNow ? 0.2 : 0.14,
                )!.withOpacity(0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: statusColor.withOpacity(trackingReady ? 0.65 : 0.45),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: WantrTheme.shadowDeep.withOpacity(0.45),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: statusColor.withOpacity(
                  trackingReady
                      ? 0.24
                      : locatingNow
                      ? 0.2
                      : 0.12,
                ),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  final pulseValue = locatingNow || trackingReady
                      ? 0.75 + (pulseAnimation.value * 0.35)
                      : 1.0;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (locatingNow || trackingReady)
                        Container(
                          width: 36 * pulseValue,
                          height: 36 * pulseValue,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor.withOpacity(0.12),
                          ),
                        ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withOpacity(0.18),
                          border: Border.all(
                            color: statusColor.withOpacity(0.6),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(icon, size: 18, color: statusColor),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cormorant(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 1.6,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.crimsonPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: WantrTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: WantrTheme.background.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: WantrTheme.brass.withOpacity(0.25)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$streetCount',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WantrTheme.brass,
                      ),
                    ),
                    Text(
                      'STREETS',
                      style: GoogleFonts.crimsonPro(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: WantrTheme.textMuted,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
              if (pendingSyncCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: WantrTheme.copper.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: WantrTheme.copper.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 13,
                        color: WantrTheme.copperLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$pendingSyncCount',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: WantrTheme.copperLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isBusy) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ],
          ),
        ),
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
          Icon(Icons.cloud_off_outlined, color: WantrTheme.parchment, size: 20),
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
