import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MapPickerDialog extends StatefulWidget {
  final LatLng? initial;
  const MapPickerDialog({super.key, this.initial});

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  late LatLng _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial ?? const LatLng(4.7110, -74.0721); // Bogotá por defecto
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder sin dependencias pesadas (flutter_map/google_maps).
    // Si ya añadiste el mapa real, reemplaza este Container por tu widget de mapa
    // y actualiza _point cuando el usuario toque/arrastre.
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text('Selecciona una ubicación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, size: 64),
                      const SizedBox(height: 8),
                      Text('Mapa de ejemplo (reemplaza por tu widget de mapa)'),
                      const SizedBox(height: 8),
                      Text('Lat: ${_point.latitude.toStringAsFixed(6)}  Lng: ${_point.longitude.toStringAsFixed(6)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _point),
                    child: const Text('Usar este punto'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
