import 'package:flutter/material.dart';

/// Colores base PetfyCo (usa los tuyos si ya tienes Theme)
const _kPrimary = Color(0xFF45BDF1);
const _kSurface = Color(0xFFF6F9FF);

/// ---------- CARD ----------
class PetfyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color; // <— agregado para tu uso en register
  final double radius;

  const PetfyCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? _kSurface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// ---------- BUTTON ----------
class PetfyButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool loading;
  final Widget? leading; // <— agregado para casos como “Mostrar mapa”
  final bool expanded;

  const PetfyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.leading,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          );

    final btn = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      onPressed: loading ? null : onPressed,
      child: child,
    );

    return expanded ? SizedBox(width: double.infinity, child: btn) : btn;
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            color: _kPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// ---------- TEXT FIELD ----------
class PetfyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;          // <— para tu login/register
  final Widget? prefix;                    // <— icono a la izquierda
  final Widget? suffix;                    // <— icono/botón a la derecha (ojo)
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputAction? textInputAction;
  final bool enabled;

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
    this.textInputAction,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

/// ---------- DROPDOWN ----------
class PetfyDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? hint;   // <— aceptamos “hint”
  final String? label;  // <— y también “label” (opcional)

  const PetfyDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        hintText: hint ?? label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.6),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
