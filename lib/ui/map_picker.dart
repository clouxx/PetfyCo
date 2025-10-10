import 'package:flutter/material.dart';

/// Diálogo simple de selección de coordenadas (placeholder).
/// Devuelve un Map con {'lat': double, 'lng': double} al cerrar con "Usar".
class MapPickerDialog extends StatefulWidget {
  final dynamic initial; // admite LatLng propio o {'lat':..,'lng':..}
  const MapPickerDialog({super.key, this.initial});

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  @override
  void initState() {
    super.initState();
    double? lat;
    double? lng;

    // Intento flexible de leer valores iniciales
    final i = widget.initial;
    try {
      if (i != null) {
        if (i is Map && i['lat'] != null && i['lng'] != null) {
          lat = (i['lat'] as num).toDouble();
          lng = (i['lng'] as num).toDouble();
        } else {
          // Campos comunes: lat/lng o latitude/longitude
          final latField = (i as dynamic?)?.lat ?? (i as dynamic?)?.latitude;
          final lngField = (i as dynamic?)?.lng ?? (i as dynamic?)?.longitude;
          lat = (latField as num?)?.toDouble();
          lng = (lngField as num?)?.toDouble();
        }
      }
    } catch (_) {}

    _latCtrl = TextEditingController(text: lat?.toStringAsFixed(6) ?? '');
    _lngCtrl = TextEditingController(text: lng?.toStringAsFixed(6) ?? '');
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecciona ubicación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Versión temporal: ingresa latitud y longitud.'),
          const SizedBox(height: 12),
          TextField(
            controller: _latCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: 'Latitud',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lngCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: 'Longitud',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final lat = double.tryParse(_latCtrl.text.trim());
            final lng = double.tryParse(_lngCtrl.text.trim());
            if (lat == null || lng == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lat/Lng inválidos')),
              );
              return;
            }
            // Devuelve un map simple para no chocar tipos
            Navigator.of(context).pop({'lat': lat, 'lng': lng});
          },
          child: const Text('Usar'),
        ),
      ],
    );
  }
}
