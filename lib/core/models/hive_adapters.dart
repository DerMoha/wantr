import 'package:hive/hive.dart';
import 'game_state.dart';
import 'discovered_street.dart';
import 'outpost.dart';
import 'revealed_segment.dart';

/// Register all Hive adapters for the app's data models
/// Must be called before opening any Hive boxes
void registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(GameStateAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DiscoveredStreetAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(OutpostAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(OutpostTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(RevealedSegmentAdapter());
  }
}
