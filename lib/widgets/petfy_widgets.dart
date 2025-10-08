import 'package:flutter/material.dart';
import 'package:petfyco/theme/app_theme.dart';

class PetfyAuthBackground extends StatelessWidget {
  final Widget child;
  const PetfyAuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue.withValues(alpha: .10),
            AppColors.orange.withValues(alpha: .08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

class PetfyAuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const PetfyAuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Image.asset('assets/logo/petfyco_logo_full.png', height: 68),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class PetfyCard extends StatelessWidget {
  final Widget child;
  const PetfyCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class PetfyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? suffix;
  const PetfyTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboard,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: hint,
        suffixIcon: suffix,
      ),
    );
  }
}

class PetfyButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool loading;
  const PetfyButton({super.key, required this.text, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: Text(loading ? 'Procesando...' : text),
    );
  }
}
