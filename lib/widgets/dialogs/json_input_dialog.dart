import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../themes/app_typography.dart';

class JsonInputDialog extends StatefulWidget {
  const JsonInputDialog({
    super.key,
    required this.title,
    required this.initialText,
    required this.cancelLabel,
    required this.applyLabel,
    this.hint,
    this.copyPathLabel,
    this.helper,
    this.validateSyntax = true,
    this.validate,
  });
  final String title, initialText, cancelLabel, applyLabel;
  final String? hint, helper, copyPathLabel;
  final bool validateSyntax;
  final void Function(String)? validate;
  @override
  State<JsonInputDialog> createState() => _JsonInputDialogState();
}

class _JsonInputDialogState extends State<JsonInputDialog> {
  late final controller = TextEditingController(text: widget.initialText);
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 650,
      child: TextField(
        autofocus: true,
        controller: controller,
        minLines: 5,
        maxLines: 15,
        style: AppTypography.codeStyle(context),
        decoration: InputDecoration(
          errorText: error,
          hintText: widget.hint,
          helperText: widget.helper,
          helperMaxLines: 4,
        ),
      ),
    ),
    actions: [
      if (widget.copyPathLabel case final label?)
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: widget.title)),
          icon: const Icon(Icons.copy),
          label: Text(label),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(
        onPressed: () {
          try {
            if (widget.validateSyntax) jsonDecode(controller.text);
            widget.validate?.call(controller.text);
            Navigator.pop(context, controller.text);
          } catch (e) {
            setState(() => error = e.toString());
          }
        },
        child: Text(widget.applyLabel),
      ),
    ],
  );
}
