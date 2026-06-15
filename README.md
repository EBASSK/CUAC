# CUAC - Lab Instrument Identifier

Aplicación Flutter completa para identificar instrumentos de laboratorio usando inteligencia artificial en el dispositivo.

---

## Estado actual del proyecto

Este repositorio ya no es un proyecto Flutter vacío. Está transformado en una app funcional con:
- `assets/models/instrument_model.tflite` como modelo TFLite integrado.
- `assets/models/labels.txt` con las clases de instrumentos.
- `lib/screens/splash_screen.dart` diseñado con animación, logo y Material Design 3.
- `lib/services/tflite_service.dart` para cargar el modelo y obtener predicciones.
- `setup_ml.py` adaptado para copiar el modelo y las etiquetas dentro de `assets/models/`.
- `train_model_v2.py` para entrenar y exportar el modelo desde dataset.
- Integración de cámara, historial local y navegación con GoRouter.

## Historia de cambios recientes

1. Rediseño de splash screen con logo, animación y fondo degradado oscuro.
2. Integración del modelo TFLite y corrección de rutas de etiquetas.
3. Ajuste del pipeline para que el app cargue `assets/models/labels.txt` correctamente.
4. Inclusión de iconos e imágenes de branding para la app.
5. Validación del entrenamiento automático y exportación del modelo.
6. Actualización de la documentación para reflejar el estado real del proyecto.

## Descripción del proyecto

CUAC es una aplicación móvil que ayuda a identificar instrumentos de laboratorio mediante la cámara del dispositivo y un modelo de aprendizaje automático local.

La app es ideal para estudiantes, docentes y técnicos que quieran reconocer rápidamente equipos como:
- Microscopios
- Probetas
- Matraces
- Pipetas
- Vasos de precipitado
- Buretas
- Embudos
- Pinzas
- Gradillas
- Crisoles

## ¿Qué hace la aplicación?

- Inicializa un modelo TFLite al arrancar.
- Pide permisos de cámara y prepara la captura.
- Captura imágenes mediante la cámara nativa.
- Procesa la imagen y la envía al modelo ML.
- Muestra resultados de clasificación con porcentajes de confianza.
- Guarda el historial de escaneos en SQLite.
- Permite revisar y gestionar registros guardados.

## Arquitectura del proyecto

### Carpetas clave

- `lib/config/` — configuración global, rutas y constantes.
- `lib/services/` — servicios para ML, cámara, base de datos e imagen.
- `lib/providers/` — lógica de estado con Riverpod.
- `lib/screens/` — pantallas del usuario.
- `lib/models/` — entidades de datos.
- `lib/widgets/` — componentes de UI reutilizables.
- `assets/models/` — modelo y etiquetas.
- `assets/imagenes/` — logo, iconos y otros recursos.

### Principales tecnologías

- Flutter 3.x + Dart
- `flutter_riverpod` / `riverpod`
- `go_router`
- `camera`
- `permission_handler`
- `tflite_flutter`
- `sqflite`
- `flutter_image_compress`
- `image`

## Flujo de funcionamiento

1. `SplashScreen` carga el modelo y verifica permisos.
2. El usuario abre la cámara y captura una imagen.
3. La app procesa la imagen para adaptarla al modelo.
4. `TFLiteService` ejecuta la inferencia.
5. Se muestra la predicción principal y posibles alternativas.
6. El usuario puede guardar el resultado en el historial.
7. El historial puede filtrarse y revisarse en detalle.

## Modelos y assets actuales

### Archivos integrados

- `assets/models/instrument_model.tflite`
- `assets/models/labels.txt`
- `assets/models/class_mapping.json`

### Clases soportadas

1. Microscopio
2. Probeta
3. Matraces
4. Pipetas
5. Vasos de precipitado
6. Buretas
7. Embudos
8. Pinzas
9. Gradillas
10. Crisoles

## Scripts de entrenamiento

### `train_model_v2.py`

Entrena un modelo mediante TensorFlow/Keras usando el dataset disponible en `dataset/`.

### `setup_ml.py`

Copia el resultado del entrenamiento al proyecto Flutter:
- `output/instrument_model.tflite` → `assets/models/instrument_model.tflite`
- `output/labels.txt` → `assets/models/labels.txt`

## Cómo entrenar y actualizar el modelo

```bash
pip install -r requirements_ml.txt
python train_model_v2.py
python setup_ml.py
flutter clean
flutter pub get
flutter run
```

## Instalación y ejecución

### Requisitos

- Flutter SDK >= 3.0.0
- Dispositivo Android/iOS o emulador
- Python 3.9+ para el entrenamiento opcional

### Pasos

```bash
git clone https://github.com/tu-usuario/lab-instrument-identifier.git
cd lab_instrument_identifier
flutter pub get
flutter run
```

### Build

```bash
flutter build apk --release
flutter build appbundle --release
```

## Problemas comunes

### Modelo no carga

- Verifica que `assets/models/instrument_model.tflite` exista.
- Verifica que `assets/models/labels.txt` exista.
- Asegúrate de que `pubspec.yaml` incluya `assets/models/`.

### Error de permisos

- Permite la cámara en el dispositivo.
- Revisa `AndroidManifest.xml` para el permiso de cámara.

### Error de inferencia

- Revisa rutas en `lib/config/app_config.dart`.
- Asegúrate de que el archivo `labels.txt` está en `assets/models/`.

## Contribuir

1. Haz fork del proyecto.
2. Crea una rama nueva.
3. Realiza tus cambios.
4. Envía un pull request.

## Licencia

MIT License.

## Autor

**Sebastian caceres osuna "EBASSK"** - sebas25caceres@gmail.com
