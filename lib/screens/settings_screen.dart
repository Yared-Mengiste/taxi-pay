import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/backup_service.dart';
import '../services/permissions_service.dart';

/// Full settings surface: backup, language, theme, live permission status
/// and the privacy note. A screen (not a sheet) because it now holds more
/// than two choices — the permission card alone justifies the room.
///
/// Permission states are re-checked every time the app resumes: the user
/// most likely just flipped them in system Settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.backup,
    required this.languageCode,
    required this.onLanguageChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.permissions,
  });

  final BackupService? backup;
  final String? languageCode;
  final Future<void> Function(String? code) onLanguageChanged;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeModeChanged;
  final PermissionsService? permissions;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  PermissionsService get _permissions =>
      widget.permissions ?? PermissionsService();

  /// null = still checking.
  bool? _smsGranted;
  bool? _batteryExempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    // The platform channel only exists on Android; anything that goes
    // wrong (missing plugin, revoked channel) reads as "not granted".
    bool sms = false;
    bool battery = false;
    try {
      sms = await _permissions.isSmsPermissionGranted;
    } catch (_) {}
    try {
      battery = await _permissions.isIgnoringBatteryOptimizations;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _smsGranted = sms;
      _batteryExempt = battery;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _sectionHeader(context, Icons.language_rounded, l10n.languageTitle),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: RadioGroup<String?>(
              groupValue: widget.languageCode,
              onChanged: widget.onLanguageChanged,
              child: Column(
                children: [
                  for (final (code, label) in [
                    (null, l10n.languageSystem),
                    ('am', l10n.languageAmharic),
                    ('en', l10n.languageEnglish),
                  ])
                    RadioListTile<String?>(
                      value: code,
                      title: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _sectionHeader(context, Icons.palette_rounded, l10n.themeTitle),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: RadioGroup<ThemeMode>(
              groupValue: widget.themeMode,
              onChanged: (mode) {
                if (mode != null) widget.onThemeModeChanged(mode);
              },
              child: Column(
                children: [
                  for (final (mode, label) in [
                    (ThemeMode.light, l10n.themeLight),
                    (ThemeMode.dark, l10n.themeDark),
                    (ThemeMode.system, l10n.themeSystem),
                  ])
                    RadioListTile<ThemeMode>(
                      value: mode,
                      title: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.backup != null) ...[
            _sectionHeader(
                context, Icons.save_rounded, l10n.settingsDataTitle),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  l10n.backupAction,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(l10n.backupSubtitle),
                onTap: () => _exportBackup(context, widget.backup!),
              ),
            ),
          ],
          _sectionHeader(context, Icons.admin_panel_settings_rounded,
              l10n.settingsPermissionsTitle),
          _PermissionsCard(
            smsGranted: _smsGranted,
            batteryExempt: _batteryExempt,
            onOpenSettings: () => _permissions.openAppSettings(),
          ),
          const SizedBox(height: 16),
          _PrivacyCard(),
          const SizedBox(height: 28),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.settingsVersion,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: scheme.primary),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  /// Copies the database and opens the share sheet; the snackbar lands
  /// once sharing finishes (or fails). Messenger and strings are captured
  /// before the await.
  Future<void> _exportBackup(
      BuildContext context, BackupService backup) async {
    final messenger = ScaffoldMessenger.of(context);
    final doneMessage = context.l10n.backupDone;
    final failMessage = context.l10n.backupFailed;
    try {
      final file = await backup.exportBackup();
      if (file == null) throw const _BackupFailedException();
      messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failMessage)));
    }
  }
}

class _BackupFailedException implements Exception {
  const _BackupFailedException();
}

/// Live permission status: one row per permission, granted/denied badge,
/// and the escape hatch to system settings.
class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({
    required this.smsGranted,
    required this.batteryExempt,
    required this.onOpenSettings,
  });

  final bool? smsGranted;
  final bool? batteryExempt;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            _PermissionRow(
              icon: Icons.sms_rounded,
              title: l10n.settingsPermissionSms,
              deniedSubtitle: l10n.settingsPermissionSmsDenied,
              granted: smsGranted,
            ),
            _PermissionRow(
              icon: Icons.battery_charging_full_rounded,
              title: l10n.settingsPermissionBattery,
              deniedSubtitle: l10n.settingsPermissionBatteryDenied,
              granted: batteryExempt,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: Text(l10n.settingsOpenAppSettings),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.deniedSubtitle,
    required this.granted,
  });

  final IconData icon;
  final String title;
  final String deniedSubtitle;
  final bool? granted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final grantedNow = granted == true;
    final checking = granted == null;
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: grantedNow
              ? scheme.tertiaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: grantedNow ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: checking || grantedNow ? null : Text(deniedSubtitle),
      trailing: checking
          // Static placeholder, deliberately not a spinner: the channel
          // check is milliseconds in production, and an indeterminate
          // progress indicator animates forever while pending (which
          // also makes `pumpAndSettle` in widget tests time out).
          ? const SizedBox(width: 18, height: 18)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: grantedNow
                    ? scheme.tertiaryContainer
                    : scheme.errorContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    grantedNow
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 14,
                    color: grantedNow
                        ? scheme.onTertiaryContainer
                        : scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    grantedNow ? l10n.settingsGranted : l10n.settingsDenied,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: grantedNow
                              ? scheme.onTertiaryContainer
                              : scheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The trust note: what this app reads, where data lives.
class _PrivacyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.settingsPrivacyTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.settingsPrivacyBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
