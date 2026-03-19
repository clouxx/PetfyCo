/// Validación de imágenes antes de subir a Supabase Storage.
///
/// Verifica:
///   1. Tamaño máximo (por defecto 5 MB)
///   2. Tipo de archivo por magic bytes — no confía en la extensión

const int kMaxImageBytes = 5 * 1024 * 1024; // 5 MB

class ImageValidationResult {
  final bool valid;
  final String? error;
  const ImageValidationResult.ok() : valid = true, error = null;
  const ImageValidationResult.fail(this.error) : valid = false;
}

/// Valida tamaño y tipo de una imagen por sus bytes crudos.
ImageValidationResult validateImageBytes(List<int> bytes, {int maxBytes = kMaxImageBytes}) {
  if (bytes.isEmpty) {
    return const ImageValidationResult.fail('El archivo está vacío.');
  }

  // --- Tamaño ---
  if (bytes.length > maxBytes) {
    final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
    return ImageValidationResult.fail(
      'La imagen pesa ${mb} MB. El máximo permitido es ${maxBytes ~/ (1024 * 1024)} MB.',
    );
  }

  // --- Tipo por magic bytes ---
  if (!_isAllowedImageType(bytes)) {
    return const ImageValidationResult.fail(
      'Formato no soportado. Usa JPEG, PNG, WebP o GIF.',
    );
  }

  return const ImageValidationResult.ok();
}

bool _isAllowedImageType(List<int> b) {
  if (b.length < 12) return false;

  // JPEG: FF D8 FF
  if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true;

  // WebP: RIFF????WEBP
  if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
      b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return true;

  // GIF87a / GIF89a
  if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return true;

  return false;
}
