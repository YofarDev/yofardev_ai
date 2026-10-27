// ignore-l10n: debug — the UI lab is debug-only; its strings are hardcoded.
import 'package:flutter/material.dart';

import '../../../../core/design/components/components.dart';
import '../../../../core/design/design.dart';

/// Real kit components and typography under the ambient (look) theme, for the
/// UI lab's Surfaces tab. Everything reads the theme, so wrapping it in a
/// different look's `Theme` restyles it.
class LabSurfacesPreview extends StatefulWidget {
  const LabSurfacesPreview({super.key});

  @override
  State<LabSurfacesPreview> createState() => _LabSurfacesPreviewState();
}

class _LabSurfacesPreviewState extends State<LabSurfacesPreview> {
  bool _notifications = true;
  bool _selectedPill = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: <Widget>[
        const _Section('Transcript'),
        const _Transcript(),
        const _Section('Settings group'),
        _SettingsGroup(
          notifications: _notifications,
          onNotifications: (bool v) => setState(() => _notifications = v),
        ),
        const _Section('Toast'),
        const _Toast(),
        const _Section('Pills'),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: <Widget>[
            AppPill(label: 'Idle', onTap: () {}),
            AppPill(
              label: 'Selected',
              selected: _selectedPill,
              onTap: () => setState(() => _selectedPill = !_selectedPill),
            ),
            AppPill(label: 'Icon', icon: Icons.history_rounded, onTap: () {}),
          ],
        ),
        const _Section('Icon buttons'),
        Row(
          children: <Widget>[
            AppIconButton(
              onPressed: () {},
              icon: Icons.mic_rounded,
              semanticLabel: 'Idle',
            ),
            AppIconButton(
              onPressed: () {},
              icon: Icons.mic_rounded,
              semanticLabel: 'Active',
              active: true,
            ),
            const AppIconButton(
              onPressed: null,
              icon: Icons.mic_rounded,
              semanticLabel: 'Disabled',
            ),
          ],
        ),
        const _Section('Glass levels'),
        const _GlassLevels(),
        const _Section('Type'),
        const _TypeSpecimen(),
        const SizedBox(height: AppSpace.xxl),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.sm),
      child: Text(
        title.toUpperCase(),
        style: context.text.labelMedium?.copyWith(
          color: context.colors.onSurface.withValues(alpha: 0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Assistant text un-bubbled at full width, a user bubble in the accent and a
/// tool chip.
class _Transcript extends StatelessWidget {
  const _Transcript();

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool cel = tokens.surfaceStyle == AppSurfaceStyle.cel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.scene.accent,
                borderRadius: BorderRadius.circular(
                  tokens.radius(AppRadius.lg),
                ),
                border: cel
                    ? Border.all(
                        color: tokens.glassBorder,
                        width: tokens.outlineWidth,
                      )
                    : null,
                boxShadow: cel
                    ? <BoxShadow>[
                        BoxShadow(
                          color: tokens.shadow.withValues(alpha: 0.6),
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.md,
                ),
                child: Text(
                  'What is the weather like by the fire tonight?',
                  style: context.text.bodyLarge?.copyWith(
                    color: tokens.scene.onAccent,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: GlassPanel(
            level: AppGlassLevel.thin,
            borderRadius: BorderRadius.circular(tokens.radius(AppRadius.pill)),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.travel_explore_rounded,
                  size: 16,
                  color: tokens.scene.accent,
                ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  'Searched the web · 3 results',
                  style: context.text.labelMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          'Clear skies and a light breeze, so the embers will last long into '
          'the night. Bring a blanket, and maybe a story to tell.',
          style: context.text.bodyLarge,
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.notifications,
    required this.onNotifications,
  });

  final bool notifications;
  final ValueChanged<bool> onNotifications;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.text;
    return GlassPanel(
      child: Column(
        children: <Widget>[
          _SettingsRow(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            trailing: Switch(value: notifications, onChanged: onNotifications),
          ),
          const Divider(),
          _SettingsRow(
            icon: Icons.language_rounded,
            title: 'Language',
            trailing: Text('English', style: text.bodyMedium),
          ),
          const Divider(),
          _SettingsRow(
            icon: Icons.memory_rounded,
            title: 'Memory',
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: context.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 22,
              color: context.colors.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Text(title, style: context.text.titleMedium)),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast();

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return GlassPanel(
      level: AppGlassLevel.thick,
      borderRadius: BorderRadius.circular(tokens.radius(AppRadius.md)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle_rounded, color: tokens.success, size: 20),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text('Chat saved', style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

/// The three glass levels over a glowing strip, so their translucency shows.
class _GlassLevels extends StatelessWidget {
  const _GlassLevels();

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            tokens.scene.glow,
            tokens.scene.accent.withValues(alpha: 0.15),
            tokens.scene.glow,
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radius(AppRadius.lg)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: <Widget>[
            for (final AppGlassLevel level in AppGlassLevel.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                  child: GlassPanel(
                    level: level,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                    child: Center(
                      child: Text(level.name, style: context.text.labelLarge),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeSpecimen extends StatelessWidget {
  const _TypeSpecimen();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Display 32', style: text.headlineLarge),
        const SizedBox(height: AppSpace.sm),
        Text('Title 22', style: text.titleLarge),
        const SizedBox(height: AppSpace.sm),
        Text('Body 16, the quick brown fox', style: text.bodyLarge),
        const SizedBox(height: AppSpace.sm),
        Text(
          '“Caption 20 in the display font”',
          style: text.titleLarge?.copyWith(fontSize: 20),
        ),
      ],
    );
  }
}
