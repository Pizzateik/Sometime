import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/app_strings.dart';

class SometimeInput extends StatefulWidget {
  const SometimeInput({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onSubmitted,
    this.semanticLabel,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? semanticLabel;

  @override
  State<SometimeInput> createState() => _SometimeInputState();
}

class _SometimeInputState extends State<SometimeInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.duration(context, AppMotion.color),
    constraints: const BoxConstraints(minHeight: 58),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: context.appColors.pill,
      borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      border: Border.all(
        color: _focus.hasFocus
            ? context.appColors.activeBorder
            : Colors.transparent,
        width: 1.25,
      ),
    ),
    child: Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        maxLength: widget.maxLength,
        maxLengthEnforcement: widget.maxLengthEnforcement,
        cursorWidth: 1.5,
        textAlignVertical: TextAlignVertical.center,
        textCapitalization: TextCapitalization.words,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(hintText: widget.hint, counterText: ''),
      ),
    ),
  );
}

class SometimeNameDialog extends StatefulWidget {
  const SometimeNameDialog({this.initialName, super.key});

  final String? initialName;

  @override
  State<SometimeNameDialog> createState() => _SometimeNameDialogState();
}

class _SometimeNameDialogState extends State<SometimeNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.strings.nameQuestion),
    content: SometimeInput(
      controller: _controller,
      autofocus: true,
      maxLength: 10,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      hint: context.strings.nameHint,
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, ''),
        child: Text(context.strings.skip),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(context.strings.continueLabel),
      ),
    ],
  );
}
