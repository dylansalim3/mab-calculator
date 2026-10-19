import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';
import 'app_info.dart';
import 'color_picker_dialog.dart';
import 'theme_controller.dart';
import 'theme_presets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.theme,
    this.infoLoader = loadAppInfo,
    this.sharer = shareApp,
  });

  final ThemeController theme;
  final AppInfoLoader infoLoader;
  final AppSharer sharer;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    widget.infoLoader().then((info) {
      if (mounted) setState(() => _version = info.versionName);
    });
  }

  Future<void> _share() async {
    try {
      await widget.sharer();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the share sheet')),
      );
    }
  }

  String _modeLabel(ThemeMode m) => switch (m) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  String _colorLabel(Color c) {
    for (final p in themePresets) {
      if (p.color.toARGB32() == c.toARGB32()) return p.name;
    }
    return 'Custom (${colorHex(c)})';
  }

  Future<void> _chooseMode() async {
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: widget.theme.mode,
            onChanged: (m) => Navigator.pop(context, m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: m,
                    title: Text(_modeLabel(m)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) widget.theme.setMode(picked);
  }

  Future<void> _chooseColor() async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Color theme'),
        content: SingleChildScrollView(
          child: _ColorChoices(
            selected: widget.theme.seed,
            onSelect: (c) => Navigator.pop(context, c),
            onCustom: () async {
              final custom = await showDialog<Color>(
                context: context,
                builder: (_) => ColorPickerDialog(initial: widget.theme.seed),
              );
              if (custom != null && context.mounted) {
                Navigator.pop(context, custom);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (picked != null) widget.theme.setSeed(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ScreenBody(
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: widget.theme,
              builder: (context, _) => Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.brightness_6_outlined),
                    title: const Text('Theme'),
                    subtitle: Text(_modeLabel(widget.theme.mode)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _chooseMode,
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: widget.theme.seed,
                    ),
                    title: const Text('Color theme'),
                    subtitle: Text(_colorLabel(widget.theme.seed)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _chooseColor,
                  ),
                ],
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share app'),
                  subtitle: const Text('Send the MoneyKit app to a friend'),
                  onTap: _share,
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Open-source licences'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'MoneyKit',
                    applicationVersion: _version,
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'About',
            child: Column(
              children: [
                StatRow(label: 'Version', value: _version ?? '—'),
                const SizedBox(height: 4),
                Text(
                  'MoneyKit works fully offline. Nothing you enter leaves your device.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Disclaimer('Estimates only — not financial advice.'),
        ],
      ),
    );
  }
}

class _ColorChoices extends StatelessWidget {
  const _ColorChoices({
    required this.selected,
    required this.onSelect,
    required this.onCustom,
  });

  final Color selected;
  final ValueChanged<Color> onSelect;
  final VoidCallback onCustom;

  bool _isPreset(Color c) =>
      themePresets.any((p) => p.color.toARGB32() == c.toARGB32());

  @override
  Widget build(BuildContext context) {
    final custom = !_isPreset(selected);
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: [
        for (final p in themePresets)
          _Swatch(
            label: p.name,
            color: p.color,
            selected: p.color.toARGB32() == selected.toARGB32(),
            onTap: () => onSelect(p.color),
          ),
        _Swatch(
          label: 'Custom',
          color: custom ? selected : null,
          selected: custom,
          icon: Icons.palette_outlined,
          onTap: onCustom,
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = color ?? scheme.surfaceContainerHighest;
    final fg = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check, color: fg)
                      : icon == null
                      ? null
                      : Icon(icon, color: fg),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
