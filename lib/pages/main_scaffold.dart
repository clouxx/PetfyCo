import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/heroe_de_patitas_modal.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  // Shell branches: 0=home, 1=lost, 2=adopt, 3=tienda, 4=profile
  // Visual nav: 0=Inicio, 1=Perdidos, [2=FAB], 3=Adoptar, 4=Tienda, 5=Perfil
  // But we keep 5 visual items to match the reference app layout:
  //   Inicio | Perdidos | [FAB Radar] | Adoptar | Perfil
  // "Tienda" is accessed via the FAB modal or the Home banners.

  void _onTap(BuildContext context, int index) {
    if (index == 2) {
      _showCentralModal(context);
    } else {
      final targetIndex = index > 2 ? index - 1 : index;
      widget.navigationShell.goBranch(
        targetIndex,
        initialLocation: targetIndex == widget.navigationShell.currentIndex,
      );
    }
  }

  void _showCentralModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 20),
              Text('¿Qué deseas hacer?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // --- Dar en adopción
              _ModalTile(
                color: AppColors.orange,
                icon: Icons.favorite,
                title: 'Dar en adopción',
                subtitle: 'Comparte el perfil de un peludito',
                onTap: () { Navigator.pop(context); context.push('/publish'); },
              ),
              const SizedBox(height: 8),

              // --- Reportar perdida
              _ModalTile(
                color: Colors.red,
                icon: Icons.campaign,
                title: 'Reportar mascota perdida',
                subtitle: 'Ayudaremos a emitir la alerta local',
                onTap: () { Navigator.pop(context); context.push('/publish?estado=perdido'); },
              ),
              const SizedBox(height: 8),

              // --- Tienda
              _ModalTile(
                color: AppColors.purple,
                icon: Icons.shopping_bag_outlined,
                title: 'Visitar la Tienda',
                subtitle: 'Nutrición y Limpieza a Domicilio',
                onTap: () { Navigator.pop(context); context.push('/tienda'); },
              ),
              const SizedBox(height: 8),

              // --- Héroe de Patitas
              _ModalTile(
                color: AppColors.pink,
                icon: Icons.volunteer_activism,
                title: 'Héroe de Patitas ❤️',
                subtitle: 'Apoya la causa por solo \$1/mes',
                onTap: () { Navigator.pop(context); HeroeDePatitasModal.show(context); },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int visualIndex = widget.navigationShell.currentIndex;
    if (visualIndex >= 2) visualIndex += 1;

    return Scaffold(
      body: widget.navigationShell,
      extendBody: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTap(context, 2),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.radar, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: AppColors.purpleGlass,
          backgroundColor: Colors.white.withOpacity(0.9),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold, fontSize: 11);
            }
            return TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 11);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.purple);
            }
            return IconThemeData(color: Colors.grey.shade500);
          }),
        ),
        child: NavigationBar(
          selectedIndex: visualIndex,
          onDestinationSelected: (i) => _onTap(context, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_searching),
              selectedIcon: Icon(Icons.my_location),
              label: 'Perdidos',
            ),
            NavigationDestination(
              icon: SizedBox.shrink(), // Empty placeholder for FAB
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.pets_outlined),
              selectedIcon: Icon(Icons.pets),
              label: 'Adoptar',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalTile extends StatelessWidget {
  const _ModalTile({required this.color, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
