import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_strings.dart';
import '../app/app_theme.dart';
import '../state/settings_controller.dart';
import '../widgets/pressable.dart';
import '../widgets/sometime_icon_hero.dart';
import '../widgets/sometime_input.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.settingsController,
    required this.onCompleted,
    super.key,
  });

  final SettingsController settingsController;
  final VoidCallback onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController = TextEditingController();
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final CurvedAnimation _stageIcon = _stage(0, 0.45);
  late final CurvedAnimation _stageWelcome = _stage(0.12, 0.58);
  late final CurvedAnimation _stageInput = _stage(0.25, 0.72);
  late final CurvedAnimation _stageActions = _stage(0.38, 0.85);
  bool _hasName = false;
  bool _saving = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _stageIcon.dispose();
    _stageWelcome.dispose();
    _stageInput.dispose();
    _stageActions.dispose();
    _entrance.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nameChanged(String value) {
    final hasName = value.trim().isNotEmpty;
    if (hasName != _hasName) setState(() => _hasName = hasName);
  }

  Future<void> _complete(String? name) async {
    if (_saving) return;
    setState(() => _saving = true);
    widget.onCompleted();
    await widget.settingsController.completeOnboarding(name);
  }

  CurvedAnimation _stage(double start, double end) => CurvedAnimation(
    parent: _entrance,
    curve: Interval(start, end, curve: AppMotion.curve),
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AnnotatedRegion(
      value: appSystemUiFor(context),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 56).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Entrance(
                          animation: _stageIcon,
                          scale: true,
                          child: const SometimeIconHero(decorative: true),
                        ),
                        const SizedBox(height: 30),
                        _Entrance(
                          animation: _stageWelcome,
                          child: Column(
                            children: [
                              Text(
                                strings.welcomeToSometime,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strings.onboardingNameQuestion,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: context.appColors.secondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        _Entrance(
                          animation: _stageInput,
                          child: SometimeInput(
                            controller: _nameController,
                            hint: strings.nameHint,
                            semanticLabel: strings.displayName,
                            maxLength: 10,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            onChanged: _nameChanged,
                            onSubmitted: (_) {
                              if (_hasName && !_saving) {
                                _complete(_nameController.text);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Entrance(
                          animation: _stageActions,
                          child: Row(
                            children: [
                              Expanded(
                                child: _OnboardingButton(
                                  label: strings.skip,
                                  onPressed: _saving
                                      ? null
                                      : () => _complete(null),
                                  primary: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _OnboardingButton(
                                  label: strings.continueLabel,
                                  onPressed: !_hasName || _saving
                                      ? null
                                      : () => _complete(_nameController.text),
                                  primary: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingButton extends StatelessWidget {
  const _OnboardingButton({
    required this.label,
    required this.onPressed,
    required this.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onPressed != null;
    final background = primary && enabled ? colors.accent : colors.track;
    final foreground = primary && enabled
        ? colors.onAccent
        : enabled
        ? colors.text
        : colors.disabled;
    return Pressable(
      label: label,
      onPressed: onPressed,
      radius: AppSpace.controlRadius,
      builder: (context, state) => AnimatedContainer(
        height: 54,
        alignment: Alignment.center,
        duration: AppMotion.duration(context, AppMotion.color),
        curve: AppMotion.curve,
        decoration: BoxDecoration(
          color: state.pressed
              ? Color.alphaBlend(colors.hover, background)
              : background,
          borderRadius: BorderRadius.circular(AppSpace.controlRadius),
        ),
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.duration(context, AppMotion.color),
          curve: AppMotion.curve,
          style: Theme.of(context).textTheme.labelLarge!
              .copyWith(color: foreground, fontWeight: FontWeight.w600),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.animation,
    required this.child,
    this.scale = false,
  });

  final Animation<double> animation;
  final Widget child;
  final bool scale;

  @override
  Widget build(BuildContext context) {
    Widget result = SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
    if (scale) {
      result = ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
        child: result,
      );
    }
    return FadeTransition(opacity: animation, child: result);
  }
}
