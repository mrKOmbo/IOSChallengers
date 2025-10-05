# backend/adapters/air/openaq_grid_provider.py
import os
import requests
from datetime import datetime, timezone
from django.core.cache import cache
import logging

logger = logging.getLogger(__name__)

OPENAQ_API_BASE = "https://api.openaq.org/v3"

def _cell_id(lat, lon, res=0.005):  # ~500 m
    # redondeo simple para agrupar consultas cercanas
    from math import floor
    latq = round(lat / res) * res
    lonq = round(lon / res) * res
    return f"{latq:.3f}:{lonq:.3f}"

def _aqi_from_pm25(pm25: float) -> int:
    """Calcula AQI de PM2.5 en µg/m³"""
    if pm25 <= 12.0:   return int((50/12.0)*pm25)
    if pm25 <= 35.4:   return int(50 + (pm25-12.1)*50/(35.4-12.1))
    if pm25 <= 55.4:   return int(100 + (pm25-35.5)*50/(55.4-35.5))
    if pm25 <= 150.4:  return int(150 + (pm25-55.5)*50/(150.4-55.5))
    if pm25 <= 250.4:  return int(200 + (pm25-150.5)*100/(250.4-150.5))
    return 301

def _aqi_from_o3(o3_ppm: float) -> int:
    """Calcula AQI de O3 en ppm (8-hour average)"""
    if o3_ppm <= 0.054:   return int((50/0.054)*o3_ppm)
    if o3_ppm <= 0.070:   return int(51 + (o3_ppm-0.055)*49/(0.070-0.055))
    if o3_ppm <= 0.085:   return int(101 + (o3_ppm-0.071)*49/(0.085-0.071))
    if o3_ppm <= 0.105:   return int(151 + (o3_ppm-0.086)*49/(0.105-0.086))
    if o3_ppm <= 0.200:   return int(201 + (o3_ppm-0.106)*99/(0.200-0.106))
    return 301

def _aqi_from_no2(no2_ppm: float) -> int:
    """Calcula AQI de NO2 en ppm (1-hour average). Convierte a ppb primero."""
    no2_ppb = no2_ppm * 1000  # Convertir ppm a ppb
    
    if no2_ppb <= 53:    return int((50/53)*no2_ppb)
    if no2_ppb <= 100:   return int(51 + (no2_ppb-54)*49/(100-54))
    if no2_ppb <= 360:   return int(101 + (no2_ppb-101)*49/(360-101))
    if no2_ppb <= 649:   return int(151 + (no2_ppb-361)*49/(649-361))
    if no2_ppb <= 1249:  return int(201 + (no2_ppb-650)*99/(1249-650))
    return 301

def _aqi_from_pm10(pm10: float) -> int:
    """Calcula AQI de PM10 en µg/m³"""
    if pm10 <= 54:    return int((50/54)*pm10)
    if pm10 <= 154:   return int(51 + (pm10-55)*49/(154-55))
    if pm10 <= 254:   return int(101 + (pm10-155)*49/(254-155))
    if pm10 <= 354:   return int(151 + (pm10-255)*49/(354-255))
    if pm10 <= 424:   return int(201 + (pm10-355)*99/(424-355))
    return 301

def _aqi_from_co(co_ppm: float) -> int:
    """Calcula AQI de CO en ppm"""
    if co_ppm <= 4.4:   return int((50/4.4)*co_ppm)
    if co_ppm <= 9.4:   return int(51 + (co_ppm-4.5)*49/(9.4-4.5))
    if co_ppm <= 12.4:  return int(101 + (co_ppm-9.5)*49/(12.4-9.5))
    if co_ppm <= 15.4:  return int(151 + (co_ppm-12.5)*49/(15.4-12.5))
    if co_ppm <= 30.4:  return int(201 + (co_ppm-15.5)*99/(30.4-15.5))
    return 301

def _aqi_from_so2(so2_ppm: float) -> int:
    """Calcula AQI de SO2 en ppm. Convierte a ppb primero."""
    so2_ppb = so2_ppm * 1000
    
    if so2_ppb <= 35:    return int((50/35)*so2_ppb)
    if so2_ppb <= 75:    return int(51 + (so2_ppb-36)*49/(75-36))
    if so2_ppb <= 185:   return int(101 + (so2_ppb-76)*49/(185-76))
    if so2_ppb <= 304:   return int(151 + (so2_ppb-186)*49/(304-186))
    if so2_ppb <= 604:   return int(201 + (so2_ppb-305)*99/(604-305))
    return 301

def _aqi_from_pollutants(values: dict) -> int:
    """Calcula AQI máximo de todos los contaminantes disponibles"""
    subs = []
    
    if values.get("pm25") is not None:
        aqi_pm25 = _aqi_from_pm25(values["pm25"])
        subs.append(aqi_pm25)
        logger.info(f"PM2.5 AQI: {aqi_pm25} (value: {values['pm25']} µg/m³)")
    
    if values.get("pm10") is not None:
        aqi_pm10 = _aqi_from_pm10(values["pm10"])
        subs.append(aqi_pm10)
        logger.info(f"PM10 AQI: {aqi_pm10} (value: {values['pm10']} µg/m³)")
    
    if values.get("o3") is not None:
        aqi_o3 = _aqi_from_o3(values["o3"])
        subs.append(aqi_o3)
        logger.info(f"O3 AQI: {aqi_o3} (value: {values['o3']} ppm)")
    
    if values.get("no2") is not None:
        aqi_no2 = _aqi_from_no2(values["no2"])
        subs.append(aqi_no2)
        logger.info(f"NO2 AQI: {aqi_no2} (value: {values['no2']} ppm = {values['no2']*1000} ppb)")
    
    if values.get("co") is not None:
        aqi_co = _aqi_from_co(values["co"])
        subs.append(aqi_co)
        logger.info(f"CO AQI: {aqi_co} (value: {values['co']} ppm)")
    
    if values.get("so2") is not None:
        aqi_so2 = _aqi_from_so2(values["so2"])
        subs.append(aqi_so2)
        logger.info(f"SO2 AQI: {aqi_so2} (value: {values['so2']} ppm = {values['so2']*1000} ppb)")
    
    final_aqi = max(subs) if subs else 0
    logger.info(f"Final AQI (max of all pollutants): {final_aqi}")
    return final_aqi

class OpenAQGridProvider:
    """Devuelve AQI aproximado en un punto/hora usando OpenAQ (MVP con caché)."""
    def __init__(self, radius_m=10000, ttl=300):
        self.radius_m = radius_m
        self.ttl = ttl

    def get_aqi_cell(self, lat: float, lon: float, when: datetime):
        when = (when or datetime.now(timezone.utc)).astimezone(timezone.utc)
        when = when.replace(minute=0, second=0, microsecond=0)
        key = f"grid:{_cell_id(lat, lon)}:{when.isoformat()}"
        cached = cache.get(key)
        if cached:
            logger.info(f"Cache hit for {key}")
            return cached

        headers = {
            "X-API-Key": os.environ.get("OPENAQ_API_KEY", "")
        }
        
        try:
            # Paso 1: Buscar ubicaciones cercanas
            locations_url = f"{OPENAQ_API_BASE}/locations"
            params = {
                "coordinates": f"{lat},{lon}",
                "radius": self.radius_m,
                "limit": 10,
            }
            
            logger.info(f"Requesting locations: {locations_url} with params: {params}")
            r = requests.get(locations_url, params=params, headers=headers, timeout=10)
            logger.info(f"Locations Response Status: {r.status_code}")
            r.raise_for_status()
            
            locations_data = r.json()
            logger.info(f"Locations Response: {locations_data}")
            
            results = locations_data.get("results", [])
            logger.info(f"Found {len(results)} locations")
            
            if not results:
                logger.warning("No locations found near coordinates")
                values = {}
            else:
                # Obtener la primera ubicación
                location = results[0]
                location_id = location["id"]
                location_name = location.get("name", "Unknown")
                distance = location.get("distance", "N/A")
                
                logger.info(f"Using location: {location_name} (ID: {location_id}), Distance: {distance}m")
                
                # Crear mapeo de sensor_id -> parameter_name
                sensor_map = {}
                for sensor in location.get("sensors", []):
                    sensor_id = sensor.get("id")
                    param_name = sensor.get("parameter", {}).get("name")
                    if sensor_id and param_name:
                        sensor_map[sensor_id] = param_name
                
                logger.info(f"Sensor mapping: {sensor_map}")
                
                # Paso 2: Obtener mediciones actuales
                latest_url = f"{OPENAQ_API_BASE}/locations/{location_id}/latest"
                logger.info(f"Requesting latest measurements: {latest_url}")
                
                r2 = requests.get(latest_url, headers=headers, timeout=10)
                logger.info(f"Latest measurements Response Status: {r2.status_code}")
                r2.raise_for_status()
                
                latest_data = r2.json()
                logger.info(f"Latest measurements Response: {latest_data}")
                
                # Extraer mediciones usando el mapeo de sensores
                measurements = latest_data.get("results", [])
                logger.info(f"Found {len(measurements)} measurements")
                
                values = {}
                for measurement in measurements:
                    sensor_id = measurement.get("sensorsId")
                    value = measurement.get("value")
                    param_name = sensor_map.get(sensor_id)
                    
                    if param_name and value is not None:
                        # Si ya existe el parámetro, usa el valor más reciente
                        if param_name not in values:
                            values[param_name] = value
                            logger.info(f"Mapped sensor {sensor_id} -> {param_name} = {value}")
                
                logger.info(f"Extracted values: {values}")
            
        except requests.exceptions.RequestException as e:
            logger.error(f"OpenAQ API request failed: {str(e)}")
            values = {}
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}", exc_info=True)
            values = {}

        aqi = _aqi_from_pollutants(values)
        logger.info(f"Calculated AQI: {aqi} from values: {values}")
        
        payload = {
            "aqi": aqi,
            "pm25": values.get("pm25"),
            "pm10": values.get("pm10"),
            "o3": values.get("o3"),
            "no2": values.get("no2"),
            "co": values.get("co"),
            "so2": values.get("so2"),
            "ai": None, "rain": 0.0, "pbl": 800.0, "wind": {"u": 0.0, "v": 0.0}
        }
        cache.set(key, payload, timeout=self.ttl)
        return payload

    def get_nearby_locations(self, lat: float, lon: float, radius_m: int = 10000, limit: int = 10):
        """
        Obtiene múltiples ubicaciones cercanas con sus mediciones de AQI.
        Retorna una lista de zonas con coordenadas, AQI y contaminantes.
        """
        headers = {
            "X-API-Key": os.environ.get("OPENAQ_API_KEY", "")
        }
        
        try:
            # Paso 1: Buscar ubicaciones cercanas
            locations_url = f"{OPENAQ_API_BASE}/locations"
            params = {
                "coordinates": f"{lat},{lon}",
                "radius": radius_m,
                "limit": limit,
            }
            
            logger.info(f"Requesting nearby locations: {locations_url} with params: {params}")
            r = requests.get(locations_url, params=params, headers=headers, timeout=10)
            r.raise_for_status()
            
            locations = r.json().get("results", [])
            logger.info(f"Found {len(locations)} nearby locations")
            
            results = []
            
            for location in locations:
                location_id = location["id"]
                location_name = location.get("name", "Unknown")
                locality = location.get("locality", "")
                distance = location.get("distance")
                coords = location.get("coordinates", {})
                
                # Crear mapeo de sensores
                sensor_map = {}
                for sensor in location.get("sensors", []):
                    sensor_id = sensor.get("id")
                    param_name = sensor.get("parameter", {}).get("name")
                    if sensor_id and param_name:
                        sensor_map[sensor_id] = param_name
                
                # Obtener mediciones
                try:
                    latest_url = f"{OPENAQ_API_BASE}/locations/{location_id}/latest"
                    r2 = requests.get(latest_url, headers=headers, timeout=10)
                    r2.raise_for_status()
                    
                    latest_data = r2.json()
                    measurements = latest_data.get("results", [])
                    
                    # Extraer valores
                    values = {}
                    for measurement in measurements:
                        sensor_id = measurement.get("sensorsId")
                        value = measurement.get("value")
                        param_name = sensor_map.get(sensor_id)
                        
                        if param_name and value is not None and param_name not in values:
                            values[param_name] = value
                    
                    # Calcular AQI
                    aqi = _aqi_from_pollutants(values)
                    
                    # Determinar categoría
                    if aqi <= 50:
                        category = "Bueno"
                        color = "#00e400"
                    elif aqi <= 100:
                        category = "Moderado"
                        color = "#ffff00"
                    elif aqi <= 150:
                        category = "Dañino para grupos sensibles"
                        color = "#ff7e00"
                    elif aqi <= 200:
                        category = "Dañino"
                        color = "#ff0000"
                    elif aqi <= 300:
                        category = "Muy dañino"
                        color = "#8f3f97"
                    else:
                        category = "Peligroso"
                        color = "#7e0023"
                    
                    # Radio aproximado para visualización (500m por defecto)
                    display_radius = 500
                    
                    results.append({
                        "id": location_id,
                        "name": location_name,
                        "locality": locality,
                        "coordinates": {
                            "lat": coords.get("latitude"),
                            "lon": coords.get("longitude")
                        },
                        "distance_meters": round(distance, 2) if distance else None,
                        "aqi": aqi,
                        "category": category,
                        "color": color,
                        "radius_meters": display_radius,
                        "pollutants": {
                            "pm25": values.get("pm25"),
                            "pm10": values.get("pm10"),
                            "o3": values.get("o3"),
                            "no2": values.get("no2"),
                            "co": values.get("co"),
                            "so2": values.get("so2"),
                        }
                    })
                    
                    logger.info(f"Location {location_name}: AQI={aqi}, Distance={distance}m")
                    
                except Exception as e:
                    logger.error(f"Error getting measurements for location {location_id}: {str(e)}")
                    continue
            
            return results
            
        except requests.exceptions.RequestException as e:
            logger.error(f"OpenAQ API request failed: {str(e)}")
            return []
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}", exc_info=True)
            return []