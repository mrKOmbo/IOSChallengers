//
//  AlertAnnotationView.swift
//  AcessNet
//
//  Anotaciones personalizadas y animadas para alertas en el mapa
//

import SwiftUI
import MapKit

// MARK: - Alert Type Enum

enum AlertType: String, CaseIterable {
    case traffic = "Traffic"
    case hazard = "Hazard"
    case accident = "Accident"
    case pedestrian = "Pedestrian"
    case police = "Police"
    case roadWork = "Road Work"

    var icon: String {
        switch self {
        case .traffic: return "car.fill"
        case .hazard: return "exclamationmark.triangle.fill"
        case .accident: return "car.side.rear.and.collision.and.car.side.front"
        case .pedestrian: return "figure.walk"
        case .police: return "hand.raised.square.on.square.fill"
        case .roadWork: return "cone.fill"
        }
    }

    var color: Color {
        switch self {
        case .traffic: return .red
        case .hazard: return .yellow
        case .accident: return .orange
        case .pedestrian: return .blue
        case .police: return .indigo
        case .roadWork: return .orange
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .traffic: return [.red, .red.opacity(0.7)]
        case .hazard: return [.yellow, .orange]
        case .accident: return [.orange, .red]
        case .pedestrian: return [.blue, .cyan]
        case .police: return [.indigo, .blue]
        case .roadWork: return [.orange, .yellow]
        }
    }
}

// MARK: - Alert Annotation View

struct AlertAnnotationView: View {
    let alertType: AlertType
    let showPulse: Bool

    @State private var animate = false

    var body: some View {
        ZStack {
            // Efecto de pulso para alertas activas
            if showPulse {
                Circle()
                    .stroke(alertType.color, lineWidth: 3)
                    .scaleEffect(animate ? 2.0 : 1.0)
                    .opacity(animate ? 0.0 : 0.7)
                    .frame(width: 50, height: 50)
                    .animation(
                        .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: animate
                    )
            }

            // Icono principal
            ZStack {
                // Fondo con gradiente
                Circle()
                    .fill(
                        LinearGradient(
                            colors: alertType.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 45, height: 45)
                    .shadow(color: alertType.color.opacity(0.5), radius: 8, x: 0, y: 4)

                // Borde blanco
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 45, height: 45)

                // Icono
                Image(systemName: alertType.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(animate ? 1.1 : 1.0)
        }
        .onAppear {
            animate = true
        }
    }
}

/// Versión compacta de la anotación
struct CompactAlertView: View {
    let alertType: AlertType
    let count: Int

    var body: some View {
        ZStack {
            // Fondo
            Capsule()
                .fill(alertType.color)
                .frame(width: 60, height: 30)
                .shadow(radius: 3)

            HStack(spacing: 4) {
                Image(systemName: alertType.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)

                if count > 1 {
                    Text("\(count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

/// Anotación expandida con información
struct DetailedAlertView: View {
    let alertType: AlertType
    let time: String
    let distance: String?

    var body: some View {
        VStack(spacing: 4) {
            // Icono principal
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: alertType.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(radius: 5)

                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: 50, height: 50)

                Image(systemName: alertType.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Info card
            VStack(spacing: 2) {
                Text(alertType.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    if let distance = distance {
                        Text(distance)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 2)
            )

            // Pointer (flecha hacia abajo)
            Triangle()
                .fill(.ultraThinMaterial)
                .frame(width: 12, height: 6)
                .offset(y: -6)
        }
    }
}

/// Triángulo para pointer
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Pin de ubicación personalizado
struct CustomMapPin: View {
    let color: Color
    let icon: String

    var body: some View {
        ZStack {
            // Pin shape
            VStack(spacing: 0) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay {
                        Circle()
                            .strokeBorder(.white, lineWidth: 3)

                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)

                // Pointer bottom
                Triangle()
                    .fill(color)
                    .frame(width: 12, height: 8)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
            }
        }
        .offset(y: -20) // Ajustar para que el punto esté en la coordenada
    }
}

// MARK: - Preview

#Preview("Alert Annotations") {
    ScrollView {
        VStack(spacing: 30) {
            Text("Alert Annotation Styles").font(.title2.bold())

            // Standard annotations
            HStack(spacing: 20) {
                ForEach(AlertType.allCases.prefix(3), id: \.self) { type in
                    VStack {
                        AlertAnnotationView(alertType: type, showPulse: false)
                        Text(type.rawValue)
                            .font(.caption)
                    }
                }
            }

            Divider()

            // With pulse
            HStack(spacing: 20) {
                ForEach(AlertType.allCases.suffix(3), id: \.self) { type in
                    VStack {
                        AlertAnnotationView(alertType: type, showPulse: true)
                        Text(type.rawValue)
                            .font(.caption)
                    }
                }
            }

            Divider()

            // Compact views
            HStack(spacing: 15) {
                CompactAlertView(alertType: .traffic, count: 1)
                CompactAlertView(alertType: .police, count: 3)
                CompactAlertView(alertType: .hazard, count: 5)
            }

            Divider()

            // Detailed views
            HStack(spacing: 20) {
                DetailedAlertView(alertType: .accident, time: "5 min ago", distance: "200m")
                DetailedAlertView(alertType: .roadWork, time: "1 hr ago", distance: nil)
            }

            Divider()

            // Custom pins
            HStack(spacing: 20) {
                CustomMapPin(color: .red, icon: "mappin.circle.fill")
                CustomMapPin(color: .blue, icon: "star.fill")
                CustomMapPin(color: .green, icon: "flag.fill")
            }
        }
        .padding()
    }
}
