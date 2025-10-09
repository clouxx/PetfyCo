import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPicker extends StatefulWidget {
  const MapPicker({super.key, this.initial});
  final LatLng? initial;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late LatLng _center;
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? const LatLng(6.2518, -75.5636); // Medellín por defecto
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona tu ubicación')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onTap: (tapPos, point) => setState(() => _picked = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.petfyco.app',
              ),
              if (_picked != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _picked!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, size: 40),
                  ),
                ]),
            ],
          ),
          Positioned(
            left: 16, right: 16, bottom: 16,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: Text(
                _picked == null
                    ? 'Elegir este punto'
                    : 'Usar ${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
              ),
              onPressed: () => Navigator.pop(context, _picked),
            ),
          ),
        ],
      ),
    );
  }
}
