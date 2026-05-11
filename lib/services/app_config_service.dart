import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Global App Config Service
///
/// Listens to Firebase Firestore (app_config/global_settings)
/// to dynamically control app features, URLs, and maintenance mode.
/// Contains hardcoded fallback defaults if offline.
/// ──────────────────────────────────────────────────────────────

class AppConfigService extends ChangeNotifier {
  // AI FIX: Changed to a getter so it doesn't call Firebase before initialization
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _configSub;

  // ─── Current App Version ───
  String _currentAppVersion = '1.0.0';
  String get currentAppVersion => _currentAppVersion;

  // ─── App Management ───
  bool _isMaintenanceMode = false;
  String _maintenanceMessage = 'We are currently under maintenance. Please check back later.';
  String _forceUpdateVersion = '1.0.0';
  String _updateUrl = 'https://noteflow.app';
  String _betaBadgeText = 'BETA';

  bool get isMaintenanceMode => _isMaintenanceMode;
  String get maintenanceMessage => _maintenanceMessage;
  String get forceUpdateVersion => _forceUpdateVersion;
  String get updateUrl => _updateUrl;
  String get betaBadgeText => _betaBadgeText;

  // ─── Contact & Social ───
  String _supportEmail = 'support@noteflow.app';
  String _whatsappNumber = '1234567890';
  String _facebookGroupUrl = 'https://facebook.com/groups/noteflow';
  String _youtubeUrl = 'https://youtube.com/@noteflow';

  String get supportEmail => _supportEmail;
  String get whatsappNumber => _whatsappNumber;
  String get facebookGroupUrl => _facebookGroupUrl;
  String get youtubeUrl => _youtubeUrl;

  // ─── AI Settings ───
  String _activeAiModel = 'gemini-3.1-flash';
  String _qwenAiModel = 'qwen-turbo';
  int _dailyLimit = 50;

  String get activeAiModel => _activeAiModel;
  String get qwenAiModel => _qwenAiModel;
  int get dailyLimit => _dailyLimit;

  // ─── Legal ───
  String _privacyPolicyUrl = 'https://noteflow.app/privacy';
  String _termsUrl = 'https://noteflow.app/terms';

  String get privacyPolicyUrl => _privacyPolicyUrl;
  String get termsUrl => _termsUrl;

  // ─── Ads ───
  bool _showAds = false;
  String _admobBannerId = 'ca-app-pub-3940256099942544/6300978111';
  String _admobInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

  bool get showAds => _showAds;
  String get admobBannerId => _admobBannerId;
  String get admobInterstitialId => _admobInterstitialId;

  // ─── Computed Properties ───
  bool get needsForceUpdate {
    return _isVersionGreaterThan(_forceUpdateVersion, _currentAppVersion);
  }

  // ─── Initialization ───

  Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentAppVersion = packageInfo.version;
    } catch (e) {
      if (kDebugMode) debugPrint('Could not fetch app version: $e');
    }
  }

  Future<void> fetchInitialConfig() async {
    try {
      final snapshot = await _firestore.collection('app_config').doc('global_settings').get();
      if (snapshot.exists && snapshot.data() != null) {
        _updateFromData(snapshot.data()!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching initial config: $e');
    }
    _listenToConfig();
  }

  void _updateFromData(Map<String, dynamic> data) {
    // App Management
    _isMaintenanceMode = data['is_maintenance_mode'] as bool? ?? false;
    _maintenanceMessage = data['maintenance_message'] as String? ?? 'We are currently under maintenance. Please check back later.';
    _forceUpdateVersion = data['force_update_version'] as String? ?? '1.0.0';
    _updateUrl = data['update_url'] as String? ?? 'https://noteflow.app';
    _betaBadgeText = data['beta_badge_text'] as String? ?? 'BETA';

    // Contact & Social
    _supportEmail = data['support_email'] as String? ?? 'support@noteflow.app';
    _whatsappNumber = data['whatsapp_number'] as String? ?? '1234567890';
    _facebookGroupUrl = data['facebook_group_url'] as String? ?? 'https://facebook.com/groups/noteflow';
    _youtubeUrl = data['youtube_url'] as String? ?? 'https://youtube.com/@noteflow';

    // AI Settings
    _activeAiModel = data['active_ai_model'] as String? ?? 'gemini-3.1-flash';
    _qwenAiModel = data['qwen_ai_model'] as String? ?? 'qwen-turbo';
    _dailyLimit = data['daily_limit'] as int? ?? 50;

    // Legal
    _privacyPolicyUrl = data['privacy_policy_url'] as String? ?? 'https://noteflow.app/privacy';
    _termsUrl = data['terms_url'] as String? ?? 'https://noteflow.app/terms';

    // Ads
    _showAds = data['show_ads'] as bool? ?? false;
    _admobBannerId = data['admob_banner_id'] as String? ?? 'ca-app-pub-3940256099942544/6300978111';
    _admobInterstitialId = data['admob_interstitial_id'] as String? ?? 'ca-app-pub-3940256099942544/1033173712';

    notifyListeners();
  }

  void _listenToConfig() {
    _configSub = _firestore
        .collection('app_config')
        .doc('global_settings')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _updateFromData(snapshot.data()!);
      }
    }, onError: (error) {
      if (kDebugMode) debugPrint('Error listening to app config: $error');
    });
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }

  // ─── Helpers ───

  /// Returns true if v1 > v2. E.g., '1.0.2' > '1.0.1'.
  bool _isVersionGreaterThan(String v1, String v2) {
    try {
      final v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final p1 = i < v1Parts.length ? v1Parts[i] : 0;
        final p2 = i < v2Parts.length ? v2Parts[i] : 0;
        if (p1 > p2) return true;
        if (p1 < p2) return false;
      }
    } catch (e) {
      // Fallback on error
    }
    return false;
  }
}