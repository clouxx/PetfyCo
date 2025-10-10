import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Si ya tienes un widget de mapa real, impórtalo y úsalo aquí.
/// Este diálogo devuelve un LatLng con Navigator.pop(ctx, point).
class MapPickerDialog extends StatefulWidget {
  final LatLng? initial;

  const MapPickerDialog({super.key, this.initial});

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial ?? const LatLng(4.5709, -74.2973); // Colombia centro aprox
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar ubicación'),
      content: SizedBox(
        width: 520,
        height: 360,
        // Placeholder. Sustituye por tu mapa (flutter_map / google_maps_flutter_web).
        child: GestureDetector(
          onTapDown: (d) {
            // Simulación de elección (no es preciso, pero permite continuar flujo).
            setState(() {
              _picked = LatLng((_picked?.latitude ?? 4.57) + 0.0001, (_picked?.longitude ?? -74.29) + 0.0001);
            });
          },
          child: Container(
            alignment: Alignment.center,
            color: Colors.grey.shade200,
            child: const Text('Mapa aquí (placeholder) - toca para simular'),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _picked),
          child: const Text('Usar ubicación'),
        ),
      ],
    );
  }
}
