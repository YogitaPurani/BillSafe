import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show themeModeNotifier;
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _autoSave = false;

  Future<void> _toggleDarkMode(bool value) async {
    final mode = value ? ThemeMode.dark : ThemeMode.light;
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'theme_mode', value ? 'dark' : 'light');
    setState(() {}); // refresh switch state
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, themeMode, _) {
          final isDark = themeMode == ThemeMode.dark;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader('Appearance'),
              _SettingsTile(
                icon: isDark ? Icons.dark_mode : Icons.light_mode,
                title: 'Dark Mode',
                subtitle: isDark
                    ? 'Dark theme is on'
                    : 'Light theme is on',
                trailing: Switch(
                  value: isDark,
                  onChanged: _toggleDarkMode,
                  thumbIcon: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Icon(Icons.dark_mode,
                          size: 16, color: Colors.white);
                    }
                    return const Icon(Icons.light_mode,
                        size: 16, color: Colors.amber);
                  }),
                ),
              ),
              const SizedBox(height: 16),
              _SectionHeader('Scan Settings'),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                subtitle: 'Get alerts for overcharged bills',
                trailing: Switch(
                  value: _notifications,
                  onChanged: (v) => setState(() => _notifications = v),
                ),
              ),
              _SettingsTile(
                icon: Icons.save_outlined,
                title: 'Auto-Save Scans',
                subtitle: 'Automatically save results to history',
                trailing: Switch(
                  value: _autoSave,
                  onChanged: (v) => setState(() => _autoSave = v),
                ),
              ),
              const SizedBox(height: 16),
              _SectionHeader('Data'),
              _SettingsTile(
                icon: Icons.delete_outline,
                title: 'Clear History',
                subtitle: 'Delete all saved scans',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _confirmClear(context),
                textColor: cs.error,
              ),
              const SizedBox(height: 24),
              _SectionHeader('About'),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Bill Safe',
                subtitle: 'Version 1.0.0 · AI-powered bill verification',
                trailing: null,
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Made with Flutter & Gemini AI',
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content:
            const Text('All saved scans will be deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.clearAll();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('History cleared')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon,
            color: textColor ?? cs.onSurfaceVariant),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: trailing,
      ),
    );
  }
}
