import 'package:flutter/material.dart';

class PetfyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const PetfyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// TextField flexible (acepta las props que usas en login/register)
class PetfyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType keyboard;
  final Widget? prefix;                // <-- para Icon widget
  final IconData? prefixIcon;          // <-- para IconData directo
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  const PetfyTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboard = TextInputType.text,
    this.prefix,
    this.prefixIcon,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    );

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix ?? (prefixIcon != null ? Icon(prefixIcon) : null),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }
}

/// Campo de contraseña con botón de mostrar/ocultar
class PetfyPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  const PetfyPasswordField({
    super.key,
    required this.controller,
    this.hint = 'Contraseña',
    this.validator,
    this.onChanged,
  });

  @override
  State<PetfyPasswordField> createState() => _PetfyPasswordFieldState();
}

class _PetfyPasswordFieldState extends State<PetfyPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return PetfyTextField(
      controller: widget.controller,
      hint: widget.hint,
      obscure: _obscure,
      prefixIcon: Icons.lock_outline,
      validator: widget.validator,
      onChanged: widget.onChanged,
    )._withSuffix(
      IconButton(
        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

// Pequeño helper para agregar suffix sin duplicar decoración
extension _SuffixExt on Widget {
  Widget _withSuffix(Widget suffix) {
    if (this is! TextFormField) return this;
    final tf = this as TextFormField;
    final dec = tf.decoration ?? const InputDecoration();
    return TextFormField(
      controller: tf.controller,
      obscureText: tf.obscureText,
      keyboardType: tf.keyboardType,
      validator: tf.validator,
      onChanged: tf.onChanged,
      decoration: dec.copyWith(
        suffixIcon: suffix,
      ),
    );
  }
}

class PetfyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;      // nombre original
  final bool? isLoading;   // alias que usas en login/register

  const PetfyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLoading = isLoading ?? loading;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: effectiveLoading ? null : onPressed,
        child: effectiveLoading
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text),
      ),
    );
  }
}

/// Enlace estilo texto
class PetfyLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const PetfyLink({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(color: color, decoration: TextDecoration.underline),
      ),
    );
  }
}

/// Dropdown genérico que usas en registro
class PetfyDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  const PetfyDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    );

    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
