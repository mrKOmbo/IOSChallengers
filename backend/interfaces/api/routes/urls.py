# backend/interfaces/api/routes/urls.py
from django.urls import path
from .views import CurrentAQIView, HealthCheckView, NearbyAirQualityView, AirQualityForecastView, CurrentWeatherView, WeatherForecastView, HistoricalWeatherView, AirQualityAIAnalysisView

urlpatterns = [
    path("healthz", HealthCheckView.as_view(), name="health-check"),
    
    path("air/current", CurrentAQIView.as_view(), name="air-current"),
    path("air/nearby", NearbyAirQualityView.as_view(), name="air-nearby"),
    path("air/forecast", AirQualityForecastView.as_view(), name="air-forecast"),
    path("air/ai-analysis", AirQualityAIAnalysisView.as_view(), name="air-ai-analysis"),

    path("weather/current", CurrentWeatherView.as_view(), name="weather-current"),
    path("weather/forecast", WeatherForecastView.as_view(), name="weather-forecast"),
    path("weather/historical", HistoricalWeatherView.as_view(), name="weather-historical"),
]
