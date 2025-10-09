import 'package:flutter/material.dart';

/// Paleta base (adáptala a tu Theme si quieres)
const _kPrimary = Color(0xFF3BB9FD);
const _kCardBg  = Color(0xFFF6F2FF);

/// ---------- CARD ----------
class PetfyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  const PetfyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin  = const EdgeInsets.symmetric(vertical: 8),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// ---------- TEXT FIELD ----------
class PetfyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? prefix;                           // ícono a la izquierda
  final Widget? suffix;                           // ícono a la derecha
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const PetfyTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboard,
    this.prefix,
    this.suffix,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: _kCardBg.withOpacity(0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.4),
        ),
      ),
    );
  }
}

/// ---------- BUTTON ----------
class PetfyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? leading; // <- opcional para ícono a la izquierda

  const PetfyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            height: 20, width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          );

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      ),
    );
  }
}

/// ---------- DROPDOWN ----------
class PetfyDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String hint;
  final String? Function(T?)? validator;
  final String? label; // <- opcional para colocar label encima

  const PetfyDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    this.validator,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _kCardBg.withOpacity(0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(.15)),
        ),
      ),
    );
  }
}

/// ---------- LINK ----------
class PetfyLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final TextAlign align;

  const PetfyLink({
    super.key,
    required this.text,
    required this.onTap,
    this.align = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            text,
            textAlign: align,
            style: const TextStyle(
              color: _kPrimary,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
