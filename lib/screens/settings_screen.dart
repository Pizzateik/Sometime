import '../app/sometime_icons.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_config.dart';
import '../app/app_strings.dart';
import '../app/app_theme.dart';
import '../membership/membership_assets.dart';
import '../membership/membership_hero.dart';
import '../models/theme_preference.dart';
import '../services/notification_service.dart';
import '../services/support_purchase_service.dart';
import '../services/data_transfer.dart';
import '../services/app_haptics.dart';

import 'package:share_plus/share_plus.dart';

import '../state/settings_controller.dart';
import '../state/theme_controller.dart';
import '../state/todo_controller.dart';
import '../widgets/pressable.dart';
import '../widgets/sometime_input.dart';
import '../widgets/sometime_icon_hero.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.themeController,
    required this.settingsController,
    required this.todoController,
    required this.purchaseService,
    this.notifications,
    super.key,
  });

  final ThemeController themeController;
  final SettingsController settingsController;
  final TodoController todoController;
  final SupportPurchaseService purchaseService;
  final NotificationService? notifications;

  void _open(BuildContext context, Widget page) {
    unawaited(
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page)),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settingsController,
    builder: (context, _) {
      final strings = context.strings;
      final value = settingsController.value;
      final hasCard =
          value.isSupporter &&
          value.supportDate != null &&
          value.membershipShapeIndex != null &&
          value.membershipGradientIndex != null;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpace.contentWidth),
          child: ListView(
            key: const PageStorageKey('settings-scroll'),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.settingsMainAxis,
              20,
              AppSpace.settingsMainAxis,
              72,
            ),
            children: [
              Text(strings.settings, style: context.appTypography.display),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: AppMotion.duration(
                  context,
                  const Duration(milliseconds: 520),
                ),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: hasCard
                    ? MembershipHero(
                        key: const ValueKey('membership-card'),
                        displayName: value.displayName,
                        supportDate: value.supportDate!,
                        shapeAsset:
                            MembershipAssets.shapes[value
                                    .membershipShapeIndex! %
                                MembershipAssets.shapes.length],
                        gradientAsset:
                            MembershipAssets.gradients[value
                                    .membershipGradientIndex! %
                                MembershipAssets.gradients.length],
                      )
                    : const _BrandHero(key: ValueKey('brand-hero')),
              ),
              const SizedBox(height: 18),
              Text(strings.appName, style: context.appTypography.sectionTitle),
              const SizedBox(height: 8),
              Text(
                strings.appDescription,
                style: context.appTypography.secondary,
              ),
              const SizedBox(height: 12),
              _SettingsRow(
                label: strings.whyBuilt,
                indent: false,
                onPressed: () => _open(context, const WhySometimeScreen()),
              ),
              const SizedBox(height: 30),
              _SettingsRow(
                icon: SometimeIcons.palette,
                label: strings.experience,
                onPressed: () => _open(
                  context,
                  ExperienceScreen(
                    themeController: themeController,
                    settingsController: settingsController,
                  ),
                ),
              ),
              _SettingsRow(
                icon: SometimeIcons.bell,
                label: strings.notifications,
                onPressed: () => _open(
                  context,
                  NotificationsScreen(
                    settingsController: settingsController,
                    notifications: notifications,
                  ),
                ),
              ),
              _SettingsRow(
                icon: SometimeIcons.globe,
                label: strings.language,
                onPressed: () => _open(
                  context,
                  LanguageScreen(settingsController: settingsController),
                ),
              ),
              _SettingsRow(
                icon: SometimeIcons.shield,
                label: strings.dataPrivacy,
                onPressed: () => _open(
                  context,
                  DataPrivacyScreen(
                    todoController: todoController,
                    settingsController: settingsController,
                    themeController: themeController,
                  ),
                ),
              ),
              const SizedBox(height: 38),
              _SectionLabel(strings.about),
              const SizedBox(height: 10),
              const _AboutRows(),
              if (value.isSupporter ||
                  purchaseService.enabled ||
                  kDebugMode) ...[
                const SizedBox(height: 34),
                if (value.isSupporter)
                  _SupportButton(
                    title: strings.supporterThanks,
                    description: strings.rerollCardDescription,
                    onPressed: kDebugMode && !purchaseService.enabled
                        ? () => _open(
                            context,
                            SupportScreen(
                              settingsController: settingsController,
                              purchaseService: purchaseService,
                            ),
                          )
                        : () => unawaited(_confirmReroll(context)),
                  )
                else
                  _SupportButton(
                    title: strings.support,
                    description: strings.supportNote,
                    onPressed: () => _open(
                      context,
                      SupportScreen(
                        settingsController: settingsController,
                        purchaseService: purchaseService,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Future<void> _confirmReroll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.rerollCardQuestion),
        content: Text(context.strings.rerollCardExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings.reroll),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final changed = await settingsController.rerollMembership(
      shapeCount: MembershipAssets.shapes.length,
      gradientCount: MembershipAssets.gradients.length,
    );
    if (changed) AppHaptics.selection();
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero({super.key});

  @override
  Widget build(BuildContext context) =>
      Center(child: SometimeIconHero(semanticLabel: context.strings.appIcon));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.appTypography.controlLabel.copyWith(
      color: context.appColors.secondary,
      fontSize: 11,
      letterSpacing: 1.2,
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.onPressed,
    this.icon,
    this.value,
    this.external = false,
    this.destructive = false,
    this.indent = true,
  });

  final IconData? icon;
  final String label;
  final String? value;
  final bool external;
  final bool destructive;
  final bool indent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    label: external ? context.strings.externalLink(label) : label,
    onPressed: onPressed,
    scale: 0.99,
    radius: 12,
    builder: (context, state) => Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: EdgeInsets.fromLTRB(
        indent ? AppSpace.settingsRowIndent : 0,
        10,
        10,
        10,
      ),
      decoration: BoxDecoration(
        color: state.hovered || state.pressed ? context.appColors.hover : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            SizedBox(
              width: 30,
              child: Icon(
                icon,
                size: 19,
                color: destructive
                    ? context.appColors.destructive
                    : context.appColors.ink,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: context.appTypography.body.copyWith(
                color: destructive ? context.appColors.destructive : null,
              ),
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.secondary.copyWith(fontSize: 14),
              ),
            ),
          ],
          if (onPressed != null) ...[
            const SizedBox(width: 8),
            Icon(
              external ? SometimeIcons.arrowUpRight : SometimeIcons.caretRight,
              size: external ? 17 : 20,
              color: context.appColors.secondary,
            ),
          ],
        ],
      ),
    ),
  );
}

class _AboutRows extends StatelessWidget {
  const _AboutRows();

  Future<void> _open(String source) async {
    final uri = Uri.tryParse(source);
    if (uri == null || !_isExternalUrl(uri)) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // A missing external handler must not interrupt the settings page.
    }
  }

  static bool _isExternalUrl(Uri uri) =>
      uri.host.isNotEmpty && (uri.scheme == 'http' || uri.scheme == 'https');

  bool _available(String source) {
    final uri = Uri.tryParse(source);
    return uri != null && _isExternalUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final portfolioAvailable = _available(AppConfig.portfolioUrl);
    final sourceCodeAvailable = _available(AppConfig.sourceCodeUrl);
    final privacyPolicyAvailable = _available(AppConfig.privacyPolicyUrl);
    return Column(
      children: [
        _SettingsRow(
          label: strings.madeBy(AppConfig.developerName),
          external: portfolioAvailable,
          onPressed: !portfolioAvailable
              ? null
              : () => unawaited(_open(AppConfig.portfolioUrl)),
        ),
        if (sourceCodeAvailable)
          _SettingsRow(
            label: strings.sourceCode,
            external: true,
            onPressed: () => unawaited(_open(AppConfig.sourceCodeUrl)),
          ),
        if (privacyPolicyAvailable)
          _SettingsRow(
            label: strings.privacyPolicy,
            external: true,
            onPressed: () => unawaited(_open(AppConfig.privacyPolicyUrl)),
          ),
        _SettingsRow(
          label: strings.licenses,
          onPressed: () => showLicensePage(
            context: context,
            applicationName: strings.appName,
          ),
        ),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            final version = info?.version;
            return _SettingsRow(
              label: strings.version,
              value: version,
              onPressed: null,
            );
          },
        ),
      ],
    );
  }
}

class WhySometimeScreen extends StatelessWidget {
  const WhySometimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _Subpage(
      title: strings.whyBuilt,
      children: [
        Text(
          strings.whyBuiltBody,
          style: context.appTypography.body.copyWith(height: 1.65),
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Trait(strings.offlineFirst),
            _Trait(strings.adFree),
            _Trait(strings.openSource),
            _Trait(strings.noAccount),
          ],
        ),
      ],
    );
  }
}

class _Trait extends StatelessWidget {
  const _Trait(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: context.appColors.track),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: context.appTypography.controlLabel),
  );
}

class ExperienceScreen extends StatelessWidget {
  const ExperienceScreen({
    required this.themeController,
    required this.settingsController,
    super.key,
  });
  final ThemeController themeController;
  final SettingsController settingsController;

  Future<void> _pickSeed(BuildContext context) async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (_) => _SeedPicker(initial: themeController.seedColor),
    );
    if (selected == null ||
        selected.toARGB32() == themeController.seedColor.toARGB32()) {
      return;
    }
    await themeController.setSeedColor(selected);
    AppHaptics.selection();
  }

  Future<void> _selectStyle(BuildContext context, AppearanceStyle style) async {
    if (themeController.style != style) {
      await themeController.setStyle(style);
      AppHaptics.selection();
      return;
    }
    if (style != AppearanceStyle.materialYou ||
        themeController.useSystemColors) {
      return;
    }
    if (themeController.colorSource != MaterialColorSource.custom) {
      await themeController.setColorSource(MaterialColorSource.custom);
      AppHaptics.selection();
      if (!context.mounted) return;
    }
    await _pickSeed(context);
  }

  Future<void> _selectColorSource(
    BuildContext context,
    MaterialColorSource source,
  ) async {
    final changed = themeController.colorSource != source;
    if (changed) {
      await themeController.setColorSource(source);
      AppHaptics.selection();
    }
    if (source == MaterialColorSource.custom && context.mounted) {
      await _pickSeed(context);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([themeController, settingsController]),
    builder: (context, _) {
      final strings = context.strings;
      return _Subpage(
        title: strings.experience,
        children: [
          Text(strings.style, style: context.appTypography.sectionTitle),
          const SizedBox(height: 14),
          Row(
            children: [
              for (
                var index = 0;
                index < AppearanceStyle.values.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 10),
                Expanded(
                  child: _StyleButton(
                    style: AppearanceStyle.values[index],
                    controller: themeController,
                    selected:
                        themeController.style == AppearanceStyle.values[index],
                    onPressed: () => unawaited(
                      _selectStyle(context, AppearanceStyle.values[index]),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (themeController.style == AppearanceStyle.materialYou) ...[
            const SizedBox(height: 16),
            if (themeController.dynamicColorsAvailable)
              _ChoiceRow(
                label: strings.materialYou,
                selected:
                    themeController.colorSource == MaterialColorSource.system,
                onPressed: () => unawaited(
                  _selectColorSource(context, MaterialColorSource.system),
                ),
              ),
            _ChoiceRow(
              label: strings.customColor,
              selected:
                  themeController.colorSource == MaterialColorSource.custom ||
                  !themeController.dynamicColorsAvailable,
              onPressed: () => unawaited(
                _selectColorSource(context, MaterialColorSource.custom),
              ),
            ),
          ],
          const SizedBox(height: 34),
          Text(strings.mode, style: context.appTypography.sectionTitle),
          const SizedBox(height: 8),
          for (final mode in AppearanceMode.values)
            _ChoiceRow(
              label: switch (mode) {
                AppearanceMode.system => strings.system,
                AppearanceMode.light => strings.light,
                AppearanceMode.dark => strings.dark,
              },
              selected: themeController.mode == mode,
              onPressed: () => unawaited(themeController.setMode(mode)),
            ),
          const SizedBox(height: 26),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.haptics, style: context.appTypography.body),
            value: settingsController.value.hapticsEnabled,
            onChanged: (value) =>
                unawaited(settingsController.setHaptics(value)),
          ),
        ],
      );
    },
  );
}

typedef AppearanceScreen = ExperienceScreen;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    required this.settingsController,
    required this.notifications,
    super.key,
  });
  final SettingsController settingsController;
  final NotificationService? notifications;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settingsController,
    builder: (context, _) {
      final minutes = settingsController.value.morningReminderMinutes;
      final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
      return _Subpage(
        title: context.strings.notifications,
        children: [
          _SettingsRow(
            label: context.strings.morningReminder,
            value: MaterialLocalizations.of(context).formatTimeOfDay(time),
            onPressed: () async {
              final selected = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (selected == null) return;
              await settingsController.setMorningReminderMinutes(
                selected.hour * 60 + selected.minute,
              );
              notifications?.refresh();
            },
          ),
          if (NotificationService.supported)
            _SettingsRow(
              label: context.strings.notificationSettings,
              external: true,
              onPressed: notifications == null
                  ? null
                  : () => unawaited(notifications!.openSettings()),
            ),
        ],
      );
    },
  );
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({required this.settingsController, super.key});
  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settingsController,
    builder: (context, _) {
      final strings = context.strings;
      final selected = settingsController.value.language;
      return _Subpage(
        title: strings.language,
        children: [
          _ChoiceRow(
            label: strings.system,
            selected: selected == 'system',
            onPressed: () => settingsController.setLanguage('system'),
          ),
          _ChoiceRow(
            label: strings.german,
            selected: selected == 'de',
            onPressed: () => settingsController.setLanguage('de'),
          ),
          _ChoiceRow(
            label: strings.english,
            selected: selected == 'en',
            onPressed: () => settingsController.setLanguage('en'),
          ),
          _ChoiceRow(
            label: strings.spanish,
            selected: selected == 'es',
            onPressed: () => settingsController.setLanguage('es'),
          ),
          _ChoiceRow(
            label: strings.portugueseBrazil,
            selected: selected == 'pt-BR',
            onPressed: () => settingsController.setLanguage('pt-BR'),
          ),
          _ChoiceRow(
            label: strings.french,
            selected: selected == 'fr',
            onPressed: () => settingsController.setLanguage('fr'),
          ),
          _ChoiceRow(
            label: strings.japanese,
            selected: selected == 'ja',
            onPressed: () => settingsController.setLanguage('ja'),
          ),
        ],
      );
    },
  );
}

class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({
    required this.todoController,
    required this.settingsController,
    required this.themeController,
    super.key,
  });
  final TodoController todoController;
  final SettingsController settingsController;
  final ThemeController themeController;

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  TodoController get todoController => widget.todoController;
  SettingsController get settingsController => widget.settingsController;
  ThemeController get themeController => widget.themeController;
  bool _busy = false;
  bool _success = false;

  Future<void> _transfer(bool importing) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _success = false;
    });
    try {
      final transfer = DataTransfer(
        todoController,
        settingsController,
        themeController,
      );
      if (importing) {
        final data = await transfer.pick();
        if (!mounted || data == null) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.strings.importQuestion),
            content: Text(context.strings.importExplanation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.strings.importAction),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await transfer.import(data);
      } else {
        final result = await transfer.export(context);
        if (result.status != ShareResultStatus.success) return;
      }
      AppHaptics.medium();
      if (mounted) setState(() => _success = true);
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(context.strings.transferError),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.strings.cancel),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.deleteQuestion),
        content: Text(context.strings.deleteExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await todoController.deleteAllData();
    await settingsController.resetLocalPreferences();
    await themeController.reset();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => _Subpage(
    title: context.strings.dataPrivacy,
    children: [
      _SectionLabel(context.strings.onDevice.toUpperCase()),
      const SizedBox(height: 12),
      _SettingsRow(
        icon: SometimeIcons.user,
        label: context.strings.displayName,
        value: settingsController.value.displayName ?? context.strings.notSet,
        onPressed: _busy
            ? null
            : () async {
                await showDisplayNameDialog(context, settingsController);
                if (mounted) setState(() {});
              },
      ),
      _SettingsRow(
        icon: SometimeIcons.export,
        label: context.strings.exportData,
        onPressed: _busy ? null : () => _transfer(false),
      ),
      _SettingsRow(
        icon: SometimeIcons.import,
        label: context.strings.importData,
        onPressed: _busy ? null : () => _transfer(true),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_success)
        Semantics(
          liveRegion: true,
          child: Text(context.strings.transferSuccess),
        ),
      _SettingsRow(
        icon: SometimeIcons.trash,
        label: context.strings.deleteAll,
        destructive: true,
        onPressed: _busy ? null : () => unawaited(_delete(context)),
      ),
    ],
  );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({
    required this.settingsController,
    required this.purchaseService,
    super.key,
  });
  final SettingsController settingsController;
  final SupportPurchaseService purchaseService;

  String _status(BuildContext context, SupportPurchaseState state) =>
      switch (state) {
        SupportPurchaseState.loading => context.strings.storeConnecting,
        SupportPurchaseState.purchasing => context.strings.storeWaiting,
        SupportPurchaseState.unavailable => context.strings.supportUnavailable,
        SupportPurchaseState.error => context.strings.purchaseError,
        SupportPurchaseState.canceled => context.strings.purchaseCanceled,
        SupportPurchaseState.restoredNothing => context.strings.noPurchase,
        SupportPurchaseState.success => context.strings.supportThankYou,
        _ => '',
      };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([purchaseService, settingsController]),
    builder: (context, _) {
      final supporter = settingsController.value.isSupporter;
      final purchasesEnabled = purchaseService.enabled;
      final busy =
          purchaseService.state == SupportPurchaseState.loading ||
          purchaseService.state == SupportPurchaseState.purchasing;
      return _Subpage(
        title: supporter ? context.strings.supporter : context.strings.support,
        children: [
          if (purchasesEnabled || supporter) ...[
            Text(
              context.strings.supportNote,
              style: context.appTypography.sectionTitle,
            ),
            const SizedBox(height: 18),
            Text(
              context.strings.supportBody,
              style: context.appTypography.body,
            ),
            const SizedBox(height: 32),
          ],
          if (purchasesEnabled && !supporter)
            FilledButton(
              onPressed: purchaseService.canPurchase
                  ? () => unawaited(purchaseService.purchase())
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  purchaseService.price == null
                      ? context.strings.becomeSupporter
                      : '${context.strings.becomeSupporter} · ${purchaseService.price}',
                ),
              ),
            ),
          if (purchasesEnabled && !supporter) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: busy
                  ? null
                  : () => unawaited(purchaseService.restore()),
              child: Text(context.strings.restore),
            ),
          ],
          if (purchasesEnabled &&
              _status(context, purchaseService.state).isNotEmpty) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _status(context, purchaseService.state),
                textAlign: TextAlign.center,
                style: context.appTypography.secondary.copyWith(fontSize: 14),
              ),
            ),
          ],
          if (kDebugMode) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.appColors.pill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'DEBUG',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(context.strings.previewSupporterState),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => settingsController.debugSetSupporter(
                      !supporter,
                      shapeCount: MembershipAssets.shapes.length,
                      gradientCount: MembershipAssets.gradients.length,
                    ),
                    child: Text(
                      supporter
                          ? context.strings.resetSupporterLocally
                          : context.strings.unlockSupporterLocally,
                    ),
                  ),
                  if (supporter)
                    TextButton(
                      onPressed: () =>
                          settingsController.debugRegenerateMembership(
                            shapeCount: MembershipAssets.shapes.length,
                            gradientCount: MembershipAssets.gradients.length,
                          ),
                      child: Text(context.strings.regenerateMembershipCard),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({
    required this.title,
    required this.description,
    required this.onPressed,
  });
  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    label: title,
    onPressed: onPressed,
    builder: (context, state) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      decoration: BoxDecoration(
        color: context.appColors.strongSelection,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: context.appTypography.buttonLabel.copyWith(
              color: context.appColors.onStrongSelection,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: context.appTypography.caption.copyWith(
              color: context.appColors.onStrongSelection.withValues(
                alpha: 0.68,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Subpage extends StatelessWidget {
  const _Subpage({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: true,
    child: Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: context.appColors.background,
        foregroundColor: context.appColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpace.contentWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            children: children,
          ),
        ),
      ),
    ),
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    label: label,
    selected: selected,
    onPressed: onPressed,
    builder: (context, state) => SizedBox(
      height: 50,
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.appTypography.body)),
          if (selected) const Icon(SometimeIcons.check, size: 20),
        ],
      ),
    ),
  );
}

class _StyleButton extends StatelessWidget {
  const _StyleButton({
    required this.style,
    required this.controller,
    required this.selected,
    required this.onPressed,
  });
  final AppearanceStyle style;
  final ThemeController controller;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (style) {
      AppearanceStyle.normal => context.strings.crisp,
      AppearanceStyle.soft => context.strings.soft,
      AppearanceStyle.materialYou => context.strings.color,
    };
    final brightness = Theme.of(context).brightness;
    final selectedColors = _selectedStyleColors(
      controller: controller,
      brightness: brightness,
      style: style,
    );
    final colors = context.appColors;
    final background = selected
        ? selectedColors.$1
        : Color.alphaBlend(colors.hover, colors.surface);
    final foreground = selected ? selectedColors.$2 : colors.text;
    return Pressable(
      label: label,
      selected: selected,
      onPressed: onPressed,
      hapticOnTap: false,
      scale: 0.97,
      radius: AppSpace.controlRadius,
      builder: (context, state) => AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.color),
        curve: AppMotion.curve,
        height: 48,
        decoration: BoxDecoration(
          color: state.pressed
              ? Color.alphaBlend(colors.hover, background)
              : background,
          borderRadius: BorderRadius.circular(AppSpace.controlRadius),
          border: Border.all(
            color: selected ? foreground : colors.track,
            width: selected ? 1.2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.duration(context, AppMotion.color),
          curve: AppMotion.curve,
          style:
              (selected
                      ? context.appTypography.segmentedSelected
                      : context.appTypography.segmentedUnselected)
                  .copyWith(color: foreground),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

(Color, Color) _selectedStyleColors({
  required ThemeController controller,
  required Brightness brightness,
  required AppearanceStyle style,
}) {
  if (style == AppearanceStyle.normal) {
    return brightness == Brightness.dark
        ? (Colors.white, Colors.black)
        : (Colors.black, Colors.white);
  }
  if (style == AppearanceStyle.soft) {
    return brightness == Brightness.dark
        ? (AppBackgrounds.offWhite, Colors.black)
        : (AppBackgrounds.softDark, Colors.white);
  }
  final scheme = controller.useSystemColors
      ? (brightness == Brightness.dark
            ? controller.dynamicDark!
            : controller.dynamicLight!)
      : sometimeColorScheme(brightness, seed: controller.seedColor);
  return (scheme.primary, scheme.onPrimary);
}

Future<void> showDisplayNameDialog(
  BuildContext context,
  SettingsController controller,
) async {
  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (context) =>
        SometimeNameDialog(initialName: controller.value.displayName),
  );
  if (result == null) return;
  await controller.setDisplayName(result);
}

class _SeedPicker extends StatefulWidget {
  const _SeedPicker({required this.initial});
  final Color initial;

  @override
  State<_SeedPicker> createState() => _SeedPickerState();
}

class _SeedPickerState extends State<_SeedPicker> {
  late HSVColor color = HSVColor.fromColor(widget.initial);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.strings.customColor),
    content: SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: color.toColor(),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          for (final component in [
            (key: 'hue', label: context.strings.hue),
            (key: 'saturation', label: context.strings.saturation),
            (key: 'brightness', label: context.strings.brightness),
          ]) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(component.label),
            ),
            Slider(
              value: switch (component.key) {
                'hue' => color.hue / 360,
                'saturation' => color.saturation,
                _ => color.value,
              },
              onChanged: (value) => setState(() {
                color = switch (component.key) {
                  'hue' => color.withHue(value * 360),
                  'saturation' => color.withSaturation(value),
                  _ => color.withValue(value),
                };
              }),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.strings.cancel),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, color.toColor()),
        child: Text(context.strings.useColor),
      ),
    ],
  );
}
