import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.navigationShell});
  
  final StatefulNavigationShell navigationShell;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  // Manejo del tap en la barra
  void _onTap(BuildContext context, int index) {
    if (index == 2) {
      // El ítem central es un FAB flotante para la cámara/reporte, 
      // no navega directamente vía shell sino que puede abrir un modal
      // o redirigir a una ruta específica. 
      // Aquí abriremos un modalBottomSheet simple para elegir qué hacer.
      _showCentralModal(context);
    } else {
      // Ajuste de índice porque la posición 2 real está ocupada por el FAB en la UI
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Qué deseas hacer?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.orange,
                  child: Icon(Icons.favorite, color: Colors.white),
                ),
                title: const Text('Dar en adopción'),
                subtitle: const Text('Comparte el perfil de un peludito'),
                onTap: () {
                  Navigator.pop(context); // cerrar sheet
                  context.push('/publish');
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.campaign, color: Colors.white),
                ),
                title: const Text('Reportar mascota perdida'),
                subtitle: const Text('Ayudaremos a emitir la alerta local'),
                onTap: () {
                  Navigator.pop(context); // cerrar sheet
                  context.push('/publish?estado=perdido');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos el índice "visual" 
    // Shell maneja internamente índices 0, 1, 2, 3 correspondientes a las ramas
    // Pero en nuestra UI tenemos 5 íconos (el índice 2 está en blanco/deshabilitado para el FAB).
    int visualIndex = widget.navigationShell.currentIndex;
    if (visualIndex >= 2) {
      visualIndex += 1; // 0, 1, (2 FAB), 3, 4
    }

    return Scaffold(
      body: widget.navigationShell,
      extendBody: true, // Deja que el contenido fluya debajo si tuvieran alpha
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTap(context, 2),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.radar, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          currentIndex: visualIndex,
          onTap: (i) => _onTap(context, i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.purple,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          elevation: 20,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_searching),
              activeIcon: Icon(Icons.my_location),
              label: 'Perdidos',
            ),
            BottomNavigationBarItem(
              icon: Icon(null), // Espacio para el FAB flotante
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pets_outlined),
              activeIcon: Icon(Icons.pets),
              label: 'Adoptar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
