//
//  AirQualityAPIService.swift
//  AcessNet
//
//  Servicio para comunicación con backend de calidad del aire (NASA APIs)
//

import Foundation
import CoreLocation
import Combine

// MARK: - Air Quality API Service

class AirQualityAPIService {

    // MARK: - Properties

    /// Instancia singleton
    static let shared = AirQualityAPIService()

    /// Base URL del backend Django
    private var baseURL: String {
        #if DEBUG
        return "http://localhost:8000/api/v1"  // Local development
        #else
        return "https://your-backend.com/api/v1"  // Production
        #endif
    }

    /// URLSession para requests
    private let session: URLSession

    /// Timeout para requests (30 segundos)
    private let requestTimeout: TimeInterval = 30.0

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    /// Obtiene la calidad del aire actual de una ubicación desde el backend real
    /// - Parameters:
    ///   - latitude: Latitud de la ubicación
    ///   - longitude: Longitud de la ubicación
    /// - Returns: Datos de calidad del aire desde OpenAQ
    func getCurrentAQI(
        latitude: Double,
        longitude: Double
    ) async throws -> AirQualityPoint {

        print("\n🌍 ===== BACKEND REAL API CALL =====")
        print("📍 Coordenadas: lat=\(latitude), lon=\(longitude)")

        // Construir URL con query parameters
        var urlComponents = URLComponents(string: baseURL + "/air/current")
        urlComponents?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude))
        ]

        guard let url = urlComponents?.url else {
            print("❌ Error: URL inválida")
            throw APIError.invalidURL
        }

        print("🔗 URL completa: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = requestTimeout

        // Realizar request
        print("⏳ Enviando request al backend Django...")
        let startTime = Date()

        let (data, response) = try await session.data(for: request)

        let duration = Date().timeIntervalSince(startTime)
        print("⏱️  Respuesta recibida en \(String(format: "%.2f", duration))s")

        // Validar response HTTP
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Error: Respuesta HTTP inválida")
            throw APIError.invalidResponse
        }

        print("📊 Status Code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Error del servidor (status \(httpResponse.statusCode))")
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                print("   Mensaje: \(errorResponse.message)")
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorResponse.message)
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Response: \(responseString)")
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unknown error")
        }

        // Log raw JSON response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📦 Response JSON:")
            print(responseString)
        }

        // Decodificar respuesta del backend Django
        do {
            let backendResponse = try JSONDecoder().decode(DjangoAQIResponse.self, from: data)

            print("✅ Decodificación exitosa!")
            print("   AQI: \(Int(backendResponse.aqi))")
            print("   Categoría: \(backendResponse.category)")
            print("   Color: \(backendResponse.color)")
            print("   Mensaje: \(backendResponse.message)")
            print("   PM2.5: \(backendResponse.pollutants.pm25 ?? 0)")
            print("   O3: \(backendResponse.pollutants.o3 ?? 0)")
            print("   NO2: \(backendResponse.pollutants.no2 ?? 0)")

            // Convertir respuesta del backend a AirQualityPoint
            let airQualityPoint = AirQualityPoint(
                coordinate: CLLocationCoordinate2D(
                    latitude: backendResponse.location.lat,
                    longitude: backendResponse.location.lon
                ),
                aqi: backendResponse.aqi,
                pm25: backendResponse.pollutants.pm25 ?? 0,
                pm10: nil,
                no2: backendResponse.pollutants.no2,
                o3: backendResponse.pollutants.o3,
                co: nil,
                so2: nil,
                aod: nil,
                timestamp: Date()
            )

            print("🎉 AirQualityPoint creado correctamente")
            print("===== END BACKEND CALL =====\n")

            return airQualityPoint

        } catch {
            print("❌ Error decodificando respuesta: \(error)")
            print("   Tipo: \(type(of: error))")
            print("===== END BACKEND CALL (ERROR) =====\n")
            throw APIError.decodingError(error)
        }
    }

    /// Analiza la calidad del aire de una ruta completa
    /// - Parameters:
    ///   - coordinates: Array de coordenadas del polyline
    ///   - samplingInterval: Distancia entre muestras en metros (default: 150m)
    /// - Returns: Análisis completo de calidad del aire
    func analyzeRoute(
        coordinates: [CLLocationCoordinate2D],
        samplingInterval: Double = 150
    ) async throws -> AirQualityRouteAnalysis {

        guard !coordinates.isEmpty else {
            throw APIError.invalidRequest("Coordinates array is empty")
        }

        print("🌍 Analizando ruta con \(coordinates.count) coordenadas...")

        let request = AnalyzeRouteRequest(
            coordinates: coordinates,
            samplingIntervalMeters: samplingInterval
        )

        let endpoint = "/air-quality/analyze-route"
        let response: AnalyzeRouteResponse = try await post(endpoint: endpoint, body: request)

        print("✅ Análisis completado: AQI promedio \(Int(response.analysis.averageAQI))")
        print("   Fuente de datos: \(response.dataSource)")
        print("   Tiempo de procesamiento: \(response.processingTimeMs)ms")

        return response.analysis
    }

    /// Obtiene la calidad del aire en un punto específico
    /// - Parameter coordinate: Coordenada a consultar
    /// - Returns: Datos de calidad del aire
    func getAirQuality(
        at coordinate: CLLocationCoordinate2D,
        includeExtendedMetrics: Bool = false
    ) async throws -> AirQualityPoint {

        let request = AirQualityPointRequest(
            coordinate: coordinate,
            includeExtendedMetrics: includeExtendedMetrics
        )

        let endpoint = "/air-quality/point"
        let response: AirQualityPointResponse = try await post(endpoint: endpoint, body: request)

        if let cacheAge = response.cacheAge {
            print("📦 Datos del cache (edad: \(cacheAge)s)")
        }

        return response.airQuality
    }

    /// Obtiene calidad del aire para múltiples puntos en una sola request (batch)
    /// - Parameter coordinates: Array de coordenadas
    /// - Returns: Array de datos de calidad del aire
    func getBatchAirQuality(
        coordinates: [CLLocationCoordinate2D],
        includeExtendedMetrics: Bool = false
    ) async throws -> [AirQualityPoint] {

        guard !coordinates.isEmpty else {
            throw APIError.invalidRequest("Coordinates array is empty")
        }

        print("🌍 Consultando calidad del aire para \(coordinates.count) puntos (batch)...")

        let request = BatchAirQualityRequest(
            coordinates: coordinates,
            includeExtendedMetrics: includeExtendedMetrics
        )

        let endpoint = "/air-quality/batch"
        let response: BatchAirQualityResponse = try await post(endpoint: endpoint, body: request)

        print("✅ Batch completado: \(response.points.count) puntos, \(response.totalProcessingTimeMs)ms")

        return response.points
    }

    // MARK: - Private HTTP Methods

    /// Realiza un POST request genérico
    private func post<T: Codable, R: Codable>(
        endpoint: String,
        body: T
    ) async throws -> R {

        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Serializar body
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError(error)
        }

        // Realizar request
        let (data, response) = try await session.data(for: request)

        // Validar response HTTP
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Intentar parsear error del backend
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorResponse.message)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unknown error")
        }

        // Decodificar respuesta
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(R.self, from: data)
        } catch {
            print("❌ Error decodificando respuesta: \(error)")
            throw APIError.decodingError(error)
        }
    }

    /// Realiza un GET request genérico
    private func get<R: Codable>(
        endpoint: String,
        queryParams: [String: String] = [:]
    ) async throws -> R {

        var urlComponents = URLComponents(string: baseURL + endpoint)
        if !queryParams.isEmpty {
            urlComponents?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorResponse.message)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unknown error")
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(R.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidRequest(String)
    case invalidResponse
    case encodingError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int, message: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .invalidResponse:
            return "Invalid server response"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Error Response Model

struct ErrorResponse: Codable {
    let message: String
    let code: String?
    let details: String?
}

// MARK: - Django Backend Response Models

/// Respuesta del backend Django para /api/v1/air/current
struct DjangoAQIResponse: Codable {
    let location: DjangoLocation
    let timestamp: String
    let aqi: Double
    let category: String
    let color: String
    let message: String
    let pollutants: DjangoPollutants
}

/// Ubicación en respuesta del backend
struct DjangoLocation: Codable {
    let lat: Double
    let lon: Double
}

/// Contaminantes en respuesta del backend
struct DjangoPollutants: Codable {
    let pm25: Double?
    let o3: Double?
    let no2: Double?
}

// MARK: - Mock Service (for testing without backend)

class MockAirQualityAPIService: AirQualityAPIService {

    /// Inicializador público para mock
    override init() {
        super.init()
    }

    /// Genera datos simulados de calidad del aire
    override func analyzeRoute(
        coordinates: [CLLocationCoordinate2D],
        samplingInterval: Double = 150
    ) async throws -> AirQualityRouteAnalysis {

        // Simular delay de red
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos

        print("🧪 Mock: Generando datos simulados para \(coordinates.count) coordenadas")

        // Generar segmentos con AQI aleatorio
        var segments: [AirQualitySegment] = []

        for i in 0..<coordinates.count - 1 {
            let start = coordinates[i]
            let end = coordinates[i + 1]

            // AQI aleatorio entre 20 y 150
            let randomAQI = Double.random(in: 20...150)
            let randomPM25 = randomAQI * 0.5  // PM2.5 aproximadamente proporcional

            let airQuality = AirQualityPoint(
                coordinate: start,
                aqi: randomAQI,
                pm25: randomPM25,
                timestamp: Date()
            )

            let segment = AirQualitySegment(
                startCoordinate: start,
                endCoordinate: end,
                distanceMeters: samplingInterval,
                airQuality: airQuality
            )

            segments.append(segment)
        }

        let analysis = AirQualityRouteAnalysis(segments: segments)

        print("✅ Mock: AQI promedio \(Int(analysis.averageAQI))")

        return analysis
    }

    override func getAirQuality(
        at coordinate: CLLocationCoordinate2D,
        includeExtendedMetrics: Bool = false
    ) async throws -> AirQualityPoint {

        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 segundos

        let randomAQI = Double.random(in: 20...150)
        let randomPM25 = randomAQI * 0.5

        return AirQualityPoint(
            coordinate: coordinate,
            aqi: randomAQI,
            pm25: randomPM25,
            timestamp: Date()
        )
    }

    override func getBatchAirQuality(
        coordinates: [CLLocationCoordinate2D],
        includeExtendedMetrics: Bool = false
    ) async throws -> [AirQualityPoint] {

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos

        return coordinates.map { coord in
            let randomAQI = Double.random(in: 20...150)
            let randomPM25 = randomAQI * 0.5

            return AirQualityPoint(
                coordinate: coord,
                aqi: randomAQI,
                pm25: randomPM25,
                timestamp: Date()
            )
        }
    }
}
