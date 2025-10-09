import 'package:flutter/material.dart';

/// Tarjeta con padding y bordes redondeados
class PetfyCard extends StatelessWidget {
  final Widget child;
  const PetfyCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// TextField estilizado de PetfyCo
class PetfyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;

  /// NUEVO: acepta ambas variantes
  final Widget? prefix;              // usa un widget como ícono a la izquierda
  final IconData? prefixIcon;        // o solo el IconData
  final Widget? suffix;              // botón/ícono a la derecha

  const PetfyTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboard,
    this.prefix,
    this.prefixIcon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? resolvedPrefix =
        prefix ?? (prefixIcon != null ? Icon(prefixIcon) : null);

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: resolvedPrefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: .6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Botón principal PetfyCo
class PetfyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  /// Conservamos `loading` y añadimos alias `isLoading` para compatibilidad.
  final bool loading;

  const PetfyButton({
    super.key,
    required this.text,
    required this.onPressed,
    bool? isLoading,
    bool loading = false,
  }) : loading = isLoading ?? loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(text),
      ),
    );
  }
}
