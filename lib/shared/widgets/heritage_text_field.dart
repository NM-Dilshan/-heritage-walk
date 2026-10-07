import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

class HeritageTextField extends StatefulWidget {
  const HeritageTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.validator,
    this.errorText,
    this.onChanged,
    this.keyboardType,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
  });
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool enabled;
  final int? maxLength;
  final int maxLines;

  @override
  State<HeritageTextField> createState() => _HeritageTextFieldState();
}

class _HeritageTextFieldState extends State<HeritageTextField> {
  bool _revealPassword = false;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    maxLength: widget.maxLength,
    maxLines: widget.isPassword ? 1 : widget.maxLines,
    obscureText: widget.isPassword && !_revealPassword,
    autocorrect: !widget.isPassword,
    enableSuggestions: !widget.isPassword,
    keyboardType: widget.keyboardType,
    validator: widget.validator == null
        ? null
        : (value) {
            final error = widget.validator!(value);
            return error == null ? null : AppLocalizations.text(context, error);
          },
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      labelText: AppLocalizations.text(context, widget.label),
      hintText: widget.hint == null
          ? null
          : AppLocalizations.text(context, widget.hint!),
      errorText: widget.errorText == null
          ? null
          : AppLocalizations.text(context, widget.errorText!),
      prefixIcon: widget.prefixIcon,
      suffixIcon:
          widget.suffixIcon ??
          (widget.isPassword
              ? IconButton(
                  tooltip: AppLocalizations.text(
                    context,
                    _revealPassword ? 'Hide password' : 'Show password',
                  ),
                  onPressed: !widget.enabled
                      ? null
                      : () =>
                            setState(() => _revealPassword = !_revealPassword),
                  icon: Icon(
                    _revealPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                )
              : null),
    ),
  );
}
