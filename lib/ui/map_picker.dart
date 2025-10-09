import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPickerDialog extends StatefulWidget {
  final LatLng? initial;
  const MapPickerDialog({super.key, this.initial});

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  late final MapController _map;
  LatLng _point = const LatLng(6.2518, -75.5636); // Medellín por defecto

  @override
  void initState() {
    super.initState();
    _map = MapController();
    if (widget.initial != null) _point = widget.initial!;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 560),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text('Selecciona tu ubicación en el mapa',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _point,
                  initialZoom: 13,
                  onTap: (tapPos, p) => setState(() => _point = p),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'petfyco',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: _point,
                      child: const Icon(Icons.location_on, size: 36, color: Colors.red),
                    ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Text(
                    'Lat: ${_point.latitude.toStringAsFixed(5)}  '
                    'Lng: ${_point.longitude.toStringAsFixed(5)}',
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _point),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
