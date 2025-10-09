import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Muestra un mapa (OpenStreetMap) para elegir una coordenada.
/// Devuelve un LatLng al cerrar con "Usar este punto".
class MapPicker extends StatefulWidget {
  final LatLng? initial;
  const MapPicker({super.key, this.initial});

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? const LatLng(6.2518, -75.5636); // Medellín por defecto
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 620),
        child: Column(
          children: [
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              width: double.infinity,
              child: Text('Selecciona tu ubicación',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 13,
                      onTap: (tapPos, latlng) => setState(() => _center = latlng),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.petfyco.app',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: _center,
                          width: 44,
                          height: 44,
                          child: const Icon(Icons.location_pin, size: 44, color: Colors.red),
                        ),
                      ]),
                    ],
                  ),
                  // Crosshair opcional
                  const IgnorePointer(
                    child: Center(
                      child: Icon(Icons.add_location_alt_outlined, size: 40, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop<LatLng>(null),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop<LatLng>(_center),
                      child: Text('Usar este punto (${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)})'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
