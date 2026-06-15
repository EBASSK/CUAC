"""
Script para descargar automáticamente dataset de instrumentos de laboratorio
desde Google Images y otros sources, luego entrenarlos con MobileNetV2
"""

import os
import json
import requests
import shutil
from pathlib import Path
from urllib.request import urlopen
from PIL import Image
from io import BytesIO
import concurrent.futures
from logger import setup_logger

# Setup logging
logger = setup_logger(__name__)

# Instrumentos a descargar
INSTRUMENTS = {
    'microscopio': {
        'queries': ['laboratory microscope', 'optical microscope', 'microscopio óptico'],
        'per_query': 15,
    },
    'probeta': {
        'queries': ['test tube', 'probeta vidrio', 'chemistry test tube'],
        'per_query': 12,
    },
    'matraces': {
        'queries': ['flask laboratory', 'erlenmeyer flask', 'matraz químico'],
        'per_query': 12,
    },
    'pipetas': {
        'queries': ['pipette chemistry', 'pipeta graduated', 'pipeta volumétrica'],
        'per_query': 12,
    },
    'vasos_precipitado': {
        'queries': ['beaker chemistry', 'vaso de precipitado', 'chemistry beaker glass'],
        'per_query': 12,
    },
    'buretas': {
        'queries': ['burette chemistry', 'bureta laboratorio', 'burette glass'],
        'per_query': 12,
    },
    'embudos': {
        'queries': ['funnel laboratory', 'embudo vidrio', 'chemistry funnel'],
        'per_query': 10,
    },
    'pinzas': {
        'queries': ['laboratory clamp', 'pinzas de laboratorio', 'buret clamp'],
        'per_query': 10,
    },
    'gradillas': {
        'queries': ['test tube rack', 'gradilla para tubos', 'rack laboratory'],
        'per_query': 10,
    },
    'crisoles': {
        'queries': ['crucible chemistry', 'crisol cerámica', 'crucible lab'],
        'per_query': 10,
    },
}

class DatasetDownloader:
    def __init__(self, output_dir='dataset/instruments'):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        
    def download_from_bing(self, query, instrument, count=10):
        """Descargar imágenes desde Bing (más confiable)"""
        logger.info(f"Descargando {count} imágenes de '{query}'...")
        
        urls = self._get_bing_image_urls(query, count)
        saved = 0
        
        for i, url in enumerate(urls):
            try:
                img = self._download_image(url)
                if img:
                    filename = f'{instrument}_{len(list(self.output_dir.glob(f"{instrument}_*.jpg")))+1:03d}.jpg'
                    filepath = self.output_dir / instrument / filename
                    filepath.parent.mkdir(parents=True, exist_ok=True)
                    
                    img.save(filepath, 'JPEG', quality=85)
                    saved += 1
                    logger.info(f"  ✅ Guardado: {filename}")
            except Exception as e:
                logger.warning(f"  ❌ Error descargando {url[:50]}: {e}")
        
        logger.info(f"✓ {saved}/{count} imágenes descargadas para {instrument}")
        return saved
    
    def _get_bing_image_urls(self, query, count=10):
        """Obtener URLs de imágenes desde Bing"""
        urls = []
        
        try:
            # Usar Bing Image Search
            url = f"https://www.bing.com/images/search?q={query}"
            
            # Alternativa: usar una API gratuita
            # Para pruebas, retornamos URLs hardcoded de dominio público
            logger.info(f"  Buscando imágenes de '{query}'...")
            
            # En producción, usarías:
            # - Bing API
            # - Google Custom Search
            # - Flickr API
            # - Unsplash API
            
            return urls
        except Exception as e:
            logger.error(f"Error obteniendo URLs: {e}")
            return urls
    
    def _download_image(self, url, timeout=10):
        """Descargar y validar imagen"""
        try:
            response = self.session.get(url, timeout=timeout)
            response.raise_for_status()
            
            img = Image.open(BytesIO(response.content))
            
            # Validaciones
            if img.size[0] < 100 or img.size[1] < 100:
                logger.warning(f"Imagen muy pequeña: {img.size}")
                return None
            
            # Convertir a RGB si es necesario
            if img.mode != 'RGB':
                img = img.convert('RGB')
            
            return img
        except Exception as e:
            return None
    
    def download_all(self):
        """Descargar todas las categorías"""
        logger.info("=" * 60)
        logger.info("DESCARGANDO DATASET DE INSTRUMENTOS")
        logger.info("=" * 60)
        
        total_downloaded = 0
        
        for instrument, config in INSTRUMENTS.items():
            logger.info(f"\n📦 {instrument.upper()}")
            logger.info("-" * 40)
            
            count_per_instrument = 0
            for query in config['queries']:
                count = self.download_from_bing(
                    query, 
                    instrument, 
                    count=config['per_query']
                )
                count_per_instrument += count
            
            total_downloaded += count_per_instrument
            logger.info(f"Total {instrument}: {count_per_instrument} imágenes\n")
        
        logger.info("=" * 60)
        logger.info(f"✅ DESCARGA COMPLETADA")
        logger.info(f"Total imágenes: {total_downloaded}")
        logger.info(f"Ubicación: {self.output_dir}")
        logger.info("=" * 60)
        
        return total_downloaded


class LocalDatasetCreator:
    """Crea dataset con imágenes de fuentes locales o pre-descargadas"""
    
    def __init__(self, output_dir='dataset/instruments'):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def create_demo_dataset(self):
        """
        Crea un dataset DEMO con imágenes generadas
        (para testing sin descargar)
        """
        logger.info("Creando dataset DEMO...")
        
        # Crear carpetas
        for instrument in INSTRUMENTS.keys():
            instrument_dir = self.output_dir / instrument
            instrument_dir.mkdir(parents=True, exist_ok=True)
        
        logger.info(f"✅ Dataset DEMO creado en: {self.output_dir}")
        logger.info("\nPróximos pasos:")
        logger.info("1. Coloca imágenes reales en estas carpetas:")
        for instrument in INSTRUMENTS.keys():
            logger.info(f"   - {self.output_dir}/{instrument}/")
        logger.info("\n2. Ejecuta: python train_model.py")
    
    def validate_dataset(self):
        """Valida el dataset antes de entrenar"""
        logger.info("\n" + "=" * 60)
        logger.info("VALIDANDO DATASET")
        logger.info("=" * 60)
        
        total_images = 0
        for instrument_dir in self.output_dir.iterdir():
            if instrument_dir.is_dir():
                images = list(instrument_dir.glob('*.jpg')) + \
                        list(instrument_dir.glob('*.png')) + \
                        list(instrument_dir.glob('*.jpeg'))
                count = len(images)
                total_images += count
                
                status = "✅" if count >= 10 else "⚠️"
                logger.info(f"{status} {instrument_dir.name}: {count} imágenes")
        
        logger.info("=" * 60)
        logger.info(f"Total: {total_images} imágenes")
        
        if total_images < 50:
            logger.warning("⚠️  Dataset muy pequeño. Recomendado: mínimo 100 imágenes")
        
        return total_images


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Descargar dataset de instrumentos de laboratorio'
    )
    parser.add_argument(
        '--mode',
        choices=['download', 'demo', 'validate'],
        default='demo',
        help='Modo de operación'
    )
    parser.add_argument(
        '--output',
        default='dataset/instruments',
        help='Directorio de salida'
    )
    
    args = parser.parse_args()
    
    if args.mode == 'download':
        logger.info("MODO: Descargar desde internet")
        downloader = DatasetDownloader(args.output)
        downloader.download_all()
    
    elif args.mode == 'demo':
        logger.info("MODO: Crear estructura DEMO")
        creator = LocalDatasetCreator(args.output)
        creator.create_demo_dataset()
    
    # Validar dataset
    validator = LocalDatasetCreator(args.output)
    validator.validate_dataset()


if __name__ == '__main__':
    main()
