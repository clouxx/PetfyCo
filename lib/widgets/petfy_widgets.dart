import 'package:flutter/material.dart';

/// ====== Constantes de estilo rápidas ======
const _kRadius = 16.0;
const _kGap = SizedBox(height: 12);
const _kBorderColor = Color(0xFFE6E9F2);

/// Tarjeta contenedora (permite color opcional)
class PetfyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const PetfyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kBorderColor.withOpacity(.7)),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(.04),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// TextField estilizado
class PetfyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard; // <- solicitado
  final Widget? prefix;          // <- solicitado
  final Widget? suffix;          // <- solicitado
  final String? Function(String?)? validator; // <- solicitado
  final void Function(String)? onChanged;     // <- solicitado
  final TextInputAction? textInputAction;

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
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: _kBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

/// Botón principal
class PetfyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading; // <- compatible con tus llamadas previas
  final Widget? leading; // <- para ícono opcional a la izquierda

  const PetfyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kRadius)),
        ),
        child: loading
            ? const SizedBox(
                height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Text(text),
                ],
              ),
      ),
    );
  }
}

/// Enlace
class PetfyLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const PetfyLink({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Dropdown estilizado genérico (con hint y label opcionales)
class PetfyDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;   // <- solicitado
  final String? label;  // <- por si lo usas en otros lados
  final String? Function(T?)? validator;

  const PetfyDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.label,
    this.validator,
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
        fillColor: const Color(0xFFF8FAFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: _kBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
