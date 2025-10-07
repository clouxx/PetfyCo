import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PetfyHeader extends StatelessWidget {
  final String title;
  final String asset; // imagen de cabecera
  const PetfyHeader({super.key, required this.title, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 96,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(.12),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            Positioned(
              top: -10,
              left: 16,
              child: Image.asset(asset, height: 110),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
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
    this.obscure = false,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
      ),
    );
  }
}

class PetfyPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const PetfyPrimaryButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onTap, child: Text(label)),
    );
  }
}

class PetfyGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const PetfyGhostButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: AppColors.navy)),
      ),
    );
  }
}
