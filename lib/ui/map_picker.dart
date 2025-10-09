// lib/ui/map_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPicker {
  /// Abre un modal con el mapa y devuelve la lat/lng seleccionada.
  static Future<LatLng?> show(
    BuildContext context, {
    LatLng? initial,
    String title = 'Selecciona tu ubicación',
  }) {
    return showDialog<LatLng?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MapPickerDialog(
        initial: initial,
        title: title,
      ),
    );
  }
}

class _MapPickerDialog extends StatefulWidget {
  final LatLng? initial;
  final String title;

  const _MapPickerDialog({
    super.key,
    this.initial,
    required this.title,
  });

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late LatLng _center;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? const LatLng(6.2518, -75.5636); // Medellín por defecto
  }

  void _onMapTap(TapPosition _, LatLng latlng) {
    setState(() => _center = latlng);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 420,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14,
              onTap: _onMapTap,
            ),
            // 👇 OJO: NO usar `const` aquí
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.petfyco',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, size: 40, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_center),
          child: const Text('Usar ubicación'),
        ),
      ],
    );
  }
}
