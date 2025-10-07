import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PetfyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const PetfyButton({super.key, required this.label, this.onPressed, this.loading=false});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class PetfyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  const PetfyTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure=false,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(hintText: hint),
    );
  }
}

/// Fondo con suave degradado y huella translúcida
class PetfyAuthBackground extends StatelessWidget {
  final Widget child;
  const PetfyAuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.9, -1),
          end: Alignment(0.8, 1),
          colors: [Color(0xFFE9F7FF), Color(0xFFFFFFFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -20,
            child: Opacity(
              opacity: .09,
              child: Image.asset('assets/logo/petfyco_icon.png', width: 180),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Contenedor tarjeta para formularios
class PetfyCard extends StatelessWidget {
  final Widget child;
  const PetfyCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

/// Encabezado con logo + título
class PetfyAuthHeader extends StatelessWidget {
  final String title;
  final String? caption;
  const PetfyAuthHeader({super.key, required this.title, this.caption});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        Image.asset('assets/logo/petfyco_logo_full.png', height: 74),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.navy)),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(caption!, style: const TextStyle(color: Colors.black54)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
