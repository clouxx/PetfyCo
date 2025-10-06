import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PetfyHome extends StatelessWidget {
  const PetfyHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logo/petfyco_logo_full.png', height: 40),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navegar a subir mascota
        },
        icon: const Icon(Icons.add),
        label: const Text('Subir mascota'),
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _HeaderBanner(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(6, (i) => _PetCard(index: i)),
          ),
        ],
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.blue.withOpacity(.18),
          AppColors.orange.withOpacity(.14)
        ]),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Image.asset('assets/logo/petfyco_icon.png', height: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Encuentra y publica mascotas en Colombia',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final int index;
  const _PetCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {/* detalle */},
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: AppColors.blue.withOpacity(.15),
                      child: const Icon(Icons.pets, size: 48, color: AppColors.navy),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Michi de prueba',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: AppColors.pink),
                    const SizedBox(width: 4),
                    Text('Bogotá • publicado',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(label: const Text('Gato')),
                    const SizedBox(width: 6),
                    Chip(
                      label: const Text('Adopción'),
                      backgroundColor: AppColors.orange.withOpacity(.15),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
