import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/app_config_service.dart';
import '../../../shared/widgets/logo_widget.dart';

// AI NOTE: UI displaying app version and developer contact links.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching $urlString: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final config = context.watch<AppConfigService>();

    return Scaffold(
      appBar: AppBar(title: const Text('About NoteFlow'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LogoWidget(iconSize: 64, fontSize: 48),
              const SizedBox(height: 16),
              Text(
                'Version 1.0.0 - Beta',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              _buildContactButton(
                context,
                icon: Icons.chat_rounded,
                label: 'Contact Developer (WhatsApp)',
                onTap: () =>
                    _launchUrl(context, 'https://wa.me/${config.whatsappNumber}'),
              ),
              const SizedBox(height: 16),
              _buildContactButton(
                context,
                icon: Icons.email_rounded,
                label: 'Email Developer (Gmail)',
                onTap: () =>
                    _launchUrl(context, 'mailto:${config.supportEmail}'),
              ),
              const SizedBox(height: 16),
              _buildContactButton(
                context,
                icon: Icons.language_rounded,
                label: 'Visit Website',
                subtitle: 'Coming Soon',
                onTap: () => _launchUrl(context, 'https://www.noteflow.dev'),
              ),
              const SizedBox(height: 48),
              Text(
                '© ${DateTime.now().year} NoteFlow. All rights reserved.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
