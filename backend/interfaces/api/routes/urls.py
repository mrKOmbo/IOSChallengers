# backend/interfaces/api/routes/urls.py
from django.urls import path
from .views import CurrentAQIView, HealthCheckView, NearbyAirQualityView, AirQualityForecastView, CurrentWeatherView, WeatherForecastView, HistoricalWeatherView

urlpatterns = [
    
    path("air/current", CurrentAQIView.as_view(), name="air-current"),
    path("air/nearby", NearbyAirQualityView.as_view(), name="air-nearby"),
    path("air/forecast", AirQualityForecastView.as_view(), name="air-forecast"),
    path("healthz", HealthCheckView.as_view(), name="health-check"),

    path("weather/current", CurrentWeatherView.as_view(), name="weather-current"),
    path("weather/forecast", WeatherForecastView.as_view(), name="weather-forecast"),
    path("weather/historical", HistoricalWeatherView.as_view(), name="weather-historical"),
]
