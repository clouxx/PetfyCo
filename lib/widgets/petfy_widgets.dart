import 'dart:async';
import 'package:flutter/material.dart';

/// Tarjeta simple con sombra y radio
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
        color: color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// TextFormField con API compatible con tus pantallas (label, prefix, suffix, obscure, keyboardType)
class PetfyTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefix; // icono a la izquierda
  final Widget? suffix; // icono/botón a la derecha
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final bool enabled;

  const PetfyTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.prefix,
    this.suffix,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText, // 👈 úsalo aquí
      validator: validator,
      onChanged: onChanged,
      maxLines: obscure ? 1 : maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

/// Botón que acepta callbacks async y muestra loading
class PetfyButton extends StatelessWidget {
  final String text;
  final FutureOr<void> Function()? onPressed; // acepta async
  final bool loading;
  final Widget? leading; // icono opcional a la izquierda

  const PetfyButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (loading || onPressed == null)
            ? null
            : () async {
                await onPressed!();
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
            ],
            if (!loading && leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            Text(text),
          ],
        ),
      ),
    );
  }
}

/// Link de texto simple
class PetfyLink extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const PetfyLink({super.key, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onTap, child: Text(text));
  }
}

/// Dropdown genérico que recibe una lista de valores `items` (List<T>)
/// y los convierte internamente en `DropdownMenuItem<T>`.
class PetfyDropdown<T> extends StatelessWidget {
  final List<T> items;
  final T? value;
  final void Function(T?)? onChanged;
  final String Function(T)? itemBuilder; // cómo mostrar cada item
  final String? hint;
  final String? label;

  const PetfyDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.itemBuilder,
    this.hint,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final menuItems = items
        .map(
          (e) => DropdownMenuItem<T>(
            value: e,
            child: Text(itemBuilder != null ? itemBuilder!(e) : '$e'),
          ),
        )
        .toList();

    return DropdownButtonFormField<T>(
      value: value,
      items: menuItems.isEmpty ? <DropdownMenuItem<T>>[] : menuItems, // ❗ sin const con genérico T
      onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
