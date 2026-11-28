
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_state.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
final AppState appState;

const SettingsScreen({
super.key,
required this.appState,
});

// PRIVACY POLICY URL
static const String privacyPolicyUrl =
'https://nbano6413-create.github.io/my-docverter-privacy-policy/';

static const String termsUrl = '';
static const String supportEmail = 'support@mydocverter.app';

@override
Widget build(BuildContext context) {
final isDark =
Theme.of(context).brightness == Brightness.dark;

return Scaffold(
backgroundColor:
isDark ? AppTheme.darkBg : AppTheme.lightBg,
appBar: AppBar(
backgroundColor: AppTheme.primaryPurple,
elevation: 0,
leading: IconButton(
icon: const Icon(
Icons.arrow_back_rounded,
color: Colors.white,
),
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
_buildSectionHeader('App Settings', isDark),
const SizedBox(height: 12),
Material(
color: isDark
? AppTheme.darkSurface
    : Colors.white,
borderRadius: BorderRadius.circular(20),
elevation: 1,
shadowColor: Colors.black12,
child: Column(
children: [
ListTile(
contentPadding:
const EdgeInsets.symmetric(
horizontal: 20,
vertical: 6,
),
leading: _buildIcon(
Icons.dark_mode_outlined,
),
title: const Text(
'Dark Mode',
style: TextStyle(
fontWeight: FontWeight.w600,
fontSize: 16,
),
),
trailing: Switch(
value: appState.isDarkMode,
activeThumbColor:
AppTheme.primaryPurple,
onChanged: appState.toggleTheme,
),
),
const Divider(
height: 1,
indent: 20,
endIndent: 20,
),
ListTile(
contentPadding:
const EdgeInsets.symmetric(
horizontal: 20,
vertical: 6,
),
leading: _buildIcon(
Icons.language_rounded,
),
title: const Text(
'Language',
style: TextStyle(
fontWeight: FontWeight.w600,
fontSize: 16,
),
),
subtitle: Text(
appState.selectedLanguage,
style: const TextStyle(
color: Colors.grey,
fontSize: 14,
),
),
trailing: const Icon(
Icons.arrow_right_rounded,
color: Colors.grey,
size: 28,
),
onTap: () =>
_showLanguageDialog(context),
),
const Divider(
height: 1,
indent: 20,
endIndent: 20,
),
ListTile(
contentPadding:
const EdgeInsets.symmetric(
horizontal: 20,
vertical: 6,
),
leading: _buildIcon(
Icons.notifications_active_outlined,
),
title: const Text(
'Notifications',
style: TextStyle(
fontWeight: FontWeight.w600,
fontSize: 16,
),
),
trailing: Switch(
value: appState.notificationsEnabled,
activeThumbColor:
AppTheme.primaryPurple,
onChanged:
appState.toggleNotifications,
),
),
],
),
),
const SizedBox(height: 30),
_buildSectionHeader('Support & About', isDark),
const SizedBox(height: 12),
Material(
color: isDark
? AppTheme.darkSurface
    : Colors.white,
borderRadius: BorderRadius.circular(20),
elevation: 1,
shadowColor: Colors.black12,
child: Column(
children: [
_buildOptionItem(
icon: Icons.share_outlined,
title: 'Share App',
onTap: () => _shareApp(context),
),
const Divider(
height: 1,
indent: 20,
endIndent: 20,
),
_buildOptionItem(
icon: Icons.card_giftcard_rounded,
title: 'Support App (Watch Optional Ad)',
onTap: () =>
_showSupportAdDialog(context),
),
const Divider(
height: 1,
indent: 20,
endIndent: 20,
),
_buildOptionItem(
icon: Icons.mail_outline_rounded,
title: 'Contact Us',
onTap: () => _contactUs(context),
),
const Divider(
height: 1,
indent: 20,
endIndent: 20,
),
_buildOptionItem(
icon: Icons.lock_outline_rounded,
title: 'Privacy Policy',
onTap: () =>
_openPrivacyPolicy(context),
),
const Divider(
height: 1,
indent: 20,
endIndent: 20,
),
_buildOptionItem(
icon: Icons.article_outlined,
title: 'Terms & Conditions',
onTap: () => _openTerms(context),
),
const Divider(
height: 1,
indent: 20,
endIndent: 20,
),
_buildOptionItem(
icon: Icons.info_outline_rounded,
title: 'About My Docverter: PDF Converter',
onTap: () =>
_showAboutDialog(context),
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

// ICON
Widget _buildIcon(IconData icon) {
return Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: AppTheme.primaryPurple.withValues(alpha: 0.1),
borderRadius: BorderRadius.circular(12),
),
child: Icon(
icon,
color: AppTheme.primaryPurple,
),
);
}

// SECTION HEADER
Widget _buildSectionHeader(
String title,
bool isDark,
) {
return Text(
title,
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
color: AppTheme.primaryPurple,
),
);
}

// OPTION ITEM
Widget _buildOptionItem({
required IconData icon,
required String title,
required VoidCallback onTap,
}) {
return ListTile(
contentPadding: const EdgeInsets.symmetric(
horizontal: 20,
vertical: 6,
),
leading: _buildIcon(icon),
title: Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w600,
fontSize: 16,
),
),
onTap: onTap,
);
}

// SHARE APP
Future<void> _shareApp(BuildContext context) async {
try {
await SharePlus.instance.share(
ShareParams(
text: 'Try My Docverter: PDF Converter!\n'
'Convert, merge, split, organize and manage PDF files easily.',
subject: 'My Docverter: PDF Converter',
),
);
} catch (e) {
if (!context.mounted) return;

_showSnackBar(
context,
'Unable to share the app right now.',
);
}
}

// CONTACT US
Future<void> _contactUs(BuildContext context) async {
final emailUri = Uri(
scheme: 'mailto',
path: supportEmail,
query: 'subject=My Docverter Support',
);

try {
final opened = await launchUrl(emailUri);

if (!context.mounted) return;

if (!opened) {
_showInfoDialog(
context,
'Contact Us',
'Unable to open your email application.\n\n'
'You can contact us at:\n$supportEmail',
);
}
} catch (e) {
if (!context.mounted) return;

_showInfoDialog(
context,
'Contact Us',
'Please email us at:\n\n$supportEmail',
);
}
}

// PRIVACY POLICY
Future<void> _openPrivacyPolicy(
BuildContext context,
) async {
final uri = Uri.parse(privacyPolicyUrl);

try {
final opened = await launchUrl(
uri,
mode: LaunchMode.externalApplication,
);

if (!context.mounted) return;

if (!opened) {
_showSnackBar(
context,
'Unable to open Privacy Policy. Please try again.',
);
}
} catch (e) {
if (!context.mounted) return;

_showSnackBar(
context,
'Unable to open Privacy Policy. Please check your internet connection.',
);
}
}

// TERMS AND CONDITIONS
Future<void> _openTerms(BuildContext context) async {
if (termsUrl.isNotEmpty) {
final uri = Uri.parse(termsUrl);

try {
final opened = await launchUrl(
uri,
mode: LaunchMode.externalApplication,
);

if (!context.mounted) return;
if (opened) return;
} catch (_) {
if (!context.mounted) return;
}
}

if (!context.mounted) return;

_showInfoDialog(
context,
'Terms & Conditions',
'MY DOCVERTER: PDF CONVERTER - TERMS & CONDITIONS\n\n'
'1. ACCEPTABLE USE\n'
'You agree to use My Docverter for lawful document '
'management, conversion and editing purposes.\n\n'
'2. YOUR FILES\n'
'You are responsible for the documents you select, '
'their contents and your rights to use them.\n\n'
'3. CONVERSION RESULTS\n'
'Converted files may not always preserve the exact '
'formatting, layout or content of the original file. '
'Please check your converted documents before use.\n\n'
'4. AVAILABILITY\n'
'Features may be updated, changed or unavailable '
'depending on device compatibility and technical '
'limitations.\n\n'
'5. RESPONSIBILITY\n'
'You are responsible for keeping copies of important '
'documents and reviewing your output files.\n\n'
'6. THIRD-PARTY SERVICES\n'
'The app may contain third-party advertising or '
'services governed by their own terms.\n\n'
'7. UPDATES\n'
'These terms may be revised as the app changes.\n\n'
'For questions, contact:\n$supportEmail',
);
}

// SUPPORT AD
void _showSupportAdDialog(BuildContext context) {
showDialog(
context: context,
builder: (ctx) => AlertDialog(
title: const Text('Support App'),
content: const Text(
'You can optionally watch a short video ad to '
'support free development of My Docverter. '
'Would you like to watch an ad?',
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
_showSnackBar(
context,
'Thank you for supporting My Docverter!',
);
}
},
onAdDismissed: () {},
);
},
child: const Text('Watch Ad'),
),
],
),
);
}

// SNACKBAR
void _showSnackBar(
BuildContext context,
String message,
) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(message),
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
backgroundColor: AppTheme.primaryPurple,
),
);
}

// LANGUAGE
void _showLanguageDialog(BuildContext context) {
showDialog(
context: context,
builder: (ctx) => AlertDialog(
title: const Text('Select Language'),
content: Column(
mainAxisSize: MainAxisSize.min,
children: [
'English',
'Spanish',
'French',
'German',
'Urdu',
'Arabic',
].map((lang) {
return ListTile(
title: Text(lang),
trailing: lang == appState.selectedLanguage
? const Icon(
Icons.check_circle_rounded,
color: AppTheme.primaryPurple,
)
    : null,
onTap: () {
appState.setLanguage(lang);
Navigator.pop(ctx);
},
);
}).toList(),
),
),
);
}

// INFORMATION DIALOG
void _showInfoDialog(
BuildContext context,
String title,
String content,
) {
showDialog(
context: context,
builder: (ctx) => AlertDialog(
title: Text(title),
content: SingleChildScrollView(
child: Text(content),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('Close'),
),
],
),
);
}

// ABOUT
void _showAboutDialog(BuildContext context) {
showDialog(
context: context,
builder: (ctx) => AlertDialog(
title: const Text(
'My Docverter: PDF Converter',
),
content: const Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Version: 1.0.0'),
SizedBox(height: 10),
Text('Fast • Secure • Smart PDF Tools'),
SizedBox(height: 10),
Text(
'Convert, edit, split, merge, and secure '
'your PDF files.',
),
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
