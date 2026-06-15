# CUAC - Lab Instrument Identifier

Este directorio contiene el código fuente de la aplicación Flutter que identifica instrumentos de laboratorio mediante un modelo de TensorFlow Lite.

## ¿Qué incluye?

- UI Flutter con Material Design 3
- Pantalla de splash animada
- Captura de cámara y procesamiento de imagen
- Inferencia en dispositivo con `tflite_flutter`
- Historial de escaneos guardado en SQLite

## Ubicaciones clave

- `lib/screens/` — pantallas de la app
- `lib/services/` — servicios de ML, cámara y base de datos
- `lib/providers/` — gestión de estado con Riverpod
- `lib/config/` — configuración global y rutas
- `assets/models/` — modelo TFLite y etiquetas

## Uso

1. Desde la raíz del proyecto, ejecuta:
   ```bash
   flutter pub get
   flutter run
   ```

2. Para actualizar el modelo ML, usa los scripts en la raíz:
   ```bash
   python train_model_v2.py
   python setup_ml.py
   ```
