import 'package:flutter/material.dart';

/// ---------- CARD ----------
class PetfyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const PetfyCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(12),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.06),
          )
        ],
      ),
      child: child,
    );
  }
}

/// ---------- TEXT FIELD ----------
class PetfyTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;

  const PetfyTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.prefix,
    this.suffix,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      textInputAction: textInputAction,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? 1 : minLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

/// ---------- BUTTON ----------
class PetfyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? leading;

  const PetfyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ],
        Text(text),
      ],
    );

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2),
              )
            : child,
      ),
    );
  }
}

/// ---------- DROPDOWN ----------
class PetfyDropdown<T> extends StatelessWidget {
  final T? value;
  /// Acepta `List<String>` o `List<DropdownMenuItem<T>>`.
  final List<dynamic> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;

  const PetfyDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
  });

  List<DropdownMenuItem<T>> _buildItems() {
    if (items.isEmpty) return <DropdownMenuItem<T>>[]; // <-- sin const
    if (items.first is DropdownMenuItem<T>) {
      return items.cast<DropdownMenuItem<T>>();
    }
    // Asumimos List<String>
    return (items as List).map<DropdownMenuItem<T>>((e) {
      final text = e.toString();
      return DropdownMenuItem<T>(
        value: text as T,
        child: Text(text),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: _buildItems(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

/// ---------- LINK ----------
class PetfyLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const PetfyLink({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(text, style: const TextStyle(decoration: TextDecoration.underline)),
    );
  }
}
