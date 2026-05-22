import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppTextField extends StatefulWidget {
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
    this.suffixIcon,
    this.obscureText = false,
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
  final Widget? suffixIcon;
  final bool obscureText;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = false;
  bool _hasFocus = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: _hasFocus ? AppColors.primaryRed : AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: AppAnimations.fast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _hasFocus
                  ? AppColors.primaryRed.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            readOnly: widget.readOnly,
            maxLines: widget.maxLines,
            validator: widget.validator,
            onChanged: widget.onChanged,
            obscureText: _obscured,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.icon == null ? null : Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: Icon(widget.icon, size: 20, color: _hasFocus ? AppColors.primaryRed : AppColors.textSecondary),
              ),
              prefixIconConstraints: widget.icon != null
                  ? const BoxConstraints(minWidth: 44, minHeight: 24)
                  : null,
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : widget.suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}
