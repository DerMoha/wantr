import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/game_provider.dart';
import 'ui/screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  await Hive.initFlutter();
  
  runApp(const WantrApp());
}

class WantrApp extends StatelessWidget {
  const WantrApp({super.key});

  @override
  Widget build(BuildContext context) {
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
    // Give the provider time to initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
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
