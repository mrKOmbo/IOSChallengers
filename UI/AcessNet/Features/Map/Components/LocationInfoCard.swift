//
//  LocationInfoCard.swift
//  AcessNet
//
//  Card que muestra información de una ubicación seleccionada antes de calcular ruta
//

import SwiftUI
import MapKit

// MARK: - Location Info Card

struct LocationInfoCard: View {
    let locationInfo: LocationInfo
    let onCalculateRoute: () -> Void
    let onCancel: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            mainInfoView
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        }
    }

    private var mainInfoView: some View {
        VStack(spacing: 16) {
            // Header con icono de ubicación
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .purple.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Punto B")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(locationInfo.distanceFromUser)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Botón de cancelar
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onCancel()
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

            // Información de la ubicación
            VStack(alignment: .leading, spacing: 12) {
                // Nombre del lugar
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)

                    Text(locationInfo.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                // Dirección (si está disponible)
                if let subtitle = locationInfo.subtitle, !subtitle.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                // Coordenadas
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)

                    Text(locationInfo.coordinatesFormatted)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Botón principal: Calcular Ruta
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onCalculateRoute()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Calcular Ruta")
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
            .padding(.top, 8)
        }
    }
}

// MARK: - Preview

#Preview("Location Info Card") {
    VStack {
        Spacer()

        LocationInfoCard(
            locationInfo: LocationInfo(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "San Francisco Downtown",
                subtitle: "Market St, San Francisco, CA",
                distanceFromUser: "2.3 km de tu ubicación"
            ),
            onCalculateRoute: { print("Calculate route") },
            onCancel: { print("Cancel") }
        )
        .padding()

        Spacer()
    }
}
