//
//  AirQualityDataGenerator.swift
//  AcessNet
//
//  Generador de datos de calidad del aire simulados con algoritmos realistas
//

import Foundation
import CoreLocation

// MARK: - Air Quality Data Generator

/// Generador inteligente de datos de calidad del aire simulados
class AirQualityDataGenerator {

    // MARK: - Singleton

    static let shared = AirQualityDataGenerator()

    private init() {}

    // MARK: - Public Methods

    /// Genera datos de calidad del aire para una ubicación específica
    /// - Parameters:
    ///   - coordinate: Coordenada geográfica
    ///   - includeExtendedMetrics: Si se deben incluir métricas extendidas (NO2, O3, CO, SO2)
    /// - Returns: Datos completos de calidad del aire
    func generateAirQuality(
        for coordinate: CLLocationCoordinate2D,
        includeExtendedMetrics: Bool = false
    ) -> AirQualityPoint {

        // 1. Calcular AQI base según zona geográfica
        let baseAQI = calculateBaseAQI(for: coordinate)

        // 2. Aplicar factor temporal (hora del día, día de la semana)
        let temporalFactor = calculateTemporalFactor()

        // 3. Aplicar variación aleatoria controlada (para realismo)
        let variation = calculateVariation(for: coordinate)

        // 4. Calcular AQI final
        let finalAQI = baseAQI * temporalFactor * variation
        let clampedAQI = max(10, min(250, finalAQI)) // Limitar entre 10 y 250

        // 5. Generar contaminantes correlacionados
        let pm25 = calculatePM25(from: clampedAQI)
        let pm10 = calculatePM10(from: pm25)

        // 6. Generar métricas extendidas si se solicitan
        var no2: Double? = nil
        var o3: Double? = nil
        var co: Double? = nil
        var so2: Double? = nil
        var aod: Double? = nil

        if includeExtendedMetrics {
            no2 = calculateNO2(from: clampedAQI)
            o3 = calculateO3(from: clampedAQI)
            co = calculateCO(from: clampedAQI)
            so2 = calculateSO2(from: clampedAQI)
            aod = calculateAOD(from: clampedAQI)
        }

        return AirQualityPoint(
            coordinate: coordinate,
            aqi: clampedAQI,
            pm25: pm25,
            pm10: pm10,
            no2: no2,
            o3: o3,
            co: co,
            so2: so2,
            aod: aod,
            timestamp: Date()
        )
    }

    // MARK: - Private Calculation Methods

    /// Calcula el AQI base según la zona geográfica
    private func calculateBaseAQI(for coordinate: CLLocationCoordinate2D) -> Double {
        // Usar hash de coordenadas para determinar "zona" (consistente por ubicación)
        let latHash = Int(abs(coordinate.latitude * 1000)) % 100
        let lonHash = Int(abs(coordinate.longitude * 1000)) % 100
        let zoneHash = (latHash + lonHash) % 100

        // Determinar tipo de zona según hash
        switch zoneHash {
        case 0..<20:
            // Zona Rural Limpia (20%)
            return Double.random(in: 15...40)
        case 20..<45:
            // Zona Suburbana (25%)
            return Double.random(in: 30...70)
        case 45..<75:
            // Zona Urbana Media (30%)
            return Double.random(in: 50...100)
        case 75..<90:
            // Zona Urbana Alta Contaminación (15%)
            return Double.random(in: 80...130)
        default:
            // Zona Industrial/Crítica (10%)
            return Double.random(in: 100...150)
        }
    }

    /// Calcula el factor temporal (hora del día, día de la semana)
    private func calculateTemporalFactor() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        var factor: Double = 1.0

        // Factor por hora del día
        switch hour {
        case 7...9, 17...19:
            // Horas pico (morning/evening rush)
            factor *= 1.35
        case 10...16:
            // Horas medias del día
            factor *= 1.15
        case 0...5:
            // Madrugada (menos tráfico)
            factor *= 0.75
        default:
            // Resto del día
            factor *= 1.0
        }

        // Factor por día de la semana
        if weekday == 1 || weekday == 7 {
            // Fin de semana (menos actividad industrial/tráfico)
            factor *= 0.85
        }

        return factor
    }

    /// Calcula variación aleatoria controlada para realismo
    private func calculateVariation(for coordinate: CLLocationCoordinate2D) -> Double {
        // Usar coordenadas como seed para consistencia (misma ubicación = misma variación)
        let seed = Int(abs(coordinate.latitude * 10000 + coordinate.longitude * 10000))
        var generator = SeededRandomNumberGenerator(seed: seed)

        // Variación del ±15%
        return Double.random(in: 0.85...1.15, using: &generator)
    }

    // MARK: - Pollutant Calculation Methods

    /// Calcula PM2.5 basado en AQI
    /// Fórmula: PM2.5 ≈ AQI × 0.45 (aproximación simplificada)
    private func calculatePM25(from aqi: Double) -> Double {
        let basePM25 = aqi * 0.45
        let variation = Double.random(in: 0.9...1.1)
        return max(0, basePM25 * variation)
    }

    /// Calcula PM10 basado en PM2.5
    /// PM10 suele ser 2-3x mayor que PM2.5
    private func calculatePM10(from pm25: Double) -> Double {
        let multiplier = Double.random(in: 2.2...2.8)
        return pm25 * multiplier
    }

    /// Calcula NO2 (Nitrogen Dioxide) en ppb
    /// Correlación con AQI, valores típicos: 10-100 ppb
    private func calculateNO2(from aqi: Double) -> Double {
        let baseNO2 = aqi * 0.3 + 15
        let variation = Double.random(in: 0.85...1.15)
        return max(5, min(150, baseNO2 * variation))
    }

    /// Calcula O3 (Ozone) en ppb
    /// Valores típicos: 20-120 ppb
    private func calculateO3(from aqi: Double) -> Double {
        let baseO3 = aqi * 0.4 + 20
        let variation = Double.random(in: 0.9...1.1)
        return max(10, min(180, baseO3 * variation))
    }

    /// Calcula CO (Carbon Monoxide) en ppm
    /// Valores típicos: 0.5-5 ppm
    private func calculateCO(from aqi: Double) -> Double {
        let baseCO = aqi * 0.02 + 0.3
        let variation = Double.random(in: 0.85...1.15)
        return max(0.1, min(10, baseCO * variation))
    }

    /// Calcula SO2 (Sulfur Dioxide) en ppb
    /// Valores típicos: 5-50 ppb
    private func calculateSO2(from aqi: Double) -> Double {
        let baseSO2 = aqi * 0.15 + 8
        let variation = Double.random(in: 0.9...1.1)
        return max(2, min(100, baseSO2 * variation))
    }

    /// Calcula AOD (Aerosol Optical Depth) - dato de satélite NASA
    /// Valores típicos: 0.01-0.5
    private func calculateAOD(from aqi: Double) -> Double {
        let baseAOD = aqi / 500.0  // Normalizar a 0-0.5
        let variation = Double.random(in: 0.9...1.1)
        return max(0.01, min(1.0, baseAOD * variation))
    }
}

// MARK: - Seeded Random Number Generator

/// Generador de números aleatorios con seed (para consistencia)
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(truncatingIfNeeded: seed)
    }

    mutating func next() -> UInt64 {
        // Linear Congruential Generator (simple pero efectivo)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
