import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme_controller.dart';
import '../../../services/api_key_service.dart';
import '../../../services/app_lock_service.dart';
import '../../../services/app_config_service.dart';
import '../../../shared/constants/app_colors.dart';
import 'about_screen.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Settings Screen (Dual Provider)
///
/// Manages two AI provider API keys and lets the user choose
/// which provider to use:
///  • Google Gemini  (gemini-1.5-flash)
///  • Alibaba Qwen   (qwen-turbo via DashScope)
///
/// Features:
///  • Two secure key fields with visibility toggles
///  • Active provider selector (radio buttons)
///  • Test Connection for the active provider
///  • Masked display after saving
///  • Delete key per provider
/// ──────────────────────────────────────────────────────────────

// AI NOTE: UI for the Settings screen where users manage AI API keys, app lock, and theme.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiKeyService _keyService = ApiKeyService();
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _qwenController = TextEditingController();

  bool _isLoading = true;
  AiProvider _activeProvider = AiProvider.gemini;

  // Gemini state
  bool _hasGeminiKey = false;
  String? _maskedGemini;
  bool _obscureGemini = true;
  bool _isSavingGemini = false;

  // Qwen state
  bool _hasQwenKey = false;
  String? _maskedQwen;
  bool _obscureQwen = true;
  bool _isSavingQwen = false;

  // Test connection
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _qwenController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final active = await _keyService.getActiveProvider();
    final maskedGemini = await _keyService.getMaskedGeminiKey();
    final maskedQwen = await _keyService.getMaskedQwenKey();

    setState(() {
      _activeProvider = active;
      _maskedGemini = maskedGemini;
      _hasGeminiKey = maskedGemini != null;
      _maskedQwen = maskedQwen;
      _hasQwenKey = maskedQwen != null;
      _isLoading = false;
    });
  }

  // ─── Save ───

  Future<void> _saveGeminiKey() async {
    final key = _geminiController.text.trim();
    if (key.isEmpty) {
      _snack('Please enter a Gemini API key.', isError: true);
      return;
    }
    setState(() => _isSavingGemini = true);
    await _keyService.saveGeminiKey(key);
    final masked = await _keyService.getMaskedGeminiKey();
    setState(() {
      _isSavingGemini = false;
      _hasGeminiKey = true;
      _maskedGemini = masked;
      _geminiController.clear();
    });
    _snack('Gemini API key saved securely.');
  }

  Future<void> _saveQwenKey() async {
    final key = _qwenController.text.trim();
    if (key.isEmpty) {
      _snack('Please enter a Qwen API key.', isError: true);
      return;
    }
    setState(() => _isSavingQwen = true);
    await _keyService.saveQwenKey(key);
    final masked = await _keyService.getMaskedQwenKey();
    setState(() {
      _isSavingQwen = false;
      _hasQwenKey = true;
      _maskedQwen = masked;
      _qwenController.clear();
    });
    _snack('Qwen API key saved securely.');
  }

  // ─── Delete ───

  Future<void> _deleteGeminiKey() async {
    final ok = await _confirmDelete('Gemini');
    if (ok) {
      await _keyService.deleteGeminiKey();
      setState(() {
        _hasGeminiKey = false;
        _maskedGemini = null;
      });
      _snack('Gemini API key deleted.');
    }
  }

  Future<void> _deleteQwenKey() async {
    final ok = await _confirmDelete('Qwen');
    if (ok) {
      await _keyService.deleteQwenKey();
      setState(() {
        _hasQwenKey = false;
        _maskedQwen = null;
      });
      _snack('Qwen API key deleted.');
    }
  }

  Future<bool> _confirmDelete(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete $name Key',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Remove your saved $name API key? AI features using $name will '
          'stop working until a new key is added.',
          style: GoogleFonts.poppins(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Test ───

  Future<void> _testActiveProvider() async {
    final appConfig = context.read<AppConfigService>();
    final modelToTest = _activeProvider == AiProvider.gemini 
        ? appConfig.activeAiModel 
        : appConfig.qwenAiModel;
    
    String? key;
    if (_activeProvider == AiProvider.gemini) {
      key = _geminiController.text.trim().isNotEmpty
          ? _geminiController.text.trim()
          : await _keyService.getGeminiKey();
    } else {
      key = _qwenController.text.trim().isNotEmpty
          ? _qwenController.text.trim()
          : await _keyService.getQwenKey();
    }

    if (key == null || key.isEmpty) {
      _snack('No API key for the active provider.', isError: true);
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final result = await _keyService.testConnection(_activeProvider, key, modelToTest);

    setState(() {
      _isTesting = false;
      _testSuccess = result == 'success';
      _testResult = _testSuccess
          ? 'Connection successful! '
                '${_activeProvider == AiProvider.gemini ? "Gemini" : "Qwen"} '
                'API key is valid.'
          : result;
    });
  }

  // ─── Provider Change ───

  Future<void> _setProvider(AiProvider provider) async {
    setState(() {
      _activeProvider = provider;
      _testResult = null;
    });
    await _keyService.setActiveProvider(provider);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 14)),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final config = context.watch<AppConfigService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Appearance (Dark Mode) ───
                  _buildSectionIcon(Icons.palette_outlined, 'Appearance'),
                  const SizedBox(height: 12),
                  _ThemeModeSelector(),

                  const SizedBox(height: 32),

                  // ─── Security (App Lock) ───
                  _buildSectionIcon(Icons.lock_outline_rounded, 'Security'),
                  const SizedBox(height: 12),
                  const _AppLockSection(),

                  const SizedBox(height: 32),

                  // ─── Active Provider Selector ───
                  _buildSectionIcon(
                    Icons.smart_toy_outlined,
                    'Active AI Provider',
                  ),
                  const SizedBox(height: 12),
                  _ProviderSelector(
                    active: _activeProvider,
                    onChanged: _setProvider,
                  ),

                  const SizedBox(height: 32),

                  // ─── API Key Sections (animated transition) ───
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1.0,
                          child: child,
                        ),
                      );
                    },
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: config.useGlobalApiKeys
                        ? Container(
                            key: const ValueKey('premium_banner'),
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: cs.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '✨ Premium AI Unlocked',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: cs.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'AI features are powered by the developer. No API key required!',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            key: const ValueKey('manual_keys'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ─── Gemini Key Section ───
                              _buildSectionIcon(
                                Icons.auto_awesome_rounded,
                                'Google Gemini API Key',
                              ),
                              const SizedBox(height: 12),
                              _KeySection(
                                hasKey: _hasGeminiKey,
                                maskedKey: _maskedGemini,
                                controller: _geminiController,
                                obscure: _obscureGemini,
                                isSaving: _isSavingGemini,
                                hintText: 'AIzaSy...',
                                onToggleObscure: () =>
                                    setState(() => _obscureGemini = !_obscureGemini),
                                onSave: _saveGeminiKey,
                                onDelete: _deleteGeminiKey,
                              ),

                              const SizedBox(height: 28),

                              // ─── Qwen Key Section ───
                              _buildSectionIcon(
                                Icons.cloud_outlined,
                                'Alibaba Qwen API Key',
                              ),
                              const SizedBox(height: 12),
                              _KeySection(
                                hasKey: _hasQwenKey,
                                maskedKey: _maskedQwen,
                                controller: _qwenController,
                                obscure: _obscureQwen,
                                isSaving: _isSavingQwen,
                                hintText: 'sk-...',
                                onToggleObscure: () =>
                                    setState(() => _obscureQwen = !_obscureQwen),
                                onSave: _saveQwenKey,
                                onDelete: _deleteQwenKey,
                              ),

                              const SizedBox(height: 28),

                              // ─── Test Connection ───
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _isTesting ? null : _testActiveProvider,
                                  icon: _isTesting
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: cs.primary,
                                          ),
                                        )
                                      : Icon(
                                          Icons.wifi_tethering_rounded,
                                          size: 20,
                                          color: cs.primary,
                                        ),
                                  label: Text(
                                    _isTesting
                                        ? 'Testing…'
                                        : 'Test ${_activeProvider == AiProvider.gemini ? "Gemini" : "Qwen"} Connection',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              // Test result
                              if (_testResult != null) ...[
                                const SizedBox(height: 14),
                                _ResultCard(message: _testResult!, isSuccess: _testSuccess),
                              ],
                            ],
                          ),
                  ),

                  const SizedBox(height: 32),

                  // ─── Info Card ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'About your API keys',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '• Keys are encrypted and stored locally on this device.\n'
                          '• They are never sent to NoteFlow servers.\n'
                          '• Gemini key: Get at ai.google.dev\n'
                          '• Qwen key: Get at dashscope.console.aliyun.com\n'
                          '• You can switch providers anytime.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.7,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ─── Feedback & Contact ───
                  _buildSectionIcon(Icons.feedback_outlined, 'Feedback & Contact'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _LegalTile(
                          icon: Icons.email_outlined,
                          title: 'Email Developer',
                          onTap: () => _openUrl('mailto:${config.supportEmail}?subject=NoteFlow%20Feedback'),
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                        _LegalTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'WhatsApp Developer',
                          onTap: () => _openUrl('https://wa.me/${config.whatsappNumber}'),
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                        _LegalTile(
                          icon: Icons.groups_outlined,
                          title: 'Facebook Group',
                          onTap: () => _openUrl(config.facebookGroupUrl),
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                        _LegalTile(
                          icon: Icons.video_library_outlined,
                          title: 'YouTube Channel',
                          onTap: () => _openUrl(config.youtubeUrl),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ─── Legal Section ───
                  _buildSectionIcon(Icons.gavel_rounded, 'Legal'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Privacy Policy
                        _LegalTile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: () => _openUrl(config.privacyPolicyUrl),
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                        // Terms of Service
                        _LegalTile(
                          icon: Icons.description_outlined,
                          title: 'Terms of Service',
                          onTap: () => _openUrl(config.termsUrl),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ─── Support & About ───
                  _buildSectionIcon(
                    Icons.info_outline_rounded,
                    'Support & About',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _LegalTile(
                      icon: Icons.contact_support_outlined,
                      title: 'About NoteFlow',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionIcon(IconData icon, String title) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandIndigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.brandIndigo),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  /// Opens a URL in the system browser.
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        _snack('Could not open link.', isError: true);
      }
    }
  }
}

/// ──────────────────────────────────────────────────────────────
/// Legal Tile — single row for privacy / terms links
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A reusable list tile widget for displaying legal links (Privacy, Terms).
class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LegalTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Provider Selector (Radio)
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A reusable widget for selecting the active AI provider (Gemini or Qwen).
class _ProviderSelector extends StatelessWidget {
  final AiProvider active;
  final ValueChanged<AiProvider> onChanged;

  const _ProviderSelector({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _tile(
            context,
            AiProvider.gemini,
            Icons.auto_awesome_rounded,
            'Google Gemini',
            context.watch<AppConfigService>().activeAiModel,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          _tile(
            context,
            AiProvider.qwen,
            Icons.cloud_outlined,
            'Alibaba Qwen',
            '${context.watch<AppConfigService>().qwenAiModel} (DashScope)',
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    AiProvider value,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = active == value;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: cs.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Simple radio circle
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Key Section — reusable for each provider
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A reusable section widget for inputting, saving, and deleting API keys.
class _KeySection extends StatelessWidget {
  final bool hasKey;
  final String? maskedKey;
  final TextEditingController controller;
  final bool obscure;
  final bool isSaving;
  final String hintText;
  final VoidCallback onToggleObscure;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _KeySection({
    required this.hasKey,
    required this.maskedKey,
    required this.controller,
    required this.obscure,
    required this.isSaving,
    required this.hintText,
    required this.onToggleObscure,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing key badge
        if (hasKey) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    maskedKey ?? '••••••••',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: cs.error,
                  ),
                  tooltip: 'Delete key',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Input field
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: Icon(
              Icons.vpn_key_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              onPressed: onToggleObscure,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Save button
        SizedBox(
          width: double.infinity,
          height: 42,
          child: FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              isSaving ? 'Saving…' : 'Save Key',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Result Card
/// ──────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _ResultCard({required this.message, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isSuccess
        ? Colors.green.withValues(alpha: 0.1)
        : cs.errorContainer.withValues(alpha: 0.4);
    final fg = isSuccess ? Colors.green.shade700 : cs.onErrorContainer;
    final icon = isSuccess
        ? Icons.check_circle_outline_rounded
        : Icons.error_outline_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Theme Mode Selector — System / Light / Dark segmented control
/// ──────────────────────────────────────────────────────────────

class _ThemeModeSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeCtrl = context.watch<ThemeController>();
    final current = themeCtrl.themeMode;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _modeChip(
            context,
            'System',
            Icons.settings_brightness_outlined,
            ThemeMode.system,
            current,
          ),
          const SizedBox(width: 6),
          _modeChip(
            context,
            'Light',
            Icons.light_mode_outlined,
            ThemeMode.light,
            current,
          ),
          const SizedBox(width: 6),
          _modeChip(
            context,
            'Dark',
            Icons.dark_mode_outlined,
            ThemeMode.dark,
            current,
          ),
        ],
      ),
    );
  }

  Widget _modeChip(
    BuildContext context,
    String label,
    IconData icon,
    ThemeMode mode,
    ThemeMode current,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isActive = mode == current;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.read<ThemeController>().setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// App Lock Section — toggle + PIN setup
/// ──────────────────────────────────────────────────────────────

class _AppLockSection extends StatefulWidget {
  const _AppLockSection();

  @override
  State<_AppLockSection> createState() => _AppLockSectionState();
}

class _AppLockSectionState extends State<_AppLockSection> {
  final AppLockService _lockService = AppLockService();
  bool _isEnabled = false;
  bool _hasPin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await _lockService.isLockEnabled();
    final hasPin = await _lockService.hasPin();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _hasPin = hasPin;
        _loading = false;
      });
    }
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      final pin = await _showPinDialog('Set a PIN');
      if (pin != null && pin.length == 4) {
        await _lockService.setPin(pin);
        await _lockService.setLockEnabled(true);
        _loadState();
      }
    } else {
      final pin = await _showPinDialog('Enter current PIN');
      if (pin != null) {
        final ok = await _lockService.verifyPin(pin);
        if (ok) {
          await _lockService.setLockEnabled(false);
          _loadState();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Incorrect PIN',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _changePin() async {
    final current = await _showPinDialog('Enter current PIN');
    if (current == null) return;
    final ok = await _lockService.verifyPin(current);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Incorrect PIN',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    final newPin = await _showPinDialog('Set new PIN');
    if (newPin != null && newPin.length == 4) {
      await _lockService.setPin(newPin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PIN changed successfully',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        );
      }
    }
  }

  Future<String?> _showPinDialog(String title) async {
    final tec = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: tec,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 12,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '• • • •',
            hintStyle: GoogleFonts.poppins(
              fontSize: 24,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (tec.text.length == 4) Navigator.pop(ctx, tec.text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              'App Lock',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _isEnabled
                  ? 'PIN or biometric required to open app'
                  : 'Protect your notes with a PIN',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            value: _isEnabled,
            onChanged: _toggleLock,
            secondary: Icon(
              _isEnabled ? Icons.lock_rounded : Icons.lock_open_outlined,
              color: _isEnabled ? cs.primary : cs.onSurfaceVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          if (_isEnabled && _hasPin)
            ListTile(
              leading: Icon(Icons.pin_outlined, color: cs.onSurfaceVariant),
              title: Text(
                'Change PIN',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: _changePin,
            ),
        ],
      ),
    );
  }
}
