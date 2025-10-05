# Vista de Calidad del Aire (AQI) - Documentación

## 📱 Nueva Estructura de la Aplicación

Se ha creado una nueva vista inicial de **Air Quality Index (AQI)** que muestra información de calidad del aire en tiempo real, similar a la interfaz de la aplicación de referencia.

## 🗂️ Archivos Creados

### 1. **AirQuality.swift**
Ubicación: `UI/AcessNet/Shared/Models/AirQuality.swift`

Contiene los modelos de datos:
- `AirQualityData`: Modelo principal con datos de AQI, PM2.5, PM10, clima, etc.
- `AQILevel`: Niveles de calidad del aire (Good, Moderate, Poor, etc.)
- `WeatherCondition`: Condiciones climáticas

### 2. **AQIHomeView.swift**
Ubicación: `UI/AcessNet/Features/AirQuality/Views/AQIHomeView.swift`

Vista principal de calidad del aire que incluye:
- **Header**: Ubicación actual con botón de navegación al mapa
- **AQI Card**: Indicador principal del índice de calidad del aire
- **PM Indicators**: Indicadores de PM2.5 y PM10
- **AQI Scale Bar**: Barra de escala visual con colores
- **Weather Card**: Temperatura, humedad, viento y UV index
- **Weather Forecast**: Sección de pronóstico (placeholder)

### 3. **MainTabView.swift**
Ubicación: `UI/AcessNet/Features/AirQuality/Views/MainTabView.swift`

Tab bar personalizada con 5 pestañas:
- 🌡️ **Climate Change** (Coming Soon)
- 🏠 **Home** (AQI Home View)
- 💻 **Devices** (Coming Soon)
- 🗺️ **Map** (Vista de mapa existente - ContentView)
- 📊 **Ranking** (Coming Soon)

## 🔄 Modificaciones a Archivos Existentes

### AcessNetApp.swift
Se cambió la vista inicial de `ContentView()` a `MainTabView()`:

```swift
var body: some Scene {
    WindowGroup {
        MainTabView()
    }
}
```

## 🎨 Características Principales

### Navegación al Mapa
- Desde la vista de AQI Home, hay un botón "Map" en el header que navega al mapa existente
- El mapa también está disponible en el tab bar inferior

### Diseño Responsive
- Gradientes de color basados en el nivel de AQI
- Animaciones suaves
- Material effects (frosted glass)
- Adaptable a diferentes tamaños de pantalla

### Niveles de AQI y Colores

| Nivel | Rango AQI | Color de Fondo |
|-------|-----------|----------------|
| Good | 0-50 | Verde (#B8E986) |
| Moderate | 51-100 | Amarillo (#FFD54F) |
| Poor | 101-150 | Naranja (#FFB74D) |
| Unhealthy | 151-200 | Rojo (#EF5350) |
| Severe | 201-300 | Morado (#AB47BC) |
| Hazardous | 301+ | Morado Oscuro (#880E4F) |

## 🧪 Datos de Prueba

Actualmente la app usa datos de muestra definidos en `AirQualityData.sample`:
- AQI: 75 (Moderate)
- PM2.5: 22 μg/m³
- PM10: 66 μg/m³
- Ubicación: Atmosphere Science Center, Mexico City
- Clima: 18°C, Overcast

## 🚀 Próximos Pasos

1. **Integrar API de Calidad del Aire**: Conectar con una API real (OpenAQ, IQAir, etc.)
2. **Implementar Weather Forecast**: Mostrar pronóstico horario y diario
3. **Agregar Location Services**: Detectar ubicación del usuario automáticamente
4. **Completar vistas placeholder**: Climate Change, Devices, Ranking
5. **Agregar Assets**: Logo AQI personalizado y mascota animada

## 📝 Uso

Para navegar al mapa desde la vista de AQI:
1. Toca el botón "Map" en el header superior derecho, o
2. Toca el tab "Map" en la barra inferior

La navegación está configurada para mantener el estado de ambas vistas.

## 🎯 Componentes Reutilizables

- `PMIndicator`: Muestra indicadores de PM2.5/PM10
- `AQIScaleBar`: Barra de escala visual con indicador de posición
- `WeatherInfoItem`: Item individual de información climática
- `ForecastTabButton`: Botón de tab para pronóstico
- `CustomTabBar`: Tab bar personalizada inferior
- `TabBarButton`: Botón individual del tab bar

## 🔧 Extensiones Creadas

- `Color.init(hex:)`: Inicializar colores desde strings hexadecimales

---

**Desarrollado con Claude Code** 🤖
