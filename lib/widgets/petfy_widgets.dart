import 'package:flutter/material.dart';

class PetfyCard extends StatelessWidget {
  const PetfyCard({super.key, this.color, this.padding, required this.child});

  final Color? color;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// TextField reutilizable con API compatible con lo que ya usas en login/register.
/// - Soporta: label, hint, prefix, suffix, keyboardType, obscureText, validator, onChanged.
/// - Mantiene compatibilidad con nombres antiguos (keyboard / obscure) por si aparecen en tu código.
class PetfyTextField extends StatelessWidget {
  const PetfyTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.obscureText,
    this.validator,
    this.onChanged,
    // compat (por si en algún archivo quedó):
    this.keyboard,
    this.obscure,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool? obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  // Compat aliases (no los uses nuevos, sólo por compatibilidad):
  final TextInputType? keyboard;
  final bool? obscure;

  @override
  Widget build(BuildContext context) {
    final effectiveObscure = obscureText ?? obscure ?? false;
    final effectiveKeyboard = keyboardType ?? keyboard;

    return TextFormField(
      controller: controller,
      keyboardType: effectiveKeyboard,
      obscureText: effectiveObscure,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class PetfyButton extends StatelessWidget {
  const PetfyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text),
      ),
    );
  }
}

/// Dropdown genérico que acepta directamente una lista de valores `items` (p.ej. List<String>)
/// y opcionalmente un `itemBuilder` para mostrar el texto.
/// También soporta `label` para el InputDecoration.
///
/// Ejemplos de uso válidos:
///   PetfyDropdown<String>(items: const ['+57'], value: '+57', onChanged: ...);
///   PetfyDropdown<String>(items: _deptNames, value: _dept, onChanged: ..., label: 'Departamento');
class PetfyDropdown<T> extends StatelessWidget {
  const PetfyDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.itemBuilder,
    this.label,
    this.hint,
  });

  final List<T> items;
  final T? value;
  final void Function(T?)? onChanged;
  final String Function(T value)? itemBuilder;
  final String? label;
  final String? hint;

  List<DropdownMenuItem<T>> _toMenuItems() {
    if (items.isEmpty) return <DropdownMenuItem<T>>[]; // <- sin const (corrige el error)
    return items
        .map(
          (e) => DropdownMenuItem<T>(
            value: e,
            child: Text(itemBuilder?.call(e) ?? e.toString()),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: _toMenuItems(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class PetfyLink extends StatelessWidget {
  const PetfyLink({super.key, required this.text, required this.onTap, this.fontSize});
  final String text;
  final VoidCallback onTap;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
              fontSize: fontSize,
            ),
      ),
    );
  }
}
