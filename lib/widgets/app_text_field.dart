import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon),
          ),
        ),
      ],
    );
  }
}

