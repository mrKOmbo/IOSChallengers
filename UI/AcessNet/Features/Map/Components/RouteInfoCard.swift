//
//  RouteInfoCard.swift
//  AcessNet
//
//  Card que muestra información de la ruta calculada
//

import SwiftUI
import MapKit

// MARK: - Route Info Card

struct RouteInfoCard: View {
    let routeInfo: RouteInfo
    let isCalculating: Bool
    let onClear: () -> Void
    let onStartNavigation: (() -> Void)?

    @State private var isExpanded = false
    @State private var showAlternates = false

    var body: some View {
        VStack(spacing: 0) {
            // Main route info
            mainInfoView
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        }
    }

    private var mainInfoView: some View {
        VStack(spacing: 16) {
            // Header con icono de ruta (mejorado)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Route")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Navigation ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Botón de cerrar mejorado
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onClear()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.gray)
                    }
                }
            }

            // Información de distancia y tiempo (mejorado)
            HStack(spacing: 16) {
                // Distancia
                EnhancedInfoBadge(
                    icon: "arrow.left.and.right",
                    value: routeInfo.distanceFormatted,
                    label: "Distance",
                    color: .blue
                )

                Divider()
                    .frame(height: 35)

                // Tiempo
                EnhancedInfoBadge(
                    icon: "clock.fill",
                    value: routeInfo.timeFormatted,
                    label: "Duration",
                    color: .green
                )
            }
            .padding(.vertical, 8)

            // Botones de acción (mejorados)
            HStack(spacing: 12) {
                // Botón Start Navigation (opcional)
                if let startNavigation = onStartNavigation {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        startNavigation()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Start Navigation")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    .blue.opacity(0.95),
                                    .blue.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }

                // Botón Clear Route
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onClear()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Clear")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: onStartNavigation == nil ? .infinity : nil)
                    .padding(.horizontal, onStartNavigation == nil ? 0 : 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.red.opacity(0.12))
                    )
                }
            }
        }
    }
}

// MARK: - Enhanced Info Badge (Modernizado)

/// Badge mejorado para mostrar información de la ruta
struct EnhancedInfoBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            // Icono con gradiente
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            // Valor y etiqueta
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Info Badge (Original - para compatibilidad)

/// Badge para mostrar información de la ruta
struct InfoBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Calculating Route Indicator

/// Vista que se muestra mientras se calcula la ruta
struct CalculatingRouteView: View {
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            // Indicador de carga
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .cyan, .blue],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("Calculating route...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Compact Route Info

/// Vista compacta de la ruta (para mostrar en la parte superior)
struct CompactRouteInfo: View {
    let routeInfo: RouteInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.system(size: 14))
                .foregroundStyle(.blue)

            Text(routeInfo.distanceFormatted)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text("•")
                .foregroundStyle(.secondary)

            Text(routeInfo.timeFormatted)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Route Error View

/// Vista para mostrar errores en el cálculo de ruta
struct RouteErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Route Error")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Preview

#Preview("Route Info Card") {
    VStack(spacing: 20) {
        // Crear una ruta de ejemplo
        let mockRoute = createMockRoute()
        let routeInfo = RouteInfo(from: mockRoute)

        RouteInfoCard(
            routeInfo: routeInfo,
            isCalculating: false,
            onClear: { print("Clear tapped") },
            onStartNavigation: { print("Start navigation") }
        )
        .padding()

        CalculatingRouteView()
            .padding()

        CompactRouteInfo(routeInfo: routeInfo)
            .padding()

        RouteErrorView(
            message: "No se pudo calcular la ruta. Intenta nuevamente.",
            onDismiss: { print("Dismiss error") }
        )
        .padding()

        Spacer()
    }
}

// MARK: - Mock Helper

private func createMockRoute() -> MKRoute {
    // Crear coordenadas de ejemplo
    let coordinates = [
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
    ]

    // Crear polyline
    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)

    // Crear un MKRoute simulado
    // Nota: MKRoute es difícil de mockear directamente, esta es una aproximación
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinates[0]))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinates[1]))

    // Para el preview, necesitamos un MKRoute real, pero esto es complicado sin hacer una request real
    // Por ahora, retornamos un placeholder - en producción esto vendrá de MKDirections
    let directions = MKDirections(request: request)

    // Hack para preview: crear estructura temporal que simule MKRoute
    // En código real, esto vendrá de MKDirections.calculate()
    fatalError("Mock route creation not implemented - use real MKDirections in production")
}
