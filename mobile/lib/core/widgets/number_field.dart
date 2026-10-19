import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Outlined numeric text field. Accepts digits, one '.', thousands commas and
/// (optionally) a leading '-'.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.controller,
    this.prefixText,
    this.suffixText,
    this.helperText,
    this.errorText,
    this.allowNegative = false,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final TextEditingController controller;
  final String? prefixText;
  final String? suffixText;
  final String? helperText;
  final String? errorText;
  final bool allowNegative;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: textInputAction,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: allowNegative,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(allowNegative ? r'[0-9.,\-]' : r'[0-9.,]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        suffixText: suffixText,
        helperText: helperText,
        errorText: errorText,
      ),
    );
  }
}
