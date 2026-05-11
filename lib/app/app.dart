import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'theme_controller.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/app_lock_screen.dart';
import '../features/notes/controllers/notes_controller.dart';
import '../features/notes/screens/notes_list_screen.dart';
import '../features/notes/screens/note_editor_screen.dart';
import '../features/notes/screens/note_detail_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../services/ai_service.dart';
import '../services/api_key_service.dart';
import '../services/app_lock_service.dart';
import '../services/firebase_service.dart';
import '../services/folder_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';
import '../services/app_config_service.dart';
import '../services/ad_service.dart';
import '../shared/constants/app_strings.dart';
import '../shared/widgets/logo_widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Root Application Widget
///
/// Sets up the Provider tree with:
///  • HiveService + FirebaseService (singletons)
///  • SyncService (offline-first orchestrator)
///  • FolderService (local folder storage)
///  • ThemeController (dark mode persistence)
///  • AuthController + NotesController
///
/// Uses a StreamBuilder on FirebaseAuth to reactively show
/// LoginScreen or NotesListScreen.
///
/// Phase 17: App lock gate + theme controller integration.
/// ──────────────────────────────────────────────────────────────

class NoteFlowApp extends StatefulWidget {
  final bool firebaseReady;
  final AppConfigService? appConfigService;

  const NoteFlowApp({
    super.key, 
    this.firebaseReady = false,
    this.appConfigService,
  });

  @override
  State<NoteFlowApp> createState() => _NoteFlowAppState();
}

class _NoteFlowAppState extends State<NoteFlowApp> {
  late final HiveService _hiveService;
  late final FirebaseService _firebaseService;
  late final SyncService _syncService;
  late final FolderService _folderService;
  late final ApiKeyService _apiKeyService;
  late final AppConfigService _appConfigService;
  late final AdService _adService;
  late final AiService _aiService;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _hiveService = HiveService();
    _firebaseService = FirebaseService();
    _syncService = SyncService(
      hiveService: _hiveService,
      firebaseService: _firebaseService,
    );
    _folderService = FolderService();
    _apiKeyService = ApiKeyService();
    _appConfigService = widget.appConfigService ?? (AppConfigService()..init());
    _adService = AdService(_appConfigService);
    _aiService = AiService(_apiKeyService, _appConfigService);
    _themeController = ThemeController();

    // Open Hive boxes
    _hiveService.init();
    _folderService.init();
    _themeController.init();
  }

  @override
  void dispose() {
    _syncService.dispose();
    _themeController.dispose();
    _adService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider.value(value: _syncService),
        ChangeNotifierProvider.value(value: _themeController),
        ChangeNotifierProvider.value(value: _appConfigService),
        Provider.value(value: _adService),
        ChangeNotifierProvider(
          create: (_) => NotesController(
            syncService: _syncService,
            aiService: _aiService,
            folderService: _folderService,
          ),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeCtrl, _) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,

            // Lumina Focus themes
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeCtrl.themeMode,

            // Home determined by auth state + app lock
            home: widget.firebaseReady
                ? const _AppLockGate()
                : const _FirebaseNotReady(),

            builder: (context, child) => _AppGuardGate(child: child!),

            // Named routes
            onGenerateRoute: _generateRoute,
          );
        },
      ),
    );
  }

  /// Route generator for named navigation with smooth transitions.
  static Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/editor':
        final noteId = settings.arguments as String?;
        return _slideUp(NoteEditorScreen(noteId: noteId), settings);
      case '/detail':
        final noteId = settings.arguments as String;
        return _slideLeft(NoteDetailScreen(noteId: noteId), settings);
      case '/login':
        return _fade(const LoginScreen(), settings);
      case '/settings':
        return _slideLeft(const SettingsScreen(), settings);
      default:
        return _fade(const NotesListScreen(), settings);
    }
  }

  /// Smooth fade transition (for auth / home).
  static PageRouteBuilder _fade(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  /// Slide-in from right (detail / settings).
  static PageRouteBuilder _slideLeft(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Slide-in from bottom (editor).
  static PageRouteBuilder _slideUp(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.15),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// App Lock Gate — checks if app lock is enabled and shows
/// the lock screen before the auth gate.
/// ──────────────────────────────────────────────────────────────

class _AppLockGate extends StatefulWidget {
  const _AppLockGate();

  @override
  State<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<_AppLockGate>
    with WidgetsBindingObserver {
  final AppLockService _lockService = AppLockService();
  bool _isLocked = false;
  bool _isCheckingLock = true;

  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lock initially on fresh launch (if enabled)
    _checkLock(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        if (elapsed.inSeconds >= 10) {
          _checkLock(force: true);
        }
        _pausedAt = null;
      }
    }
  }

  Future<void> _checkLock({bool force = false}) async {
    if (!force) return;
    final enabled = await _lockService.isLockEnabled();
    final hasPin = await _lockService.hasPin();

    if (mounted) {
      setState(() {
        _isLocked = enabled && hasPin;
        _isCheckingLock = false;
      });
    }
  }

  void _unlock() {
    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLock) return const _SplashScreen();
    if (_isLocked) return AppLockScreen(onUnlocked: _unlock);
    return const _AuthGate();
  }
}

/// ──────────────────────────────────────────────────────────────
/// Auth Gate — StreamBuilder that swaps screens based on auth
/// ──────────────────────────────────────────────────────────────

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still checking auth — show splash
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // User signed in → start sync and show notes
        if (snapshot.hasData && snapshot.data != null) {
          // Kick off initial sync with this user's ID
          final sync = context.read<SyncService>();
          sync.setUser(snapshot.data!.uid);

          return const NotesListScreen();
        }

        // Not signed in
        final sync = context.read<SyncService>();
        sync.clearUser();
        return const LoginScreen();
      },
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Branded Splash Screen — animated logo + app name
/// ──────────────────────────────────────────────────────────────

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Logo: scale up + fade in (first 60%)
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Text: slide up + fade in (40%–100%)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Animated Logo ──
                Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: const LogoWidget(iconSize: 56, fontSize: 48),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Animated Text ──
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        Text(
                          AppStrings.appTagline,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Loading indicator ──
                FadeTransition(
                  opacity: _textOpacity,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cs.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fallback when Firebase isn't configured.
class _FirebaseNotReady extends StatelessWidget {
  const _FirebaseNotReady();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 40,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  AppStrings.appName,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your notes. Smarter.',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 28,
                        color: cs.onSecondaryContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Firebase is not configured yet.\n'
                        'You can still use the app in offline mode.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.6,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotesListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(
                      'Continue Offline',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// App Guard Gate — Enforces Maintenance and Update modes
/// ──────────────────────────────────────────────────────────────

class _AppGuardGate extends StatelessWidget {
  final Widget child;
  const _AppGuardGate({required this.child});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigService>();

    if (config.isMaintenanceMode) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build_circle_outlined, size: 64, color: Colors.amber),
                const SizedBox(height: 24),
                Text(
                  'Maintenance Break',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(
                  config.maintenanceMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (config.needsForceUpdate) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update_alt_rounded, size: 64, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  'Update Required',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(
                  'A new version of NoteFlow is available. Please update to continue using the app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () async {
                    final uri = Uri.parse(config.updateUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('Update Now'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }
}
