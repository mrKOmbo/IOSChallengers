# backend/adapters/air/waqi_forecast_provider.py
import os
import requests
import math
from datetime import datetime, timezone, timedelta
from django.core.cache import cache
import logging

logger = logging.getLogger(__name__)

WAQI_API_BASE = "https://api.waqi.info"

def _categorize_aqi(aqi: int) -> dict:
    """Categoriza el AQI"""
    if aqi <= 50:
        return {"category": "Bueno", "color": "#00e400", "message": "La calidad del aire es satisfactoria"}
    elif aqi <= 100:
        return {"category": "Moderado", "color": "#ffff00", "message": "La calidad del aire es aceptable"}
    elif aqi <= 150:
        return {"category": "Dañino para grupos sensibles", "color": "#ff7e00", "message": "Grupos sensibles pueden experimentar efectos"}
    elif aqi <= 200:
        return {"category": "Dañino", "color": "#ff0000", "message": "Todos pueden experimentar efectos en la salud"}
    elif aqi <= 300:
        return {"category": "Muy dañino", "color": "#8f3f97", "message": "Alerta de salud: todos pueden experimentar efectos graves"}
    else:
        return {"category": "Peligroso", "color": "#7e0023", "message": "Alerta de salud de emergencia"}

def _aqi_from_pm25(pm25: float) -> int:
    """Calcula AQI desde PM2.5 usando fórmula EPA"""
    if pm25 <= 12.0:
        return int((50/12.0)*pm25)
    elif pm25 <= 35.4:
        return int(50 + (pm25-12.1)*50/(35.4-12.1))
    elif pm25 <= 55.4:
        return int(100 + (pm25-35.5)*50/(55.4-35.5))
    elif pm25 <= 150.4:
        return int(150 + (pm25-55.5)*50/(150.4-55.5))
    elif pm25 <= 250.4:
        return int(200 + (pm25-150.5)*100/(250.4-150.5))
    return 301

def _km_to_degrees(km: float, lat: float) -> tuple:
    """Convierte km a grados (lat, lon) aproximados"""
    # 1 grado latitud ≈ 111 km
    dlat = km / 111.0
    # 1 grado longitud ≈ 111 * cos(lat) km
    dlon = km / (111.0 * math.cos(math.radians(lat)))
    return dlat, dlon

class WAQIForecastProvider:
    """Proveedor de predicciones usando WAQI API"""
    
    def __init__(self, ttl=3600):
        self.ttl = ttl
        self.api_key = os.environ.get("WAQI_API_KEY", "")
    
    def _get_single_point_forecast(self, lat: float, lon: float):
        """Obtiene forecast de un solo punto"""
        try:
            url = f"{WAQI_API_BASE}/feed/geo:{lat};{lon}/"
            params = {"token": self.api_key}
            
            r = requests.get(url, params=params, timeout=10)
            r.raise_for_status()
            
            data = r.json()
            
            if data.get("status") != "ok":
                logger.warning(f"WAQI returned status: {data.get('status')} for {lat},{lon}")
                return None
            
            station_data = data.get("data", {})
            
            # Extraer datos
            current_aqi = station_data.get("aqi")
            forecast_data = station_data.get("forecast", {}).get("daily", {})
            pm25_forecast = forecast_data.get("pm25", [])
            pm10_forecast = forecast_data.get("pm10", [])
            
            return {
                "current_aqi": current_aqi,
                "station_name": station_data.get("city", {}).get("name"),
                "coordinates": station_data.get("city", {}).get("geo"),
                "pm25_forecast": pm25_forecast,
                "pm10_forecast": pm10_forecast,
            }
            
        except Exception as e:
            logger.error(f"Error fetching WAQI data for {lat},{lon}: {str(e)}")
            return None
    
    def get_forecast_with_radius(self, lat: float, lon: float, radius_km: float = 10, hours: int = 48):
        """
        Obtiene predicción con radio de alcance.
        
        Args:
            lat: Latitud central
            lon: Longitud central
            radius_km: Radio en km (default: 10)
            hours: 24 o 48 horas
        
        Returns:
            Predicción agregada del área
        """
        cache_key = f"waqi_forecast_radius:{lat:.4f}:{lon:.4f}:{radius_km}:{hours}"
        cached = cache.get(cache_key)
        if cached:
            logger.info(f"Cache hit for WAQI forecast radius: {cache_key}")
            return cached
        
        # Generar puntos de muestreo (centro + 8 direcciones)
        # Paso de ~5km para cubrir el radio de 10km
        step_km = radius_km / 2.0
        dlat, dlon = _km_to_degrees(step_km, lat)
        
        sample_points = [
            (lat, lon),                    # Centro
            (lat + dlat, lon),             # Norte
            (lat - dlat, lon),             # Sur
            (lat, lon + dlon),             # Este
            (lat, lon - dlon),             # Oeste
            (lat + dlat, lon + dlon),      # NE
            (lat + dlat, lon - dlon),      # NW
            (lat - dlat, lon + dlon),      # SE
            (lat - dlat, lon - dlon),      # SW
        ]
        
        logger.info(f"Sampling {len(sample_points)} points in {radius_km}km radius")
        
        # Obtener datos de cada punto
        all_forecasts = []
        for plat, plon in sample_points:
            point_data = self._get_single_point_forecast(plat, plon)
            if point_data:
                all_forecasts.append(point_data)
        
        if not all_forecasts:
            logger.error("No forecast data available in the area")
            return None
        
        logger.info(f"Got data from {len(all_forecasts)} stations")
        
        # Determinar qué días necesitamos
        today = datetime.now(timezone.utc).date()
        tomorrow = today + timedelta(days=1)
        day_after_tomorrow = today + timedelta(days=2)
        
        # Agregar datos por día
        def aggregate_day_forecast(target_date):
            """Agrega forecast de todos los puntos para un día específico"""
            day_str = target_date.strftime("%Y-%m-%d")
            
            pm25_values = []
            pm10_values = []
            
            for forecast in all_forecasts:
                # Buscar el día en pm25_forecast
                for entry in forecast["pm25_forecast"]:
                    if entry.get("day") == day_str:
                        avg = entry.get("avg")
                        if avg:
                            pm25_values.append(avg)
                        break
                
                # Buscar en pm10_forecast
                for entry in forecast["pm10_forecast"]:
                    if entry.get("day") == day_str:
                        avg = entry.get("avg")
                        if avg:
                            pm10_values.append(avg)
                        break
            
            if not pm25_values:
                return None
            
            # Promediar
            avg_pm25 = sum(pm25_values) / len(pm25_values)
            max_pm25 = max(pm25_values)
            min_pm25 = min(pm25_values)
            
            avg_pm10 = sum(pm10_values) / len(pm10_values) if pm10_values else None
            
            # Calcular AQI
            aqi = _aqi_from_pm25(avg_pm25)
            category_info = _categorize_aqi(aqi)
            
            return {
                "date": day_str,
                "aqi": aqi,
                "category": category_info["category"],
                "color": category_info["color"],
                "message": category_info["message"],
                "pollutants": {
                    "pm25": {
                        "avg": round(avg_pm25, 1),
                        "max": round(max_pm25, 1),
                        "min": round(min_pm25, 1),
                    },
                    "pm10": {
                        "avg": round(avg_pm10, 1) if avg_pm10 else None,
                    }
                }
            }
        
        # Construir respuesta
        result = {
            "center": {"lat": lat, "lon": lon},
            "radius_km": radius_km,
            "stations_sampled": len(all_forecasts),
            "current_aqi": all_forecasts[0]["current_aqi"],  # Del punto central
        }
        
        # Agregar forecast según las horas solicitadas
        if hours >= 24:
            forecast_24h = aggregate_day_forecast(tomorrow)
            if forecast_24h:
                result["forecast_24h"] = forecast_24h
        
        if hours >= 48:
            forecast_48h = aggregate_day_forecast(day_after_tomorrow)
            if forecast_48h:
                result["forecast_48h"] = forecast_48h
        
        cache.set(cache_key, result, timeout=self.ttl)
        return result