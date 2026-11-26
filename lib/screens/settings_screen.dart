import 'package:material_ui/material_ui.dart';
import '../providers/app_state.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  final AppState appState;

  const SettingsScreen({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: App Settings
            _buildSectionHeader('App Settings', isDark),
            const SizedBox(height: 12),
            Material(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 1,
              shadowColor: Colors.black12,
              child: Column(
                children: [
                  // Dark Mode Switch
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.dark_mode_outlined, color: AppTheme.primaryPurple),
                    ),
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    trailing: Switch(
                      value: appState.isDarkMode,
                      activeThumbColor: AppTheme.primaryPurple,
                      onChanged: (value) {
                        appState.toggleTheme(value);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  // Language Selection
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.language_rounded, color: AppTheme.primaryPurple),
                    ),
                    title: const Text(
                      'Language',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Text(
                      appState.selectedLanguage,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.arrow_right_rounded, color: Colors.grey, size: 28),
                    onTap: () {
                      _showLanguageDialog(context);
                    },
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  // Notifications Switch
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryPurple),
                    ),
                    title: const Text(
                      'Notifications',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    trailing: Switch(
                      value: appState.notificationsEnabled,
                      activeThumbColor: AppTheme.primaryPurple,
                      onChanged: (value) {
                        appState.toggleNotifications(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Section 2: Support & About
            _buildSectionHeader('Support & About', isDark),
            const SizedBox(height: 12),
            Material(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 1,
              shadowColor: Colors.black12,
              child: Column(
                children: [
                  _buildOptionItem(
                    icon: Icons.share_outlined,
                    title: 'Share App',
                    onTap: () => _showSnackBar(context, 'Share link copied to clipboard!'),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  _buildOptionItem(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Support App (Watch Optional Ad)',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Support App & Get Perks'),
                          content: const Text(
                            'You can optionally watch a short video ad to support free development of My Docverter. Would you like to watch an ad now?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                AdService.instance.showRewardedAd(
                                  onRewarded: () {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Thank you! Reward unlocked successfully.'),
                                          backgroundColor: AppTheme.primaryPurple,
                                        ),
                                      );
                                    }
                                  },
                                  onAdDismissed: () {
                                    // Ad dismissed or unavailable
                                  },
                                );
                              },
                              child: const Text('Watch Ad'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  _buildOptionItem(
                    icon: Icons.star_outline_rounded,
                    title: 'Rate App',
                    onTap: () => _showSnackBar(context, 'Thank you for rating My Docverter!'),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  _buildOptionItem(
                    icon: Icons.mail_outline_rounded,
                    title: 'Contact Us',
                    onTap: () => _showSnackBar(context, 'Support email: support@mydocverter.app'),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  _buildOptionItem(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy Policy',
                    onTap: () => _showInfoDialog(
                      context,
                      'Privacy Policy',
                      'My Docverter processes your documents locally on your device. We do not store, transfer, or upload your private PDF files to any external server.',
                    ),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  _buildOptionItem(
                    icon: Icons.article_outlined,
                    title: 'Terms & Conditions',
                    onTap: () => _showInfoDialog(
                      context,
                      'Terms & Conditions',
                      'By using My Docverter: PDF Converter, you agree to use the software responsibly for legal document management and conversion purposes.',
                    ),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  _buildOptionItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About My Docverter: PDF Converter',
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryPurple,
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primaryPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.primaryPurple),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      onTap: onTap,
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppTheme.primaryPurple,
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['English', 'Spanish', 'French', 'German', 'Urdu', 'Arabic']
              .map(
                (lang) => ListTile(
                  title: Text(lang),
                  trailing: lang == appState.selectedLanguage
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryPurple)
                      : null,
                  onTap: () {
                    appState.setLanguage(lang);
                    Navigator.pop(ctx);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My Docverter: PDF Converter'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 10),
            Text('Fast • Secure • Smart PDF Tools'),
            SizedBox(height: 10),
            Text('Convert, edit, split, merge, and secure your PDF files with high speed and zero data uploads.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
