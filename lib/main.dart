import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/game_provider.dart';
import 'ui/screens/map_screen.dart';

String? _initError;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase init error: $e');
    _initError = e.toString();
  }
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: WantrTheme.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  // Initialize Hive
  try {
    await Hive.initFlutter();
    debugPrint('✅ Hive initialized');
  } catch (e) {
    debugPrint('❌ Hive init error: $e');
    _initError = (_initError ?? '') + '\nHive: $e';
  }
  
  runApp(WantrApp(initError: _initError));
}

class WantrApp extends StatelessWidget {
  final String? initError;
  
  const WantrApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    // If there was an init error, show it
    if (initError != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: WantrTheme.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    initError!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return ChangeNotifierProvider(
      create: (_) => GameProvider()..initialize(),
      child: MaterialApp(
        title: 'Wantr',
        debugShowCheckedModeBanner: false,
        theme: WantrTheme.darkTheme,
        home: const WantrHome(),
      ),
    );
  }
}

/// Home screen with loading state handling
class WantrHome extends StatefulWidget {
  const WantrHome({super.key});

  @override
  State<WantrHome> createState() => _WantrHomeState();
}

class _WantrHomeState extends State<WantrHome> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    final gameProvider = context.read<GameProvider>();
    
    // Check if already initialized
    if (gameProvider.isInitialized) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Wait for provider to initialize
    // We also keep the 500ms minimum for splash feeling
    await Future.wait([
      gameProvider.initialize(),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: WantrTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/title
              Text(
                'Wantr',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: WantrTheme.discovered,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The Wandering Trader',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: WantrTheme.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    WantrTheme.discovered,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const MapScreen();
  }
}
