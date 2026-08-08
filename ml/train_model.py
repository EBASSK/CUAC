"""Entrena, evalúa y exporta el clasificador local de instrumentos de CUAC.

El flujo consume el manifiesto reproducible generado por ``dataset.py``, aplica
aprendizaje por transferencia con MobileNetV2 y produce los archivos que después
se publican en la aplicación Flutter.
"""

import json
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import (
    Dense,
    Dropout,
    GlobalAveragePooling2D,
    Input,
    RandomContrast,
    RandomFlip,
    RandomRotation,
    RandomTranslation,
    RandomZoom,
    Rescaling,
)
from tensorflow.keras.models import Model
from tensorflow.keras.optimizers import Adam
from sklearn.metrics import classification_report, confusion_matrix
from pathlib import Path
import matplotlib.pyplot as plt
from datetime import datetime
from PIL import Image, ImageOps

# ========== CONFIGURACIÓN ==========

# Tamaño y normalización deben coincidir con el contrato de entrada que usa la
# aplicación al ejecutar el modelo TFLite.
IMG_SIZE = 224
BATCH_SIZE = 16
EPOCHS = 50
LEARNING_RATE = 0.001
RANDOM_STATE = 42

# Solo se intentan decodificar formatos compatibles con Pillow en este entorno.
SUPPORTED_IMAGE_EXTENSIONS = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.avif',
}

# Las rutas absolutas evitan que los artefactos dependan del directorio actual.
ML_ROOT = Path(__file__).resolve().parent
DATASET_PATH = ML_ROOT / 'data' / 'instruments'
OUTPUT_DIR = ML_ROOT / 'artifacts'
SPLIT_MANIFEST_PATH = OUTPUT_DIR / 'split_manifest.json'
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ========== REGISTRO DE EJECUCIÓN ==========


class Logger:
    """Registra mensajes en consola y conserva una copia para el informe final."""

    def __init__(self):
        """Inicializa el búfer de mensajes de esta ejecución."""
        self.logs = []

    def info(self, msg):
        """Registra información general del avance."""
        print(f"[INFO] {msg}")
        self.logs.append(f"[INFO] {msg}")

    def warn(self, msg):
        """Registra una condición recuperable que requiere revisión."""
        print(f"[WARN] {msg}")
        self.logs.append(f"[WARN] {msg}")

    def error(self, msg):
        """Registra un fallo que impide completar una parte del flujo."""
        print(f"[ERROR] {msg}")
        self.logs.append(f"[ERROR] {msg}")

    def success(self, msg):
        """Registra que una etapa terminó correctamente."""
        print(f"[SUCCESS] {msg}")
        self.logs.append(f"[SUCCESS] {msg}")

    def save(self, filepath):
        """Guarda todos los mensajes acumulados como texto UTF-8."""
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(self.logs))


# Una sola instancia conserva la cronología completa de todas las fases.
logger = Logger()

# ========== CARGA DE DATOS ==========

class DatasetLoader:
    """Carga imágenes y respeta la división fijada en el manifiesto auditado."""

    def __init__(self, data_path, img_size=224):
        """Configura la raíz del dataset y el tamaño de entrada del modelo."""
        self.dataset_path = Path(data_path)
        self.img_size = img_size
        self.classes = []
        self.class_to_idx = {}
        self.idx_to_class = {}

    def load_dataset(self):
        """Carga imágenes normalizadas, etiquetas numéricas y división asignada.

        Cada archivo debe aparecer en ``split_manifest.json`` con la misma clase
        que indica su carpeta. Así el entrenamiento nunca vuelve a dividir los
        datos de manera independiente ni mezcla copias exactas entre conjuntos.
        """
        logger.info("Cargando dataset...")

        # Comprobar que la ruta del dataset existe
        if not self.dataset_path.exists():
            logger.error(f"Ruta de dataset no encontrada: {self.dataset_path}")
            return None, None, None
        if not SPLIT_MANIFEST_PATH.is_file():
            logger.error(
                'No existe split_manifest.json. Ejecuta primero '
                'python ml/dataset.py audit'
            )
            return None, None, None

        # El manifiesto es la fuente única para train, validation y test.
        manifest = json.loads(SPLIT_MANIFEST_PATH.read_text(encoding='utf-8'))
        manifest_by_path = {item['path']: item for item in manifest}

        images = []
        labels = []
        splits = []

        class_dirs = sorted(
            path for path in self.dataset_path.iterdir() if path.is_dir()
        )

        # Cada carpeta válida representa una clase y recibe un índice estable.
        for idx, class_dir in enumerate(class_dirs):

            class_name = class_dir.name
            self.classes.append(class_name)
            self.class_to_idx[class_name] = idx
            self.idx_to_class[idx] = class_name

            logger.info(f"  [{idx}] Cargando: {class_name}")

            # Cargar únicamente imágenes admitidas de la clase actual.
            image_count = 0
            image_files = sorted(
                path for path in class_dir.iterdir()
                if path.is_file()
                and path.suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS
            )
            for img_file in image_files:
                try:
                    manifest_path = img_file.relative_to(ML_ROOT).as_posix()
                    manifest_item = manifest_by_path.get(manifest_path)
                    if manifest_item is None:
                        raise ValueError(
                            f'{manifest_path} no está en split_manifest.json'
                        )
                    if manifest_item['class'] != class_name:
                        raise ValueError(
                            f'Clase inconsistente para {manifest_path}: '
                            f"{manifest_item['class']} != {class_name}"
                        )

                    with Image.open(img_file) as source_image:
                        # Se aplica la orientación EXIF antes de redimensionar y
                        # se normalizan los píxeles al intervalo [0, 1].
                        rgb_image = ImageOps.exif_transpose(
                            source_image.convert('RGB')
                        )
                        resized_image = rgb_image.resize(
                            (self.img_size, self.img_size),
                            Image.Resampling.LANCZOS,
                        )
                        img = np.asarray(
                            resized_image,
                            dtype=np.float32,
                        ) / 255.0

                    images.append(img)
                    labels.append(idx)
                    splits.append(manifest_item['split'])
                    image_count += 1
                except Exception as e:
                    logger.warn(f"Error cargando {img_file}: {e}")

            logger.info(f"      → {image_count} imágenes cargadas")

        X = np.array(images)
        y = np.array(labels)
        split_names = np.array(splits)

        logger.success(f"Dataset cargado: {len(X)} imágenes, {len(self.classes)} clases")

        if len(X) == 0:
            logger.error("No se cargaron imágenes. Verifica el dataset.")
            return None, None, None

        return X, y, split_names

    def validate_data(self, X, y):
        """Comprueba dimensiones y exige suficientes muestras para cada clase."""
        logger.info("\n" + "=" * 60)
        logger.info("VALIDACIÓN DEL DATASET")
        logger.info("=" * 60)

        logger.info(f"Forma de X: {X.shape}")
        logger.info(f"Forma de y: {y.shape}")
        logger.info(f"Clases: {len(self.classes)}")
        logger.info(f"Clases: {self.classes}")

        # El conteo por clase detecta desbalances críticos o carpetas incompletas.
        unique, counts = np.unique(y, return_counts=True)
        for class_idx, count in zip(unique, counts):
            logger.info(f"  {self.idx_to_class[class_idx]}: {count} muestras")
            if count < 10:
                raise ValueError(
                    f"La clase {self.idx_to_class[class_idx]} necesita "
                    "al menos 10 imágenes válidas"
                )

        logger.info("=" * 60)

# ========== MODELO ==========

class InstrumentModel:
    """Encapsula la construcción, entrenamiento y evaluación del clasificador."""

    def __init__(self, num_classes, input_shape=(IMG_SIZE, IMG_SIZE, 3)):
        """Conserva la cantidad de clases y la forma esperada de cada imagen."""
        self.num_classes = num_classes
        self.input_shape = input_shape
        self.model = None
        self.history = None

    def build(self):
        """Construye una cabeza de clasificación sobre MobileNetV2 preentrenada."""
        logger.info("\nConstruyendo modelo MobileNetV2...")

        # Base convolucional preentrenada sin su clasificador original.
        base_model = MobileNetV2(
            input_shape=self.input_shape,
            include_top=False,
            weights='imagenet'
        )

        # La referencia se reutiliza en ajuste fino; al principio sus pesos
        # permanecen congelados para entrenar solo la nueva cabeza.
        self.base_model = base_model
        self.base_model.trainable = False

        # El aumento de datos se integra al modelo y solo se activa al entrenar.
        augmentation = keras.Sequential(
            [
                RandomFlip('horizontal'),
                RandomRotation(0.08),
                RandomTranslation(0.08, 0.08),
                RandomZoom(0.1),
                RandomContrast(0.15),
            ],
            name='data_augmentation',
        )

        # La app entrega píxeles en [0, 1]. La normalización específica de
        # MobileNetV2 queda dentro del modelo exportado.
        inputs = Input(shape=self.input_shape)
        x = augmentation(inputs)
        x = Rescaling(scale=2.0, offset=-1.0, name='mobilenet_normalization')(x)
        x = base_model(x, training=False)
        x = GlobalAveragePooling2D()(x)
        x = Dropout(0.2)(x)
        x = Dense(256, activation='relu')(x)
        x = Dropout(0.2)(x)
        outputs = Dense(self.num_classes, activation='softmax')(x)

        self.model = Model(inputs, outputs)

        # Las etiquetas son índices enteros, por eso se usa la variante sparse.
        self.model.compile(
            optimizer=Adam(learning_rate=LEARNING_RATE),
            loss='sparse_categorical_crossentropy',
            metrics=[
                'accuracy']
        )

        logger.success("Modelo construido")
        self.model.summary()

    def train(self, X_train, y_train, X_val, y_val):
        """Entrena la cabeza y conserva automáticamente el mejor checkpoint."""
        logger.info("\n" + "=" * 60)
        logger.info("ENTRENAMIENTO")
        logger.info("=" * 60)

        # Estos controles frenan el sobreajuste, reducen la tasa de aprendizaje
        # cuando la validación se estanca y guardan el mejor modelo observado.
        callbacks = [
            keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=10,
                restore_best_weights=True,
                verbose=1
            ),
            keras.callbacks.ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=5,
                min_lr=1e-7,
                verbose=1
            ),
            keras.callbacks.ModelCheckpoint(
                OUTPUT_DIR / 'best_model.keras',
                monitor='val_accuracy',
                save_best_only=True,
                verbose=1
            ),
        ]

        # Entrenamiento inicial con la base todavía congelada.
        logger.info(f"Entrenando por {EPOCHS} épocas...")

        self.history = self.model.fit(
            X_train, y_train,
            validation_data=(X_val, y_val),
            epochs=EPOCHS,
            batch_size=BATCH_SIZE,
            callbacks=callbacks,
            verbose=1
        )

        logger.success("Entrenamiento completado")

    def fine_tune(self, X_train, y_train, X_val, y_val):
        """Descongela las últimas capas de la base y las ajusta con tasa menor."""
        logger.info("\n" + "=" * 60)
        logger.info("FINE-TUNING")
        logger.info("=" * 60)

        # Recuperar la misma base creada en build y habilitar su entrenamiento.
        base_model = getattr(self, 'base_model', None)
        if base_model is None:
            logger.error('No se encontró base_model para fine-tuning. Abortando fine-tune.')
            return
        base_model.trainable = True

        # Las capas iniciales conservan características visuales generales; solo
        # las 50 últimas se adaptan a los instrumentos del dataset.
        if len(base_model.layers) > 50:
            for layer in base_model.layers[:-50]:
                layer.trainable = False

        # Tras cambiar capas entrenables es obligatorio recompilar. Una tasa diez
        # veces menor reduce el riesgo de destruir los pesos preentrenados.
        self.model.compile(
            optimizer=Adam(learning_rate=LEARNING_RATE / 10),
            loss='sparse_categorical_crossentropy',
            metrics=['accuracy']
        )

        logger.info("Entrenando con capas base desbloqueadas...")

        fine_tune_callbacks = [
            keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=5,
                restore_best_weights=True,
                verbose=1,
            ),
            keras.callbacks.ModelCheckpoint(
                OUTPUT_DIR / 'best_fine_tuned_model.keras',
                monitor='val_accuracy',
                save_best_only=True,
                verbose=1,
            ),
        ]

        self.model.fit(
            X_train, y_train,
            validation_data=(X_val, y_val),
            epochs=10,
            batch_size=BATCH_SIZE,
            callbacks=fine_tune_callbacks,
            verbose=1
        )

        logger.success("Fine-tuning completado")

    def evaluate(self, X_test, y_test, class_names):
        """Evalúa una sola vez sobre prueba y devuelve métricas serializables."""
        logger.info("\n" + "=" * 60)
        logger.info("EVALUACIÓN")
        logger.info("=" * 60)

        results = self.model.evaluate(X_test, y_test, verbose=0)
        probabilities = self.model.predict(
            X_test,
            batch_size=BATCH_SIZE,
            verbose=0,
        )
        predictions = np.argmax(probabilities, axis=1)
        report = classification_report(
            y_test,
            predictions,
            labels=list(range(len(class_names))),
            target_names=class_names,
            output_dict=True,
            zero_division=0,
        )
        matrix = confusion_matrix(
            y_test,
            predictions,
            labels=list(range(len(class_names))),
        )

        logger.info(f"Loss: {results[0]:.4f}")
        logger.info(f"Accuracy: {results[1]:.4f} ({results[1]*100:.2f}%)")
        logger.info("=" * 60)

        return {
            'loss': float(results[0]),
            'accuracy': float(results[1]),
            'classification_report': report,
            'confusion_matrix': matrix.tolist(),
        }

# ========== EXPORTACIÓN ==========

def export_to_tflite(model, output_path='instrument_model.tflite'):
    """Convierte el modelo Keras a TFLite optimizado y guarda sus bytes."""
    logger.info(f"\nExportando a TFLite: {output_path}...")

    # La optimización predeterminada reduce el tamaño cuando es seguro hacerlo,
    # manteniendo solo operaciones integradas compatibles con el runtime móvil.
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS
    ]

    tflite_model = converter.convert()

    output_path = OUTPUT_DIR / output_path
    with open(output_path, 'wb') as f:
        f.write(tflite_model)

    size_mb = len(tflite_model) / (1024 * 1024)
    logger.success(f"Modelo exportado: {output_path}")
    logger.info(f"Tamaño: {size_mb:.2f} MB")

    return output_path


def evaluate_tflite(model_path, X_test, y_test):
    """Comprueba que el modelo exportado mantiene la precisión de Keras.

    La conversión puede cambiar tipos o cuantización. Por eso esta evaluación
    consulta los tensores reales del intérprete y adapta entrada y salida antes
    de comparar las clases predichas.
    """
    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    predictions = []

    for image in X_test:
        sample = np.expand_dims(image, axis=0)
        # Si el convertidor cuantizó la entrada, se aplica su escala y punto cero.
        if input_detail['dtype'] != np.float32:
            scale, zero_point = input_detail['quantization']
            sample = np.round(sample / scale + zero_point).astype(
                input_detail['dtype']
            )
        else:
            sample = sample.astype(np.float32)

        interpreter.set_tensor(input_detail['index'], sample)
        interpreter.invoke()
        output = interpreter.get_tensor(output_detail['index'])[0]
        # La salida se devuelve a punto flotante antes de obtener el máximo.
        if output_detail['dtype'] != np.float32:
            scale, zero_point = output_detail['quantization']
            output = (output.astype(np.float32) - zero_point) * scale
        predictions.append(int(np.argmax(output)))

    accuracy = float(np.mean(np.asarray(predictions) == y_test))
    logger.info(f'Accuracy TFLite: {accuracy:.4f} ({accuracy * 100:.2f}%)')
    return accuracy


def save_labels(class_to_idx, output_path='labels.txt'):
    """Guarda una etiqueta por línea en el mismo orden de salida del modelo."""
    output_path = OUTPUT_DIR / output_path

    idx_to_class = {v: k for k, v in class_to_idx.items()}

    with open(output_path, 'w', encoding='utf-8') as f:
        for idx in sorted(idx_to_class.keys()):
            f.write(f"{idx_to_class[idx]}\n")

    logger.success(f"Etiquetas guardadas: {output_path}")

    return output_path

def save_class_mapping(class_to_idx, output_path='class_mapping.json'):
    """Guarda en JSON las conversiones bidireccionales entre clase e índice."""
    output_path = OUTPUT_DIR / output_path
    # JSON exige claves de texto para representar el mapeo índice a clase.
    idx_to_class = {str(idx): cls for cls, idx in class_to_idx.items()}

    mapping = {
        'class_to_idx': class_to_idx,
        'idx_to_class': idx_to_class
    }

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(mapping, f, ensure_ascii=False, indent=2)

    logger.success(f"Mapeo de clases guardado: {output_path}")
    return output_path

# ========== VISUALIZACIÓN ==========

def plot_training_history(history, output_path='training_history.png'):
    """Genera las curvas de precisión y pérdida de entrenamiento/validación."""
    fig, axes = plt.subplots(1, 2, figsize=(15, 5))

    # Precisión por época.
    axes[0].plot(history.history['accuracy'], label='Train')
    axes[0].plot(history.history['val_accuracy'], label='Validation')
    axes[0].set_title('Accuracy')
    axes[0].set_xlabel('Epoch')
    axes[0].set_ylabel('Accuracy')
    axes[0].legend()
    axes[0].grid(True)

    # Pérdida por época.
    axes[1].plot(history.history['loss'], label='Train')
    axes[1].plot(history.history['val_loss'], label='Validation')
    axes[1].set_title('Loss')
    axes[1].set_xlabel('Epoch')
    axes[1].set_ylabel('Loss')
    axes[1].legend()
    axes[1].grid(True)

    output_path = OUTPUT_DIR / output_path
    plt.savefig(output_path, dpi=100, bbox_inches='tight')
    logger.success(f"Gráfico guardado: {output_path}")
    plt.close()


def plot_confusion_matrix(matrix, class_names):
    """Guarda la matriz de confusión del conjunto de prueba como imagen."""
    figure, axis = plt.subplots(figsize=(10, 8))
    image = axis.imshow(matrix, interpolation='nearest', cmap='Blues')
    figure.colorbar(image, ax=axis)
    axis.set(
        xticks=np.arange(len(class_names)),
        yticks=np.arange(len(class_names)),
        xticklabels=class_names,
        yticklabels=class_names,
        ylabel='Clase real',
        xlabel='Predicción',
        title='Matriz de confusión - conjunto de prueba',
    )
    plt.setp(axis.get_xticklabels(), rotation=45, ha='right')

    # El umbral cambia el color del número para conservar contraste con cada
    # intensidad de la celda.
    threshold = np.asarray(matrix).max() / 2
    for row in range(len(class_names)):
        for column in range(len(class_names)):
            axis.text(
                column,
                row,
                str(matrix[row][column]),
                ha='center',
                va='center',
                color='white' if matrix[row][column] > threshold else 'black',
            )

    figure.tight_layout()
    output_path = OUTPUT_DIR / 'confusion_matrix.png'
    figure.savefig(output_path, dpi=120, bbox_inches='tight')
    plt.close(figure)
    logger.success(f'Matriz de confusión guardada: {output_path}')

# ========== PUNTO DE ENTRADA ==========

def main():
    """Ejecuta de forma reproducible las ocho fases del entrenamiento."""
    # Semillas fijas facilitan comparar experimentos con la misma configuración.
    np.random.seed(RANDOM_STATE)
    tf.random.set_seed(RANDOM_STATE)

    logger.info("=" * 60)
    logger.info("ENTRENAMIENTO DE MODELO - LAB INSTRUMENT IDENTIFIER")
    logger.info("=" * 60)
    logger.info(f"Timestamp: {datetime.now()}\n")

    # ========== FASE 1: CARGAR DATOS ==========
    logger.info("\n" + "█" * 60)
    logger.info("FASE 1: CARGAR Y VALIDAR DATOS")
    logger.info("█" * 60)

    loader = DatasetLoader(DATASET_PATH, IMG_SIZE)
    X, y, split_names = loader.load_dataset()

    if X is None:
        logger.error("No se pudo cargar el dataset. Abortando.")
        return

    loader.validate_data(X, y)

    # ========== FASE 2: DIVIDIR DATOS ==========
    logger.info("\n" + "█" * 60)
    logger.info("FASE 2: DIVIDIR DATOS")
    logger.info("█" * 60)

    # Se aplican las asignaciones del manifiesto; no se vuelve a dividir aquí.
    train_mask = split_names == 'train'
    validation_mask = split_names == 'validation'
    test_mask = split_names == 'test'
    X_train, y_train = X[train_mask], y[train_mask]
    X_val, y_val = X[validation_mask], y[validation_mask]
    X_test, y_test = X[test_mask], y[test_mask]

    logger.info(f"Train: {len(X_train)} | Val: {len(X_val)} | Test: {len(X_test)}")

    # ========== FASE 3: CONSTRUIR MODELO ==========
    logger.info("\n" + "█" * 60)
    logger.info("FASE 3: CONSTRUIR MODELO")
    logger.info("█" * 60)

    model = InstrumentModel(len(loader.classes))
    model.build()

    # ========== FASE 4: ENTRENAR ==========
    logger.info("\n" + "█" * 60)
    logger.info("FASE 4: ENTRENAR MODELO")
    logger.info("█" * 60)

    model.train(X_train, y_train, X_val, y_val)

    # ========== FASE 5: FINE-TUNE ==========
    logger.info("\n" + "█" * 60)
    logger.info("FASE 5: FINE-TUNING")
    logger.info("█" * 60)

    model.fine_tune(X_train, y_train, X_val, y_val)

    # ========== FASE 6: EVALUAR ==========
    logger.info("\n" + "█" * 60)
    logger.info("FASE 6: EVALUAR EN TEST SET")
    logger.info("█" * 60)

    metrics = model.evaluate(X_test, y_test, loader.classes)

    # ========== FASE 7: EXPORTAR ==========
    logger.info("\n" + "█" * 60)
    logger.info("FASE 7: EXPORTAR A TFLITE")
    logger.info("█" * 60)

    tflite_path = export_to_tflite(model.model, 'instrument_model.tflite')
    metrics['tflite_accuracy'] = evaluate_tflite(
        tflite_path,
        X_test,
        y_test,
    )
    # Una divergencia superior a dos puntos sugiere un problema de conversión o
    # cuantización y evita publicar un modelo móvil degradado.
    if abs(metrics['accuracy'] - metrics['tflite_accuracy']) > 0.02:
        raise RuntimeError(
            'La precisión TFLite difiere más de 2 puntos de la de Keras'
        )
    save_labels(loader.class_to_idx, 'labels.txt')
    save_class_mapping(loader.class_to_idx, 'class_mapping.json')

    # ========== FASE 8: VISUALIZAR ==========
    if model.history:
        plot_training_history(model.history)
    plot_confusion_matrix(metrics['confusion_matrix'], loader.classes)
    evaluation = {
        'generated_at': datetime.now().isoformat(),
        'dataset_images': int(len(X)),
        'split_counts': {
            'train': int(len(X_train)),
            'validation': int(len(X_val)),
            'test': int(len(X_test)),
        },
        **metrics,
    }
    (OUTPUT_DIR / 'evaluation_metrics.json').write_text(
        json.dumps(evaluation, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )

    # ========== RESUMEN FINAL ==========
    logger.info("\n" + "=" * 60)
    logger.info("ENTRENAMIENTO COMPLETADO")
    logger.info("=" * 60)
    logger.info(f"\nArchivos generados en: {OUTPUT_DIR}/")
    logger.info("  - instrument_model.tflite  (Modelo para Flutter)")
    logger.info("  - labels.txt               (Etiquetas)")
    logger.info("  - class_mapping.json       (Mapeo de clases)")
    logger.info("  - best_model.keras         (Checkpoint)")
    logger.info("  - training_history.png     (Gráfico)")
    logger.info("  - confusion_matrix.png     (Evaluación)")
    logger.info("  - evaluation_metrics.json  (Métricas)")
    logger.info(f"\nAccuracy final: {metrics['accuracy']:.2%}")

    logger.info("\nPRÓXIMO PASO:")
    logger.info("  Ejecuta: python ml/run_pipeline.py --copy-only")
    logger.info("\n" + "=" * 60)

    # El registro se escribe al final para adjuntarlo a los demás artefactos.
    logger.save(OUTPUT_DIR / 'training_log.txt')

if __name__ == '__main__':
    main()
