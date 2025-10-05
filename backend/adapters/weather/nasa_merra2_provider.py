# backend/adapters/weather/nasa_merra2_provider.py
import os
import earthaccess
import xarray as xr
import numpy as np
from datetime import datetime, timezone, timedelta
from django.core.cache import cache
import logging
import tempfile

logger = logging.getLogger(__name__)

class NASAMERRA2Provider:
    """
    Proveedor de datos meteorológicos históricos usando NASA MERRA-2.
    Procesa archivos NetCDF con xarray y earthaccess.
    """
    
    def __init__(self, ttl=86400):
        self.ttl = ttl  # Cache por 24 horas
        self.earthdata_username = os.environ.get("EARTHDATA_USERNAME", "")
        self.earthdata_password = os.environ.get("EARTHDATA_PASSWORD", "")
        self.authenticated = False
    
    def _authenticate(self):
        """Autentica con NASA Earthdata"""
        if self.authenticated:
            return True
    
        if not self.earthdata_username or not self.earthdata_password:
            logger.error("NASA Earthdata credentials not configured")
            return False
    
        try:
            os.environ['EARTHDATA_USERNAME'] = self.earthdata_username
            os.environ['EARTHDATA_PASSWORD'] = self.earthdata_password
        
            # Login que inicializa el store
            logger.info("Authenticating with NASA Earthdata...")
            auth = earthaccess.login(persist=False)
        
            if auth and hasattr(auth, 'authenticated') and auth.authenticated:
                self.authenticated = True
                logger.info(f"NASA Earthdata authentication successful. Store initialized: {earthaccess.__store__ is not None}")
                return True
        
            logger.error("NASA Earthdata authentication failed - auth object not valid")
            return False
        
        except Exception as e:
            logger.error(f"NASA Earthdata authentication error: {str(e)}")
            return False
    
    def _find_closest_grid_point(self, dataset, lat, lon):
        """
        Encuentra el punto más cercano en la grilla de MERRA-2.
        MERRA-2 tiene resolución de 0.5° lat x 0.625° lon.
        """
        # MERRA-2 usa lat/lon en el rango [-90, 90] y [-180, 180]
        lat_diff = np.abs(dataset.lat.values - lat)
        lon_diff = np.abs(dataset.lon.values - lon)
        
        lat_idx = lat_diff.argmin()
        lon_idx = lon_diff.argmin()
        
        closest_lat = dataset.lat.values[lat_idx]
        closest_lon = dataset.lon.values[lon_idx]
        
        logger.info(f"Requested: {lat},{lon} -> Closest grid point: {closest_lat},{closest_lon}")
        
        return lat_idx, lon_idx
    
    def get_historical_weather(self, lat: float, lon: float, start_date: str, end_date: str):
        """
        Obtiene datos meteorológicos históricos de MERRA-2.
        
        Args:
            lat: Latitud (-90 a 90)
            lon: Longitud (-180 a 180)
            start_date: Fecha inicio (YYYY-MM-DD)
            end_date: Fecha fin (YYYY-MM-DD)
        
        Returns:
            Datos históricos de temperatura, humedad, viento, precipitación
        """
        logger.info(f"Fetching MERRA-2 data for {lat},{lon} from {start_date} to {end_date}")
        
        cache_key = f"merra2:{lat:.4f}:{lon:.4f}:{start_date}:{end_date}"
        cached = cache.get(cache_key)
        if cached:
            logger.info(f"Cache hit for MERRA-2: {cache_key}")
            return cached
        
        # Autenticar
        if not self._authenticate():
            return {
                "error": "NASA Earthdata authentication failed",
                "message": "Check NASA_EARTHDATA_USERNAME and NASA_EARTHDATA_PASSWORD"
            }
        
        try:
            # Convertir fechas
            start_dt = datetime.strptime(start_date, "%Y-%m-%d")
            end_dt = datetime.strptime(end_date, "%Y-%m-%d")
            
            # MERRA-2 tiene datos desde 1980-01-01
            if start_dt.year < 1980:
                return {"error": "MERRA-2 data starts from 1980-01-01"}
            
            # Limitar rango de fechas (máximo 31 días por request)
            days_diff = (end_dt - start_dt).days
            if days_diff > 31:
                return {"error": "Date range too large. Maximum: 31 days"}
            
            # Buscar datasets de MERRA-2
            # M2T1NXSLV: Single-Level Diagnostics (temperatura, humedad, viento, precipitación)
            logger.info("Searching for MERRA-2 datasets...")
            
            results = earthaccess.search_data(
                short_name="M2T1NXSLV",
                cloud_hosted=True,
                temporal=(start_date, end_date),
            )
            
            if not results:
                logger.error("No MERRA-2 data found for the specified date range")
                return {"error": "No data found for the specified date range"}
            
            logger.info(f"Found {len(results)} MERRA-2 files")
            
            # Abrir datasets (earthaccess puede streamear desde S3)
            logger.info("Opening MERRA-2 files...")
            files = earthaccess.open(results)
            
            # Combinar todos los archivos en un solo dataset
            ds = xr.open_mfdataset(files, combine='by_coords', engine='h5netcdf')
            
            logger.info(f"Dataset variables: {list(ds.data_vars)}")
            
            # Encontrar punto más cercano en la grilla
            lat_idx, lon_idx = self._find_closest_grid_point(ds, lat, lon)
            
            # Extraer datos para el punto específico
            point_data = ds.isel(lat=lat_idx, lon=lon_idx)
            
            # Procesar variables meteorológicas
            time_series = []
            
            for time_val in point_data.time.values:
                time_dt = datetime.utcfromtimestamp(time_val.astype('O') / 1e9)
                
                data_point = {
                    "timestamp": time_dt.isoformat() + "Z",
                    "temperature_2m": float(point_data.sel(time=time_val)['T2M'].values) - 273.15,  # Kelvin a Celsius
                    "humidity_2m": float(point_data.sel(time=time_val)['QV2M'].values) * 1000,  # kg/kg a g/kg
                    "wind_speed_10m": {
                        "u": float(point_data.sel(time=time_val)['U10M'].values),  # m/s
                        "v": float(point_data.sel(time=time_val)['V10M'].values),  # m/s
                    },
                    "pressure_surface": float(point_data.sel(time=time_val)['PS'].values) / 100,  # Pa a hPa
                    "precipitation_total": float(point_data.sel(time=time_val)['PRECTOT'].values) * 3600,  # kg/m2/s a mm/h
                }
                
                # Calcular velocidad del viento total
                wind_speed = np.sqrt(data_point["wind_speed_10m"]["u"]**2 + data_point["wind_speed_10m"]["v"]**2)
                data_point["wind_speed_total"] = float(wind_speed)
                
                # Calcular dirección del viento
                wind_dir = np.arctan2(data_point["wind_speed_10m"]["v"], data_point["wind_speed_10m"]["u"]) * 180 / np.pi
                data_point["wind_direction"] = float((wind_dir + 360) % 360)
                
                time_series.append(data_point)
            
            # Cerrar dataset
            ds.close()
            
            # Calcular estadísticas
            temps = [d["temperature_2m"] for d in time_series]
            precips = [d["precipitation_total"] for d in time_series]
            
            result = {
                "source": "NASA MERRA-2",
                "location": {
                    "requested": {"lat": lat, "lon": lon},
                    "actual_grid_point": {
                        "lat": float(ds.lat.values[lat_idx]),
                        "lon": float(ds.lon.values[lon_idx])
                    }
                },
                "period": {
                    "start": start_date,
                    "end": end_date,
                    "total_hours": len(time_series)
                },
                "statistics": {
                    "temperature": {
                        "mean": round(np.mean(temps), 2),
                        "max": round(np.max(temps), 2),
                        "min": round(np.min(temps), 2),
                        "std": round(np.std(temps), 2),
                    },
                    "precipitation": {
                        "total": round(np.sum(precips), 2),
                        "mean": round(np.mean(precips), 2),
                        "max": round(np.max(precips), 2),
                    }
                },
                "time_series": time_series
            }
            
            cache.set(cache_key, result, timeout=self.ttl)
            return result
            
        except Exception as e:
            logger.error(f"MERRA-2 processing error: {str(e)}", exc_info=True)
            return {
                "error": "Failed to process MERRA-2 data",
                "details": str(e)
            }