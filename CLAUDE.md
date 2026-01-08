# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Wantr ("The Wandering Trader") is a location-based mobile game built with Flutter. Players explore real-world streets to discover and reveal map segments, build outposts, and collaborate with teams. The game uses a "fog of war" mechanic where streets are revealed as the player walks near them.

## Build & Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build for release
flutter build apk
flutter build ios

# Run linting
flutter analyze

# Run tests
flutter test

# Generate Hive adapters (required after modifying @HiveType models)
dart run build_runner build --delete-conflicting-outputs

# Regenerate app icons
flutter pub run flutter_launcher_icons
```

## Architecture

### State Management
- **Provider pattern** with `GameProvider` as the central state manager (`lib/core/providers/game_provider.dart`)
- GameProvider owns location tracking, street discovery logic, cloud sync coordination, and all game state mutations
- Uses throttled `notifyListeners()` (max 2x/sec) to prevent UI jank during location updates

### Data Persistence
- **Hive** for local storage with generated adapters (`*.g.dart` files)
- Models requiring Hive persistence: `GameState`, `DiscoveredStreet`, `RevealedSegment`, `Outpost`, `AppSettings`
- Adapter type IDs 0-5 are registered in `lib/core/models/hive_adapters.dart`
- When adding new Hive fields, increment `@HiveField` indices - never reuse or change existing ones

### Backend Integration (Firebase)
- **Firebase Auth**: Google Sign-In, anonymous auth, email/password
- **Cloud Firestore**: Team data, revealed segments sync, user profiles
- Sync is WiFi-aware and uses debouncing/buffering to minimize quota usage
- Real-time team segment sync via Firestore streams with incremental sync support (`lastTeamSyncAt`)

### Services Layer (`lib/core/services/`)
| Service | Purpose |
|---------|---------|
| `LocationService` | GPS tracking with configurable accuracy modes |
| `OsmStreetService` | Fetches OpenStreetMap data for street geometry |
| `AuthService` | Singleton handling Firebase auth, caches `teamId` |
| `CloudSyncService` | Syncs segments to team Firestore collection |
| `TeamService` | Team CRUD, invite codes, member stats |
| `TrackingNotificationService` | Live notification showing walk progress |
| `ConnectivityService` | Monitors WiFi/mobile data for sync decisions |

### Key Constants (in GameProvider)
- `_minDistanceForNewPoint`: 15m - minimum movement to record walk path
- `_streetFetchRadiusKm`: 2km - OSM data fetch radius
- `_revealRadius`: 15m - fog of war reveal distance from player
- `_osmRefetchDistanceKm`: 1km - distance before refreshing OSM data

### UI Structure (`lib/ui/`)
- `screens/`: Full-page views (MapScreen, StatsScreen, AccountScreen)
- `widgets/`: Reusable components (ResourceBar, PlayerStatsPanel, MapControls)
- Theme defined in `lib/core/theme/app_theme.dart` with `WantrTheme` class

## Important Patterns

### Adding Hive-Persisted Fields
1. Add field with next available `@HiveField(n)` index
2. Run `dart run build_runner build --delete-conflicting-outputs`
3. Test that existing data migrates correctly (Hive uses nullable defaults for new fields)

### Street Discovery Flow
1. `LocationService` emits location updates
2. `GameProvider._handleLocationUpdate()` processes movement
3. `_checkStreetDiscovery()` compares player position to cached OSM street segments
4. New segments are saved to Hive and queued for cloud sync via `_syncSegmentToCloud()`

### Cloud Sync Optimization
- Segment syncs are buffered for 5 seconds before batch upload
- Distance updates buffer 100m or 60 seconds before syncing
- WiFi-only sync setting checks connectivity before each sync attempt
- Batch uploads use 500-doc batches (Firestore limit)

### Firestore Data Structure
```
teams/{teamId}/
  - stats: { totalSegments, totalDistance }
  - revealedSegments/{segmentId}:
      streetId, streetName, startLat, startLng, endLat, endLng,
      discoveredBy (userId), firstDiscoveredAt, timesWalked,
      lastWalkedAt, lastWalkedBy
users/{userId}/
  - teamId, displayName, email
```

### GPS Mode Settings
Stored in `AppSettings.gpsModeIndex`:
| Mode | distanceFilter | interval | batterySaverMode |
|------|---------------|----------|------------------|
| 0 - Battery Saver | 10m | 5s | true |
| 1 - Balanced | 5m | 3s | false |
| 2 - High Accuracy | 3m | 2s | false |
