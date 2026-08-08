"""Prepara, importa, valida y audita el dataset local de instrumentos."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageOps
from sklearn.model_selection import StratifiedGroupKFold

# Rutas canónicas para que el script funcione sin depender del directorio desde
# el que se invoque.
ML_ROOT = Path(__file__).resolve().parent
DATASET_DIR = ML_ROOT / 'data' / 'instruments'
ARTIFACTS_DIR = ML_ROOT / 'artifacts'

# Las carpetas de clase y extensiones admitidas forman el contrato del dataset.
CLASSES = (
    'buretas',
    'crisoles',
    'embudos',
    'gradillas',
    'matraces',
    'microscopio',
    'pinzas',
    'pipetas',
    'probeta',
    'vasos_precipitado',
)
SUPPORTED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp', '.avif'}
RANDOM_STATE = 42


def prepare() -> None:
    """Crea la estructura de carpetas esperada sin borrar datos existentes."""
    for class_name in CLASSES:
        (DATASET_DIR / class_name).mkdir(parents=True, exist_ok=True)
    print(f'Estructura preparada en {DATASET_DIR}')


def is_valid_image(path: Path) -> bool:
    """Comprueba que Pillow pueda decodificar una imagen sin cargarla completa."""
    try:
        with Image.open(path) as image:
            image.verify()
        return True
    except (OSError, ValueError):
        return False


def iter_images(class_dir: Path) -> list[Path]:
    """Devuelve, en orden estable, los archivos de imagen admitidos de una clase."""
    return sorted(
        path
        for path in class_dir.iterdir()
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS
    )


def validate(minimum_per_class: int) -> bool:
    """Valida imágenes y cantidad mínima por clase; retorna el resultado global."""
    prepare()
    valid = True
    total = 0

    for class_name in CLASSES:
        class_dir = DATASET_DIR / class_name
        candidates = iter_images(class_dir)
        valid_images = [path for path in candidates if is_valid_image(path)]
        total += len(valid_images)
        print(f'{class_name}: {len(valid_images)} imágenes válidas')
        if len(valid_images) < minimum_per_class:
            valid = False

    print(f'Total: {total} imágenes válidas')
    return valid


def _difference_hash(image: Image.Image) -> int:
    """Calcula un dHash de 64 bits para detectar imágenes visualmente similares.

    La transposición EXIF corrige fotografías tomadas con orientación almacenada
    como metadato. Después se comparan píxeles vecinos en escala de grises.
    """
    grayscale = ImageOps.exif_transpose(image).convert('L').resize((9, 8))
    pixels = list(grayscale.tobytes())
    result = 0
    for row in range(8):
        for column in range(8):
            left = pixels[row * 9 + column]
            right = pixels[row * 9 + column + 1]
            result = (result << 1) | int(left > right)
    return result


def _create_split_manifest(
    records: list[dict[str, object]],
) -> list[dict[str, object]]:
    """Asigna cada imagen a entrenamiento, validación o prueba.

    La división es estratificada por clase y agrupada por SHA-256. Agrupar las
    copias exactas impide que una misma imagen aparezca en más de un conjunto y
    produzca una evaluación artificialmente optimista.
    """
    labels = [str(record['class']) for record in records]
    groups = [str(record['sha256']) for record in records]
    indexes = list(range(len(records)))

    # Primera división: reserva una quinta parte para la prueba final.
    outer_splitter = StratifiedGroupKFold(
        n_splits=5,
        shuffle=True,
        random_state=RANDOM_STATE,
    )
    train_validation_indexes, test_indexes = next(
        outer_splitter.split(indexes, labels, groups)
    )

    train_validation_labels = [
        labels[index] for index in train_validation_indexes
    ]
    train_validation_groups = [
        groups[index] for index in train_validation_indexes
    ]
    # Segunda división: separa validación dentro del bloque restante.
    inner_splitter = StratifiedGroupKFold(
        n_splits=4,
        shuffle=True,
        random_state=RANDOM_STATE,
    )
    train_relative, validation_relative = next(
        inner_splitter.split(
            train_validation_indexes,
            train_validation_labels,
            train_validation_groups,
        )
    )

    split_by_index = {int(index): 'test' for index in test_indexes}
    split_by_index.update(
        {
            int(train_validation_indexes[index]): 'train'
            for index in train_relative
        }
    )
    split_by_index.update(
        {
            int(train_validation_indexes[index]): 'validation'
            for index in validation_relative
        }
    )

    manifest = [
        {
            'path': record['path'],
            'class': record['class'],
            'sha256': record['sha256'],
            'split': split_by_index[index],
        }
        for index, record in enumerate(records)
    ]

    # Esta comprobación protege contra cualquier fuga de duplicados exactos.
    group_splits: dict[str, set[str]] = defaultdict(set)
    for item in manifest:
        group_splits[str(item['sha256'])].add(str(item['split']))
    if any(len(splits) > 1 for splits in group_splits.values()):
        raise RuntimeError('Una imagen duplicada quedó distribuida en varios splits')
    return manifest


def audit(near_distance: int = 4) -> dict[str, object]:
    """Audita integridad, resolución y duplicados, y genera los artefactos JSON.

    ``near_distance`` es la distancia de Hamming máxima entre hashes perceptivos
    para considerar dos archivos visualmente similares. El informe resultante
    se devuelve además de guardarse para que el pipeline pueda bloquear errores
    críticos antes del entrenamiento.
    """
    records: list[dict[str, object]] = []
    invalid_images: list[str] = []

    for class_name in CLASSES:
        class_dir = DATASET_DIR / class_name
        for image_path in iter_images(class_dir):
            relative_path = image_path.relative_to(ML_ROOT).as_posix()
            try:
                file_bytes = image_path.read_bytes()
                with Image.open(image_path) as image:
                    width, height = image.size
                    difference_hash = _difference_hash(image)
                records.append(
                    {
                        'path': relative_path,
                        'class': class_name,
                        'width': width,
                        'height': height,
                        'size_bytes': len(file_bytes),
                        'sha256': hashlib.sha256(file_bytes).hexdigest(),
                        'dhash': f'{difference_hash:016x}',
                    }
                )
            except (OSError, ValueError):
                invalid_images.append(relative_path)

    # SHA-256 detecta copias byte a byte y permite identificar etiquetas
    # contradictorias cuando un archivo aparece en carpetas de clases distintas.
    by_sha256: dict[str, list[dict[str, object]]] = defaultdict(list)
    for record in records:
        by_sha256[str(record['sha256'])].append(record)

    exact_duplicates = [
        [str(record['path']) for record in group]
        for group in by_sha256.values()
        if len(group) > 1
    ]
    cross_class_duplicates = [
        [str(record['path']) for record in group]
        for group in by_sha256.values()
        if len({record['class'] for record in group}) > 1
    ]

    # dHash detecta pares parecidos aunque hayan sido redimensionados o
    # recomprimidos. No se consideran aquí los duplicados exactos ya reportados.
    near_duplicates: list[dict[str, object]] = []
    for index, left in enumerate(records):
        left_hash = int(str(left['dhash']), 16)
        for right in records[index + 1 :]:
            if left['sha256'] == right['sha256']:
                continue
            distance = (left_hash ^ int(str(right['dhash']), 16)).bit_count()
            if distance <= near_distance:
                near_duplicates.append(
                    {
                        'left': left['path'],
                        'right': right['path'],
                        'distance': distance,
                        'cross_class': left['class'] != right['class'],
                    }
                )

    # Las imágenes menores que la entrada del modelo deben ampliarse y pueden
    # perder detalle, por eso se registran como riesgo de calidad.
    low_resolution = [
        str(record['path'])
        for record in records
        if min(int(record['width']), int(record['height'])) < 224
    ]
    class_counts = {
        class_name: sum(record['class'] == class_name for record in records)
        for class_name in CLASSES
    }
    report: dict[str, object] = {
        'total_images': len(records),
        'class_counts': class_counts,
        'invalid_images': invalid_images,
        'low_resolution_images': low_resolution,
        'exact_duplicate_groups': exact_duplicates,
        'cross_class_exact_duplicate_groups': cross_class_duplicates,
        'near_duplicate_pairs': near_duplicates,
        'near_duplicate_distance': near_distance,
    }
    split_manifest = _create_split_manifest(records)
    split_counts = {
        split_name: sum(item['split'] == split_name for item in split_manifest)
        for split_name in ('train', 'validation', 'test')
    }
    report['split_counts'] = split_counts

    # Ambos archivos son reproducibles: el informe documenta la calidad y el
    # manifiesto fija qué muestras pertenecen a cada conjunto.
    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    report_path = ARTIFACTS_DIR / 'dataset_audit.json'
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )
    manifest_path = ARTIFACTS_DIR / 'split_manifest.json'
    manifest_path.write_text(
        json.dumps(split_manifest, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )

    print(f'Auditoría guardada en {report_path.relative_to(ML_ROOT.parent)}')
    print(f'Imágenes: {len(records)}')
    print(f'Inválidas: {len(invalid_images)}')
    print(f'Baja resolución: {len(low_resolution)}')
    print(f'Grupos duplicados exactos: {len(exact_duplicates)}')
    print(f'Duplicados exactos entre clases: {len(cross_class_duplicates)}')
    print(f'Pares visualmente similares: {len(near_duplicates)}')
    print(
        'División: '
        f"{split_counts['train']} entrenamiento, "
        f"{split_counts['validation']} validación, "
        f"{split_counts['test']} prueba"
    )
    return report


def import_from(source: Path) -> None:
    """Copia desde otra raíz solo imágenes válidas de las clases conocidas.

    Si un nombre ya existe, se añade el tamaño del archivo para evitar una
    sobrescritura accidental del ejemplar presente en el dataset.
    """
    prepare()
    if not source.is_dir():
        raise RuntimeError(f'La ruta de origen no existe: {source}')

    for class_name in CLASSES:
        source_class = source / class_name
        if not source_class.is_dir():
            continue

        destination_class = DATASET_DIR / class_name
        for source_image in source_class.iterdir():
            if (
                not source_image.is_file()
                or source_image.suffix.lower() not in SUPPORTED_EXTENSIONS
                or not is_valid_image(source_image)
            ):
                continue

            destination = destination_class / source_image.name
            if destination.exists():
                destination = destination_class / (
                    f'{source_image.stem}_{source_image.stat().st_size}'
                    f'{source_image.suffix.lower()}'
                )
            shutil.copy2(source_image, destination)


def parse_args() -> argparse.Namespace:
    """Define y procesa los comandos disponibles en la interfaz de consola."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        'command',
        choices=('prepare', 'validate', 'audit', 'import'),
    )
    parser.add_argument('--source', type=Path)
    parser.add_argument('--minimum', type=int, default=10)
    parser.add_argument('--near-distance', type=int, default=4)
    return parser.parse_args()


def main() -> int:
    """Ejecuta el comando solicitado y comunica éxito o fallo mediante el código."""
    args = parse_args()
    if args.command == 'prepare':
        prepare()
        return 0
    if args.command == 'import':
        if args.source is None:
            raise RuntimeError('--source es obligatorio para importar')
        import_from(args.source)
    if args.command == 'audit':
        report = audit(args.near_distance)
        # Una imagen ilegible o idéntica entre clases hace que las etiquetas no
        # sean confiables y, por tanto, produce un código de salida de error.
        has_critical_errors = bool(
            report['invalid_images']
            or report['cross_class_exact_duplicate_groups']
        )
        return 1 if has_critical_errors else 0
    return 0 if validate(args.minimum) else 1


if __name__ == '__main__':
    raise SystemExit(main())
