# backend/adapters/weather/openweather_provider.py
import os
import requests
from datetime import datetime, timezone
from django.core.cache import cache
import logging

logger = logging.getLogger(__name__)

OPENWEATHER_API_BASE = "https://api.openweathermap.org/data/3.0"

class OpenWeatherProvider:
    """
    Proveedor de datos meteorológicos actuales y predicción usando OpenWeatherMap One Call 3.0.
    """
    
    def __init__(self, ttl=1800):
        self.ttl = ttl  # Cache por 30 minutos
        self.api_key = os.environ.get("OPENWEATHERMAP_API_KEY", "")
    
    def get_current_weather(self, lat: float, lon: float):
        """
        Obtiene datos meteorológicos actuales.
        
        Args:
            lat: Latitud
            lon: Longitud
        
        Returns:
            Datos meteorológicos actuales
        """
        cache_key = f"weather_current:{lat:.4f}:{lon:.4f}"
        cached = cache.get(cache_key)
        if cached:
            logger.info(f"Cache hit for current weather: {cache_key}")
            return cached
        
        try:
            url = f"{OPENWEATHER_API_BASE}/onecall"
            params = {
                "lat": lat,
                "lon": lon,
                "exclude": "minutely,hourly,daily,alerts",
                "units": "metric",
                "appid": self.api_key
            }
            
            logger.info(f"Requesting current weather from OpenWeatherMap: {url}")
            r = requests.get(url, params=params, timeout=10)
            logger.info(f"Response status: {r.status_code}")
            r.raise_for_status()
            
            data = r.json()
            current = data.get("current", {})
            
            result = {
                "timestamp": datetime.fromtimestamp(current["dt"], tz=timezone.utc).isoformat(),
                "temperature": current.get("temp"),
                "feels_like": current.get("feels_like"),
                "humidity": current.get("humidity"),
                "pressure": current.get("pressure"),
                "wind_speed": current.get("wind_speed"),
                "wind_deg": current.get("wind_deg"),
                "clouds": current.get("clouds"),
                "uvi": current.get("uvi"),
                "visibility": current.get("visibility"),
                "dew_point": current.get("dew_point"),
                "weather": {
                    "main": current.get("weather", [{}])[0].get("main"),
                    "description": current.get("weather", [{}])[0].get("description"),
                    "icon": current.get("weather", [{}])[0].get("icon"),
                }
            }
            
            cache.set(cache_key, result, timeout=self.ttl)
            return result
            
        except requests.exceptions.RequestException as e:
            logger.error(f"OpenWeatherMap API request failed: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}", exc_info=True)
            return None
    
    def get_weather_forecast(self, lat: float, lon: float, hours: int = 48):
        """
        Obtiene predicción meteorológica para las próximas 24 o 48 horas.
        
        Args:
            lat: Latitud
            lon: Longitud
            hours: 24 o 48 horas
        
        Returns:
            Predicción meteorológica horaria y diaria
        """
        cache_key = f"weather_forecast:{lat:.4f}:{lon:.4f}:{hours}"
        cached = cache.get(cache_key)
        if cached:
            logger.info(f"Cache hit for weather forecast: {cache_key}")
            return cached
        
        try:
            url = f"{OPENWEATHER_API_BASE}/onecall"
            params = {
                "lat": lat,
                "lon": lon,
                "exclude": "current,minutely,alerts",
                "units": "metric",
                "appid": self.api_key
            }
            
            logger.info(f"Requesting weather forecast: {url}")
            r = requests.get(url, params=params, timeout=10)
            logger.info(f"Response status: {r.status_code}")
            r.raise_for_status()
            
            data = r.json()
            
            # Predicción horaria (48 horas)
            hourly_data = data.get("hourly", [])
            hourly_forecast = []
            
            limit = min(hours, 48)
            for entry in hourly_data[:limit]:
                hourly_forecast.append({
                    "timestamp": datetime.fromtimestamp(entry["dt"], tz=timezone.utc).isoformat(),
                    "temperature": entry.get("temp"),
                    "feels_like": entry.get("feels_like"),
                    "humidity": entry.get("humidity"),
                    "pressure": entry.get("pressure"),
                    "wind_speed": entry.get("wind_speed"),
                    "wind_deg": entry.get("wind_deg"),
                    "clouds": entry.get("clouds"),
                    "pop": round(entry.get("pop", 0) * 100, 1),  # Probabilidad de precipitación en %
                    "rain": entry.get("rain", {}).get("1h", 0),  # Lluvia en mm
                    "weather": {
                        "main": entry.get("weather", [{}])[0].get("main"),
                        "description": entry.get("weather", [{}])[0].get("description"),
                    }
                })
            
            # Predicción diaria (próximos 2 días)
            daily_data = data.get("daily", [])
            daily_forecast = []
            
            for entry in daily_data[:2]:
                daily_forecast.append({
                    "date": datetime.fromtimestamp(entry["dt"], tz=timezone.utc).date().isoformat(),
                    "sunrise": datetime.fromtimestamp(entry["sunrise"], tz=timezone.utc).isoformat(),
                    "sunset": datetime.fromtimestamp(entry["sunset"], tz=timezone.utc).isoformat(),
                    "temperature": {
                        "day": entry["temp"].get("day"),
                        "night": entry["temp"].get("night"),
                        "max": entry["temp"].get("max"),
                        "min": entry["temp"].get("min"),
                        "morning": entry["temp"].get("morn"),
                        "evening": entry["temp"].get("eve"),
                    },
                    "feels_like": {
                        "day": entry["feels_like"].get("day"),
                        "night": entry["feels_like"].get("night"),
                    },
                    "humidity": entry.get("humidity"),
                    "wind_speed": entry.get("wind_speed"),
                    "wind_deg": entry.get("wind_deg"),
                    "clouds": entry.get("clouds"),
                    "pop": round(entry.get("pop", 0) * 100, 1),
                    "rain": entry.get("rain", 0),
                    "uvi": entry.get("uvi"),
                    "weather": {
                        "main": entry.get("weather", [{}])[0].get("main"),
                        "description": entry.get("weather", [{}])[0].get("description"),
                    }
                })
            
            result = {
                "hourly": hourly_forecast,
                "daily": daily_forecast,
            }
            
            cache.set(cache_key, result, timeout=self.ttl)
            return result
            
        except requests.exceptions.RequestException as e:
            logger.error(f"OpenWeatherMap API request failed: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}", exc_info=True)
            return None