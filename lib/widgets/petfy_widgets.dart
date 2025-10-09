import 'package:flutter/material.dart';

/// Colores base (usa lo que tengas en tu Theme si prefieres)
const _kPrimary = Color(0xFF3BB9FD);
const _kCard = Color(0xFFF6F2FF);

/// Campo de texto reutilizable
class PetfyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? prefix;            // <- ícono a la izquierda
  final Widget? suffix;            // <- ícono a la derecha
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
        fillColor: _kCard.withOpacity(0.35),
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

/// Botón primario
class PetfyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  const PetfyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
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
        child: loading
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Dropdown estilizado (genérico)
class PetfyDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String hint;
  final String? Function(T?)? validator;

  const PetfyDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
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
        hintText: hint,
        filled: true,
        fillColor: _kCard.withOpacity(0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(.15)),
        ),
      ),
    );
  }
}

/// Link de texto clickeable
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
