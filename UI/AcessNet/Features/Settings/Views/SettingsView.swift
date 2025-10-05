//
//  SettingsView.swift
//  AcessNet
//
//  Created by Claude Code
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedAQI: AQIStandard = .european
    @State private var selectedTemperature: TemperatureUnit = .celsius
    @State private var selectedWindSpeed: WindSpeedUnit = .kmh

    enum AQIStandard {
        case european
        case us
    }

    enum TemperatureUnit {
        case celsius
        case fahrenheit
    }

    enum WindSpeedUnit {
        case kmh
        case mph
    }

    var body: some View {
        ZStack {
            // Background gradient - Deep blue to purple
            LinearGradient(
                colors: [
                    Color(hex: "#1a1a2e"),
                    Color(hex: "#16213e"),
                    Color(hex: "#0f3460")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Circle()
                            .fill(Color(hex: "#4ECDC4"))
                            .frame(width: 12, height: 12)

                        Text("SETTINGS")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)

                    // Air Quality Index Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AIR QUALITY INDEX")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)

                        HStack(spacing: 0) {
                            SegmentButton(
                                title: "European AQI",
                                isSelected: selectedAQI == .european
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedAQI = .european
                                }
                            }

                            SegmentButton(
                                title: "US AQI",
                                isSelected: selectedAQI == .us
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedAQI = .us
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .padding(.horizontal)

                    // Temperature Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TEMPERATURE")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)

                        HStack(spacing: 0) {
                            SegmentButton(
                                title: "°C",
                                isSelected: selectedTemperature == .celsius
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTemperature = .celsius
                                }
                            }

                            SegmentButton(
                                title: "°F",
                                isSelected: selectedTemperature == .fahrenheit
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTemperature = .fahrenheit
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .padding(.horizontal)

                    // Wind Speed Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WIND SPEED")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1)

                        HStack(spacing: 0) {
                            SegmentButton(
                                title: "Km/h",
                                isSelected: selectedWindSpeed == .kmh
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedWindSpeed = .kmh
                                }
                            }

                            SegmentButton(
                                title: "Mph",
                                isSelected: selectedWindSpeed == .mph
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedWindSpeed = .mph
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .padding(.horizontal)

                    // Support us Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Support us")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            SupportButton(
                                icon: "star.fill",
                                title: "Rate"
                            )

                            Divider()
                                .background(Color.white.opacity(0.1))

                            SupportButton(
                                icon: "paperplane.fill",
                                title: "Share"
                            )

                            Divider()
                                .background(Color.white.opacity(0.1))

                            SupportButton(
                                icon: "square.grid.2x2.fill",
                                title: "More"
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Supporting Views

struct SegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.bold())
                .foregroundColor(isSelected ? Color(hex: "#0D1B3E") : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? .white : .clear)
                )
        }
    }
}

struct SupportButton: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 30)

                Text(title)
                    .font(.body)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
