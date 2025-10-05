//
//  RouteOptimizer.swift
//  AcessNet
//
//  Sistema avanzado de optimización de rutas con análisis multi-criterio
//  Integra incidentes, calidad del aire y preferencias del usuario
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Route Optimizer

/// Motor de optimización inteligente de rutas
class RouteOptimizer: ObservableObject {

    // MARK: - Types

    /// Zona de evitación (combina incidentes + aire malo)
    struct AvoidanceZone {
        let center: CLLocationCoordinate2D
        let radius: CLLocationDistance  // En metros
        let severity: Double            // 0-1 (1 = máxima severidad)
        let type: AvoidanceType
        let reason: String

        enum AvoidanceType {
            case incident(AlertType)
            case airQuality(AQILevel)
            case combined
            case temporal  // Zonas temporales (hora punta, eventos)
        }
    }

    /// Segmento de ruta evaluado
    struct EvaluatedSegment {
        let startCoordinate: CLLocationCoordinate2D
        let endCoordinate: CLLocationCoordinate2D
        let distance: CLLocationDistance
        let estimatedTime: TimeInterval
        let safetyScore: Double      // 0-100
        let airQualityScore: Double  // 0-100
        let overallScore: Double     // 0-100
        let hazards: [String]         // Descripción de peligros en el segmento
    }

    /// Configuración de optimización
    struct OptimizationConfig {
        var timeWeight: Double = 0.4
        var safetyWeight: Double = 0.3
        var airQualityWeight: Double = 0.3
        var avoidHighways: Bool = false
        var considerTrafficPatterns: Bool = true
        var predictiveAnalysis: Bool = true
        var maxAlternatives: Int = 3

        static let balanced = OptimizationConfig()

        static let fastest = OptimizationConfig(
            timeWeight: 0.8,
            safetyWeight: 0.1,
            airQualityWeight: 0.1
        )

        static let safest = OptimizationConfig(
            timeWeight: 0.2,
            safetyWeight: 0.6,
            airQualityWeight: 0.2
        )

        static let healthiest = OptimizationConfig(
            timeWeight: 0.2,
            safetyWeight: 0.3,
            airQualityWeight: 0.5
        )
    }

    // MARK: - Properties

    @Published var avoidanceZones: [AvoidanceZone] = []
    @Published var isOptimizing: Bool = false
    @Published var optimizationProgress: Double = 0.0

    private var config: OptimizationConfig
    private let calculationQueue = DispatchQueue(label: "com.acessnet.routeoptimizer", qos: .userInitiated)

    // Data sources
    private var activeIncidents: [CustomAnnotation] = []
    private var airQualityZones: [AirQualityZone] = []

    // MARK: - Initialization

    init(config: OptimizationConfig = .balanced) {
        self.config = config
    }

    // MARK: - Public Methods

    /// Actualiza los datos de entrada para la optimización
    func updateData(
        incidents: [CustomAnnotation],
        airQualityZones: [AirQualityZone]
    ) {
        self.activeIncidents = incidents
        self.airQualityZones = airQualityZones

        // Recalcular zonas de evitación
        Task {
            await calculateAvoidanceZones()
        }
    }

    /// Optimiza rutas con análisis avanzado
    @MainActor
    func optimizeRoutes(
        routes: [RouteInfo],
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> [ScoredRoute] {

        isOptimizing = true
        optimizationProgress = 0.0

        var optimizedRoutes: [ScoredRoute] = []

        for (index, route) in routes.enumerated() {
            // Actualizar progreso
            optimizationProgress = Double(index) / Double(routes.count)

            // Evaluar cada segmento de la ruta
            let segments = await evaluateRouteSegments(route: route)

            // Calcular scores agregados
            let avgSafetyScore = segments.map { $0.safetyScore }.reduce(0, +) / Double(max(segments.count, 1))
            let avgAirScore = segments.map { $0.airQualityScore }.reduce(0, +) / Double(max(segments.count, 1))

            // Identificar incidentes y problemas de aire en la ruta
            let routeIncidents = findIncidentsNearRoute(route: route)
            let routeAirQuality = analyzeAirQualityForRoute(route: route)

            // Crear análisis de incidentes
            let incidentAnalysis = createIncidentAnalysis(
                incidents: routeIncidents,
                safetyScore: avgSafetyScore
            )

            // Crear ruta optimizada con scoring
            let scoredRoute = ScoredRoute(
                routeInfo: route,
                airQualityAnalysis: routeAirQuality,
                incidentAnalysis: incidentAnalysis,
                fastestTime: route.expectedTravelTime,
                cleanestAQI: routeAirQuality?.averageAQI ?? 50,
                safestSafetyScore: avgSafetyScore,
                preference: mapConfigToPreference(),
                rankPosition: nil
            )

            optimizedRoutes.append(scoredRoute)
        }

        // Ordenar por score combinado
        optimizedRoutes.sort { $0.combinedScore > $1.combinedScore }

        isOptimizing = false
        optimizationProgress = 1.0

        return Array(optimizedRoutes.prefix(config.maxAlternatives))
    }

    /// Calcula zonas de evitación basadas en incidentes y calidad del aire
    @MainActor
    private func calculateAvoidanceZones() async {
        var zones: [AvoidanceZone] = []

        // Crear zonas de evitación para incidentes críticos
        for incident in activeIncidents {
            let severity = calculateIncidentSeverity(incident.alertType)
            let radius = calculateIncidentRadius(incident.alertType)

            if severity > 0.3 {  // Solo crear zona si es significativo
                zones.append(AvoidanceZone(
                    center: incident.coordinate,
                    radius: radius,
                    severity: severity,
                    type: .incident(incident.alertType),
                    reason: "Active \(incident.alertType.rawValue)"
                ))
            }
        }

        // Crear zonas de evitación para aire malo
        for airZone in airQualityZones {
            let severity = calculateAirQualitySeverity(airZone.level)

            if severity > 0.4 {  // Solo si el aire es malo
                zones.append(AvoidanceZone(
                    center: airZone.coordinate,
                    radius: airZone.radius,
                    severity: severity,
                    type: .airQuality(airZone.level),
                    reason: "Poor air quality (AQI: \(Int(airZone.airQuality.aqi)))"
                ))
            }
        }

        // Combinar zonas superpuestas
        zones = combineOverlappingZones(zones)

        // Agregar zonas temporales si está habilitado
        if config.predictiveAnalysis {
            zones.append(contentsOf: await calculateTemporalZones())
        }

        self.avoidanceZones = zones

        print("🚫 Calculadas \(zones.count) zonas de evitación")
    }

    // MARK: - Private Methods

    /// Evalúa los segmentos de una ruta
    private func evaluateRouteSegments(route: RouteInfo) async -> [EvaluatedSegment] {
        let polyline = route.route.polyline
        let coordinates = polyline.coordinates()

        var segments: [EvaluatedSegment] = []
        let segmentLength = 200.0  // Evaluar cada 200 metros

        var currentDistance: CLLocationDistance = 0

        for i in 0..<coordinates.count - 1 {
            let start = coordinates[i]
            let end = coordinates[i + 1]
            let distance = start.distance(to: end)

            // Evaluar segmento
            let safetyScore = evaluateSegmentSafety(from: start, to: end)
            let airScore = evaluateSegmentAirQuality(from: start, to: end)
            let overallScore = calculateOverallScore(safety: safetyScore, air: airScore)

            let hazards = identifySegmentHazards(from: start, to: end)

            segments.append(EvaluatedSegment(
                startCoordinate: start,
                endCoordinate: end,
                distance: distance,
                estimatedTime: distance / 13.89,  // Asumiendo 50 km/h promedio
                safetyScore: safetyScore,
                airQualityScore: airScore,
                overallScore: overallScore,
                hazards: hazards
            ))

            currentDistance += distance
        }

        return segments
    }

    /// Evalúa la seguridad de un segmento
    private func evaluateSegmentSafety(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> Double {
        var safetyScore = 100.0

        // Verificar proximidad a zonas de evitación
        for zone in avoidanceZones {
            if case .incident = zone.type {
                let distanceToZone = min(
                    start.distance(to: zone.center),
                    end.distance(to: zone.center)
                )

                if distanceToZone < zone.radius {
                    // Reducir score basado en proximidad y severidad
                    let proximityFactor = 1 - (distanceToZone / zone.radius)
                    safetyScore -= zone.severity * proximityFactor * 50
                }
            }
        }

        return max(0, safetyScore)
    }

    /// Evalúa la calidad del aire de un segmento
    private func evaluateSegmentAirQuality(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> Double {
        var airScore = 100.0

        // Buscar zonas de aire cercanas
        for zone in airQualityZones {
            let distanceToZone = min(
                start.distance(to: zone.coordinate),
                end.distance(to: zone.coordinate)
            )

            if distanceToZone < zone.radius * 2 {
                // Ajustar score basado en AQI
                let aqiPenalty = zone.airQuality.aqi / 5  // Max penalty = 100 (AQI 500)
                let proximityFactor = 1 - (distanceToZone / (zone.radius * 2))
                airScore -= aqiPenalty * proximityFactor
            }
        }

        return max(0, airScore)
    }

    /// Identifica peligros en un segmento
    private func identifySegmentHazards(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> [String] {
        var hazards: [String] = []

        for zone in avoidanceZones {
            let distanceToZone = min(
                start.distance(to: zone.center),
                end.distance(to: zone.center)
            )

            if distanceToZone < zone.radius * 1.5 {
                hazards.append(zone.reason)
            }
        }

        return hazards
    }

    /// Encuentra incidentes cerca de la ruta
    private func findIncidentsNearRoute(route: RouteInfo) -> [(incident: CustomAnnotation, distance: Double)] {
        let polyline = route.route.polyline
        let coordinates = polyline.coordinates()

        var nearbyIncidents: [(incident: CustomAnnotation, distance: Double)] = []

        for incident in activeIncidents {
            var minDistance = Double.greatestFiniteMagnitude

            for coord in coordinates {
                let distance = coord.distance(to: incident.coordinate)
                minDistance = min(minDistance, distance)

                if distance < 50 {
                    break
                }
            }

            if minDistance <= 1000 {  // Dentro de 1km
                nearbyIncidents.append((incident, minDistance))
            }
        }

        return nearbyIncidents
    }

    /// Analiza la calidad del aire para una ruta
    private func analyzeAirQualityForRoute(route: RouteInfo) -> AirQualityRouteAnalysis? {
        let polyline = route.route.polyline
        let coordinates = polyline.coordinates()

        var aqiValues: [Double] = []
        var pm25Values: [Double] = []
        var foundZones: [AirQualityZone] = []

        // Samplear cada 200m
        let sampleInterval = 200.0
        var accumulatedDistance = 0.0

        for i in 0..<coordinates.count - 1 {
            let coord1 = coordinates[i]
            let coord2 = coordinates[i + 1]
            let segmentDistance = coord1.distance(to: coord2)

            if accumulatedDistance >= sampleInterval {
                // Buscar zona de aire más cercana
                if let nearestZone = findNearestAirQualityZone(to: coord1) {
                    aqiValues.append(nearestZone.airQuality.aqi)
                    pm25Values.append(nearestZone.airQuality.pm25)
                    foundZones.append(nearestZone)
                }
                accumulatedDistance = 0
            }

            accumulatedDistance += segmentDistance
        }

        guard !aqiValues.isEmpty else { return nil }

        let avgAQI = aqiValues.reduce(0, +) / Double(aqiValues.count)
        let avgPM25 = pm25Values.reduce(0, +) / Double(pm25Values.count)
        let maxAQI = aqiValues.max() ?? avgAQI
        let minAQI = aqiValues.min() ?? avgAQI

        // Crear segmentos de análisis para la ruta
        var segments: [AirQualitySegment] = []

        // Crear segmentos basados en las zonas encontradas
        for (index, zone) in foundZones.enumerated() {
            let segment = AirQualitySegment(
                startCoordinate: zone.coordinate,
                endCoordinate: zone.coordinate, // Simplificado por ahora
                distanceMeters: zone.radius,
                airQuality: zone.airQuality
            )
            segments.append(segment)
        }

        // Si no hay segmentos, crear uno con valores promedio
        if segments.isEmpty {
            let avgPoint = AirQualityPoint(
                coordinate: route.route.polyline.coordinates().first ?? CLLocationCoordinate2D(),
                aqi: avgAQI,
                pm25: avgPM25,
                pm10: 0
            )

            let segment = AirQualitySegment(
                startCoordinate: route.route.polyline.coordinates().first ?? CLLocationCoordinate2D(),
                endCoordinate: route.route.polyline.coordinates().last ?? CLLocationCoordinate2D(),
                distanceMeters: route.route.distance,
                airQuality: avgPoint
            )
            segments.append(segment)
        }

        // Crear análisis con los segmentos
        return AirQualityRouteAnalysis(
            segments: segments
        )
    }

    /// Encuentra la zona de calidad del aire más cercana
    private func findNearestAirQualityZone(to coordinate: CLLocationCoordinate2D) -> AirQualityZone? {
        return airQualityZones.min { zone1, zone2 in
            coordinate.distance(to: zone1.coordinate) < coordinate.distance(to: zone2.coordinate)
        }
    }

    /// Crea análisis de incidentes
    private func createIncidentAnalysis(
        incidents: [(incident: CustomAnnotation, distance: Double)],
        safetyScore: Double
    ) -> IncidentRouteAnalysis {

        var trafficCount = 0
        var hazardCount = 0
        var accidentCount = 0
        var pedestrianCount = 0
        var policeCount = 0
        var roadWorkCount = 0

        for (incident, _) in incidents {
            switch incident.alertType {
            case .traffic: trafficCount += 1
            case .hazard: hazardCount += 1
            case .accident: accidentCount += 1
            case .pedestrian: pedestrianCount += 1
            case .police: policeCount += 1
            case .roadWork: roadWorkCount += 1
            }
        }

        let criticalCount = incidents.filter { (incident, distance) in
            (incident.alertType == .accident || incident.alertType == .roadWork) && distance < 500
        }.count

        return IncidentRouteAnalysis(
            totalIncidents: incidents.count,
            criticalIncidents: criticalCount,
            nearbyIncidents: incidents,
            safetyScore: safetyScore,
            riskLevel: RiskLevel.from(safetyScore: safetyScore),
            trafficCount: trafficCount,
            hazardCount: hazardCount,
            accidentCount: accidentCount,
            pedestrianCount: pedestrianCount,
            policeCount: policeCount,
            roadWorkCount: roadWorkCount
        )
    }

    /// Calcula zonas temporales (hora punta, eventos)
    private func calculateTemporalZones() async -> [AvoidanceZone] {
        var zones: [AvoidanceZone] = []

        let hour = Calendar.current.component(.hour, from: Date())
        let isRushHour = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)

        if isRushHour && config.considerTrafficPatterns {
            // Aquí podrías agregar zonas conocidas de congestión
            // Por ahora retornamos vacío
        }

        return zones
    }

    /// Combina zonas superpuestas
    private func combineOverlappingZones(_ zones: [AvoidanceZone]) -> [AvoidanceZone] {
        // Simplificado: retornar todas las zonas
        // En una implementación completa, combinarías zonas cercanas
        return zones
    }

    // MARK: - Utility Methods

    private func calculateIncidentSeverity(_ type: AlertType) -> Double {
        switch type {
        case .accident: return 1.0
        case .roadWork: return 0.8
        case .traffic: return 0.7
        case .hazard: return 0.6
        case .police: return 0.4
        case .pedestrian: return 0.3
        }
    }

    private func calculateIncidentRadius(_ type: AlertType) -> CLLocationDistance {
        switch type {
        case .accident: return 500
        case .roadWork: return 400
        case .traffic: return 300
        case .hazard: return 200
        case .police: return 150
        case .pedestrian: return 100
        }
    }

    private func calculateAirQualitySeverity(_ level: AQILevel) -> Double {
        switch level {
        case .good: return 0.0
        case .moderate: return 0.2
        case .poor: return 0.5
        case .unhealthy: return 0.7
        case .severe: return 0.9
        case .hazardous: return 1.0
        }
    }

    private func calculateOverallScore(safety: Double, air: Double) -> Double {
        return (safety * config.safetyWeight + air * config.airQualityWeight) /
               (config.safetyWeight + config.airQualityWeight)
    }

    private func determineHealthRisk(avgAQI: Double) -> HealthRisk {
        switch avgAQI {
        case 0..<100: return .low
        case 100..<150: return .medium
        case 150..<200: return .high
        default: return .veryHigh
        }
    }

    private func mapConfigToPreference() -> RoutePreference {
        if config.timeWeight > 0.6 {
            return .fastest
        } else if config.safetyWeight > 0.5 {
            return .safest
        } else if config.airQualityWeight > 0.5 {
            return .cleanestAir
        } else {
            return .balancedSafety
        }
    }
}

// MARK: - Extensions

// Las extensiones de CLLocationCoordinate2D y MKPolyline ya están definidas en otros archivos