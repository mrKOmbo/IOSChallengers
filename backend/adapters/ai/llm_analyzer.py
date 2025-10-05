import os
import json
from groq import Groq

class AirQualityLLMAnalyzer:
    """
    Usa Groq (Llama 3.1) GRATIS para analizar calidad del aire.
    """
    
    def __init__(self):
        self.client = Groq(api_key=os.getenv('GROQ_API_KEY'))
        self.model = "llama-3.1-70b-versatile"  # GRATIS y potente
    
    def analyze_forecast(self, current_data: dict, forecast_data: dict, location: dict):
        """Analiza predicción con LLM gratuito"""
        
        prompt = self._build_prompt(current_data, forecast_data, location)
        
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "system",
                        "content": """Eres un experto en calidad del aire y salud pública. 
                        Analiza datos de AQI y genera insights útiles en español.
                        Responde SOLO con JSON válido."""
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                temperature=0.3,
                max_tokens=800,
            )
            
            # Extraer JSON del response
            content = response.choices[0].message.content
            # Limpiar si viene con ```json
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0].strip()
            elif "```" in content:
                content = content.split("```")[1].split("```")[0].strip()
            
            result = json.loads(content)
            return result
            
        except Exception as e:
            return {
                "error": f"Error al analizar: {str(e)}",
                "fallback": True
            }
    
    def _build_prompt(self, current_data: dict, forecast_data: dict, location: dict):
        """Prompt optimizado"""
        
        return f"""
Analiza estos datos de calidad del aire para {location.get('name', 'esta ubicación')}:

ACTUAL:
- AQI: {current_data.get('aqi', 'N/A')}
- PM2.5: {current_data.get('pm25', 'N/A')} μg/m³
- PM10: {current_data.get('pm10', 'N/A')} μg/m³

PREDICCIÓN 24H:
- AQI promedio: {forecast_data.get('forecast_24h', {}).get('avg_aqi', 'N/A')}
- AQI máximo: {forecast_data.get('forecast_24h', {}).get('max_aqi', 'N/A')}

Responde SOLO con este JSON (sin markdown):
{{
  "resumen": "Resumen en 2 líneas",
  "tendencia": "mejorando|empeorando|estable",
  "nivel_riesgo": "bajo|moderado|alto|muy_alto",
  "recomendaciones": ["Recomendación 1", "Recomendación 2", "Recomendación 3"],
  "mejor_horario": "Mejor hora para salir",
  "peor_horario": "Hora a evitar",
  "alerta": "Mensaje de alerta o null"
}}
"""