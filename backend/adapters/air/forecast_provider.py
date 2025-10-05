# backend/adapters/air/forecast_provider.py
import os
import requests
from datetime import datetime, timezone, timedelta
from django.core.cache import cache
import logging

logger = logging.getLogger(__name__)

OPENWEATHER_API_BASE = "http://api.openweathermap.org/data/2.5"

def _categorize_aqi(aqi: int) -> dict:
    """Categoriza el AQI y retorna color, categoría y mensaje"""
    if aqi <= 50:
        return {
            "category": "Bueno",
            "color": "#00e400",
            "message": "La calidad del aire es satisfactoria"
        }
    elif aqi <= 100:
        return {
            "category": "Moderado",
            "color": "#ffff00",
            "message": "La calidad del aire es aceptable"
        }
    elif aqi <= 150:
        return {
            "category": "Dañino para grupos sensibles",
            "color": "#ff7e00",
            "message": "Grupos sensibles pueden experimentar efectos"
        }
    elif aqi <= 200:
        return {
            "category": "Dañino",
            "color": "#ff0000",
            "message": "Todos pueden experimentar efectos en la salud"
        }
    elif aqi <= 300:
        return {
            "category": "Muy dañino",
            "color": "#8f3f97",
            "message": "Alerta de salud: todos pueden experimentar efectos graves"
        }
    else:
        return {
            "category": "Peligroso",
            "color": "#7e0023",
            "message": "Alerta de salud de emergencia"
        }

def _openweather_aqi_to_epa(ow_aqi: int) -> int:
    """
    Convierte el AQI de OpenWeatherMap (1-5) al estándar EPA (0-500).
    OpenWeatherMap usa una escala simplificada:
    1 = Good (0-50)
    2 = Fair (51-100)
    3 = Moderate (101-150)
    4 = Poor (151-200)
    5 = Very Poor (201+)
    """
    conversion = {
        1: 25,   # Bueno
        2: 75,   # Moderado
        3: 125,  # Dañino para grupos sensibles
        4: 175,  # Dañino
        5: 250,  # Muy dañino
    }
    return conversion.get(ow_aqi, 0)

class AirQualityForecastProvider:
    """Proveedor de predicciones de calidad del aire usando OpenWeatherMap"""
    
    def __init__(self, ttl=3600):
        self.ttl = ttl  # Cache por 1 hora
        self.api_key = os.environ.get("OPENWEATHERMAP_API_KEY", "")
    
    def get_forecast(self, lat: float, lon: float, hours: int = 48):
        """
        Obtiene la predicción de calidad del aire para las próximas N horas.
        
        Args:
            lat: Latitud
            lon: Longitud
            hours: Horas de predicción (24 o 48)
        
        Returns:
            Lista de predicciones por hora
        """
        cache_key = f"forecast:{lat:.4f}:{lon:.4f}:{hours}"
        cached = cache.get(cache_key)
        if cached:
            logger.info(f"Cache hit for forecast: {cache_key}")
            return cached
        
        try:
            # Llamada a OpenWeatherMap Air Pollution Forecast API
            url = f"{OPENWEATHER_API_BASE}/air_pollution/forecast"
            params = {
                "lat": lat,
                "lon": lon,
                "appid": self.api_key
            }
            
            logger.info(f"Requesting forecast from OpenWeatherMap: {url}")
            r = requests.get(url, params=params, timeout=10)
            logger.info(f"Response status: {r.status_code}")
            r.raise_for_status()
            
            data = r.json()
            forecast_list = data.get("list", [])
            
            logger.info(f"Received {len(forecast_list)} forecast entries")
            
            # Filtrar solo las próximas N horas
            now = datetime.now(timezone.utc)
            cutoff = now + timedelta(hours=hours)
            
            forecasts = []
            for entry in forecast_list:
                forecast_time = datetime.fromtimestamp(entry["dt"], tz=timezone.utc)
                
                if forecast_time > cutoff:
                    break
                
                # Extraer datos de OpenWeatherMap
                aqi_ow = entry["main"]["aqi"]  # Escala 1-5
                components = entry.get("components", {})
                
                # Convertir a escala EPA
                aqi_epa = _openweather_aqi_to_epa(aqi_ow)
                category_info = _categorize_aqi(aqi_epa)
                
                forecasts.append({
                    "timestamp": forecast_time.isoformat(),
                    "datetime_local": forecast_time.strftime("%Y-%m-%d %H:%M"),
                    "aqi": aqi_epa,
                    "category": category_info["category"],
                    "color": category_info["color"],
                    "message": category_info["message"],
                    "pollutants": {
                        "pm25": components.get("pm2_5"),
                        "pm10": components.get("pm10"),
                        "o3": components.get("o3"),
                        "no2": components.get("no2"),
                        "so2": components.get("so2"),
                        "co": components.get("co"),
                    }
                })
            
            logger.info(f"Returning {len(forecasts)} forecast entries")
            
            # Cachear resultado
            cache.set(cache_key, forecasts, timeout=self.ttl)
            return forecasts
            
        except requests.exceptions.RequestException as e:
            logger.error(f"OpenWeatherMap API request failed: {str(e)}")
            return []
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}", exc_info=True)
            return []
    
    def get_summary_forecast(self, lat: float, lon: float):
        """
        Obtiene un resumen de la predicción para 24h y 48h.
        Retorna el promedio, máximo y mínimo AQI.
        """
        forecasts_48h = self.get_forecast(lat, lon, hours=48)
        
        if not forecasts_48h:
            return None
        
        # Dividir en 24h y 48h
        now = datetime.now(timezone.utc)
        cutoff_24h = now + timedelta(hours=24)
        
        forecasts_24h = []
        forecasts_24_48h = []
        
        for f in forecasts_48h:
            f_time = datetime.fromisoformat(f["timestamp"])
            if f_time <= cutoff_24h:
                forecasts_24h.append(f)
            else:
                forecasts_24_48h.append(f)
        
        def calculate_stats(forecast_list):
            if not forecast_list:
                return None
            
            aqis = [f["aqi"] for f in forecast_list]
            avg_aqi = sum(aqis) // len(aqis)
            max_aqi = max(aqis)
            min_aqi = min(aqis)
            
            return {
                "average": avg_aqi,
                "max": max_aqi,
                "min": min_aqi,
                "average_category": _categorize_aqi(avg_aqi)["category"],
                "max_category": _categorize_aqi(max_aqi)["category"],
                "hourly": forecast_list
            }
        
        return {
            "location": {"lat": lat, "lon": lon},
            "next_24h": calculate_stats(forecasts_24h),
            "next_48h": calculate_stats(forecasts_24_48h) if forecasts_24_48h else None,
        }