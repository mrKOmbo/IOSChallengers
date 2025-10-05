//
//  AirQualityGridManager.swift
//  AcessNet
//
//  Generador y gestor de grid dinámico de zonas de calidad del aire
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

// MARK: - Air Quality Grid Manager

/// Gestor del grid de zonas de calidad del aire que se actualiza dinámicamente
class AirQualityGridManager: ObservableObject {

    // MARK: - Published Properties

    /// Zonas actuales de calidad del aire
    @Published private(set) var zones: [AirQualityZone] = []

    /// Indica si está calculando el grid
    @Published private(set) var isCalculating: Bool = false

    /// Centro actual del grid
    @Published private(set) var currentCenter: CLLocationCoordinate2D?

    // MARK: - Private Properties

    /// Configuración del grid
    private var config: AirQualityGridConfig

    /// Generador de datos de calidad del aire
    private let dataGenerator = AirQualityDataGenerator.shared

    /// Timestamp del último cálculo
    private var lastCalculation: Date?

    /// Timer para actualizaciones periódicas
    private var updateTimer: Timer?

    /// Queue para cálculos en background
    private let calculationQueue = DispatchQueue(label: "com.acessnet.airqualitygrid", qos: .userInitiated)

    /// Distancia mínima para recalcular (en metros)
    private let minimumDistanceForUpdate: CLLocationDistance = 500

    // MARK: - Initialization

    init(config: AirQualityGridConfig = .default) {
        self.config = config
    }

    deinit {
        stopAutoUpdate()
    }

    // MARK: - Public Methods

    /// Actualiza el grid con un nuevo centro
    /// - Parameter center: Coordenada central del grid
    func updateGrid(center: CLLocationCoordinate2D) {
        // Verificar si es necesario actualizar
        guard shouldUpdate(for: center) else {
            return
        }

        // Marcar como calculando
        DispatchQueue.main.async {
            self.isCalculating = true
        }

        // Calcular grid en background
        calculationQueue.async { [weak self] in
            guard let self = self else { return }

            let newZones = self.calculateGrid(center: center)

            // Actualizar en main thread
            DispatchQueue.main.async {
                self.zones = newZones
                self.currentCenter = center
                self.lastCalculation = Date()
                self.isCalculating = false

                print("🌍 Grid actualizado: \(newZones.count) zonas generadas")
                self.logGridStatistics()
            }
        }
    }

    /// Limpia todas las zonas
    func clearGrid() {
        DispatchQueue.main.async {
            self.zones = []
            self.currentCenter = nil
            self.lastCalculation = nil
        }
    }

    /// Inicia actualizaciones automáticas cada X segundos
    /// - Parameter interval: Intervalo en segundos (por defecto usa config.cacheTime)
    func startAutoUpdate(center: CLLocationCoordinate2D, interval: TimeInterval? = nil) {
        stopAutoUpdate()

        let updateInterval = interval ?? config.cacheTime

        // Actualizar inmediatamente
        updateGrid(center: center)

        // Configurar timer para actualizaciones periódicas
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self, let currentCenter = self.currentCenter else { return }
            self.updateGrid(center: currentCenter)
        }

        print("⏰ Auto-update iniciado (cada \(Int(updateInterval))s)")
    }

    /// Detiene las actualizaciones automáticas
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Obtiene la zona más cercana a una coordenada
    /// - Parameter coordinate: Coordenada a buscar
    /// - Returns: Zona más cercana o nil
    func nearestZone(to coordinate: CLLocationCoordinate2D) -> AirQualityZone? {
        guard !zones.isEmpty else { return nil }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return zones.min { zone1, zone2 in
            let loc1 = CLLocation(latitude: zone1.coordinate.latitude, longitude: zone1.coordinate.longitude)
            let loc2 = CLLocation(latitude: zone2.coordinate.latitude, longitude: zone2.coordinate.longitude)

            return location.distance(from: loc1) < location.distance(from: loc2)
        }
    }

    /// Filtra zonas por nivel de calidad
    /// - Parameter level: Nivel de AQI a filtrar
    /// - Returns: Zonas con ese nivel
    func zones(withLevel level: AQILevel) -> [AirQualityZone] {
        return zones.filter { $0.level == level }
    }

    /// Actualiza la configuración del grid
    /// - Parameter newConfig: Nueva configuración
    func updateConfiguration(_ newConfig: AirQualityGridConfig) {
        self.config = newConfig

        // Recalcular grid si hay un centro
        if let center = currentCenter {
            updateGrid(center: center)
        }
    }

    // MARK: - Private Methods

    /// Determina si se debe actualizar el grid
    private func shouldUpdate(for center: CLLocationCoordinate2D) -> Bool {
        // Si no hay centro previo, actualizar
        guard let previousCenter = currentCenter else {
            return true
        }

        // Verificar distancia desde último centro
        let previousLocation = CLLocation(latitude: previousCenter.latitude, longitude: previousCenter.longitude)
        let newLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let distance = previousLocation.distance(from: newLocation)

        if distance >= minimumDistanceForUpdate {
            print("📍 Movimiento detectado: \(Int(distance))m (mín: \(Int(minimumDistanceForUpdate))m)")
            return true
        }

        // Verificar tiempo desde último cálculo
        if let lastCalc = lastCalculation {
            let timeSinceLastCalc = Date().timeIntervalSince(lastCalc)
            if timeSinceLastCalc >= config.cacheTime {
                print("⏱️ Cache expirado: \(Int(timeSinceLastCalc))s (max: \(Int(config.cacheTime))s)")
                return true
            }
        }

        return false
    }

    /// Calcula el grid de zonas
    /// - Parameter center: Centro del grid
    /// - Returns: Array de zonas
    private func calculateGrid(center: CLLocationCoordinate2D) -> [AirQualityZone] {
        var zones: [AirQualityZone] = []

        let halfSize = config.gridSize / 2
        let metersPerDegreeLatitude = 111_000.0  // Aproximadamente 111km por grado de latitud

        // Calcular en grados
        let latDegreePerMeter = 1.0 / metersPerDegreeLatitude
        let lonDegreePerMeter = 1.0 / (metersPerDegreeLatitude * cos(center.latitude * .pi / 180))

        let latSpacing = config.spacing * latDegreePerMeter
        let lonSpacing = config.spacing * lonDegreePerMeter

        // Generar grid NxN
        for i in -halfSize...halfSize {
            for j in -halfSize...halfSize {
                let lat = center.latitude + (Double(i) * latSpacing)
                let lon = center.longitude + (Double(j) * lonSpacing)

                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                // Generar datos de calidad del aire para este punto
                let airQuality = dataGenerator.generateAirQuality(
                    for: coordinate,
                    includeExtendedMetrics: false
                )

                // Crear zona
                let zone = AirQualityZone(
                    coordinate: coordinate,
                    radius: config.zoneRadius,
                    airQuality: airQuality
                )

                zones.append(zone)
            }
        }

        return zones
    }

    /// Registra estadísticas del grid en consola
    private func logGridStatistics() {
        let goodCount = zones.filter { $0.level == .good }.count
        let moderateCount = zones.filter { $0.level == .moderate }.count
        let poorCount = zones.filter { $0.level == .poor }.count
        let unhealthyCount = zones.filter { $0.level == .unhealthy }.count

        let avgAQI = zones.map { $0.airQuality.aqi }.reduce(0, +) / Double(max(zones.count, 1))

        print("""
        📊 Estadísticas del Grid:
           - Total zonas: \(zones.count)
           - AQI promedio: \(Int(avgAQI))
           - 🟢 Good: \(goodCount)
           - 🟡 Moderate: \(moderateCount)
           - 🟠 Poor: \(poorCount)
           - 🔴 Unhealthy: \(unhealthyCount)
        """)
    }
}

// MARK: - Grid Statistics

extension AirQualityGridManager {
    /// Estadísticas del grid actual
    struct GridStatistics {
        let totalZones: Int
        let averageAQI: Double
        let goodCount: Int
        let moderateCount: Int
        let poorCount: Int
        let unhealthyCount: Int
        let severeCount: Int
        let hazardousCount: Int

        var dominantLevel: AQILevel {
            let counts = [
                (AQILevel.good, goodCount),
                (AQILevel.moderate, moderateCount),
                (AQILevel.poor, poorCount),
                (AQILevel.unhealthy, unhealthyCount),
                (AQILevel.severe, severeCount),
                (AQILevel.hazardous, hazardousCount)
            ]

            return counts.max { $0.1 < $1.1 }?.0 ?? .good
        }
    }

    /// Calcula estadísticas del grid actual
    func getStatistics() -> GridStatistics {
        return GridStatistics(
            totalZones: zones.count,
            averageAQI: zones.isEmpty ? 0 : zones.map { $0.airQuality.aqi }.reduce(0, +) / Double(zones.count),
            goodCount: zones.filter { $0.level == .good }.count,
            moderateCount: zones.filter { $0.level == .moderate }.count,
            poorCount: zones.filter { $0.level == .poor }.count,
            unhealthyCount: zones.filter { $0.level == .unhealthy }.count,
            severeCount: zones.filter { $0.level == .severe }.count,
            hazardousCount: zones.filter { $0.level == .hazardous }.count
        )
    }
}
