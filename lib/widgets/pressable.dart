import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../services/app_haptics.dart';

const appLongPressDuration = Duration(milliseconds: 380);

class PressState {
  const PressState({required this.pressed, required this.hovered});

  final bool pressed;
  final bool hovered;
}

class Pressable extends StatefulWidget {
  const Pressable({
    required this.label,
    required this.onPressed,
    required this.builder,
    this.onLongPress,
    this.isButton = true,
    this.hapticOnTap = true,
    this.hapticOnLongPress = true,
    this.checked,
    this.selected,
    this.expanded,
    this.excludeChildSemantics = true,
    this.scale = 0.96,
    this.radius = 16,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget Function(BuildContext, PressState) builder;
  final VoidCallback? onLongPress;
  final bool isButton;
  final bool hapticOnTap;
  final bool hapticOnLongPress;
  final bool? checked;
  final bool? selected;
  final bool? expanded;
  final bool excludeChildSemantics;
  final double scale;
  final double radius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;
  bool _showFocus = false;

  bool get _enabled => widget.onPressed != null;

  void _activate() {
    if (!_enabled) return;
    if (widget.hapticOnTap) AppHaptics.selection();
    widget.onPressed!();
  }

  void _activateLongPress() {
    if (widget.onLongPress == null) return;
    if (widget.hapticOnLongPress) AppHaptics.medium();
    widget.onLongPress!();
  }

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.label,
      button: widget.isButton,
      checked: widget.checked,
      selected: widget.selected,
      expanded: widget.expanded,
      enabled: _enabled,
      focusable: _enabled,
      focused: _focused,
      onTap: _enabled ? _activate : null,
      onLongPress: widget.onLongPress == null ? null : _activateLongPress,
      excludeSemantics: widget.excludeChildSemantics,
      child: FocusableActionDetector(
        enabled: _enabled,
        includeFocusSemantics: false,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onFocusChange: (value) => setState(() => _focused = value),
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: Listener(
          onPointerDown: _enabled ? (_) => _setPressed(true) : null,
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapCancel: () => _setPressed(false),
            onTap: _enabled ? _activate : null,

            child: RawGestureDetector(
              gestures: {
                if (widget.onLongPress != null)
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer
                      >(
                        () => LongPressGestureRecognizer(
                          duration: appLongPressDuration,
                        ),
                        (recognizer) =>
                            recognizer.onLongPress = _activateLongPress,
                      ),
              },
              child: AnimatedScale(
                scale: _pressed && _enabled ? widget.scale : 1,
                duration: AppMotion.duration(context, AppMotion.press),
                curve: AppMotion.curve,
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.press),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    border: Border.all(
                      color: _showFocus
                          ? context.appColors.focus
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: widget.builder(
                    context,
                    PressState(
                      pressed: _pressed && _enabled,
                      hovered: _hovered && _enabled,
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
