![Firebase Deploy](https://github.com/clouxx/PetfyCo/actions/workflows/firebase-hosting-merge.yml/badge.svg)

# PetfyCo – Flutter Starter

## Configuración
1. Instala Flutter 3.x, Android Studio y (opcional) Xcode para iOS.
2. Crea un proyecto en Supabase y ejecuta `supabase_schema_petfyco.sql`.
3. En Android/VS Code configura variables de entorno en `--dart-define`:
   - SUPABASE_URL
   - SUPABASE_ANON_KEY

## Ejecutar
```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR.supabase.co --dart-define=SUPABASE_ANON_KEY=YOURKEY
```
