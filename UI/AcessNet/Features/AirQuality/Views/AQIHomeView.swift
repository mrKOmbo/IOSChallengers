//
//  AQIHomeView.swift
//  AcessNet
//
//  Created by Claude Code
//

import SwiftUI

struct AQIHomeView: View {
    @Binding var showBusinessPulse: Bool
    @State private var airQualityData: AirQualityData = .sample
    @State private var selectedForecastTab: ForecastTab = .hourly
    @State private var showSearchModal = false
    @State private var searchText = ""
    @State private var isMenuOpen = false

    enum ForecastTab {
        case hourly
        case daily
    }

    private let menuWidth: CGFloat = 280

    init(showBusinessPulse: Binding<Bool>) {
        self._showBusinessPulse = showBusinessPulse
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Side menu ahora vive en la vista de inicio
            SideMenuView(onBusinessToggle: { isActive in
                showBusinessPulse = isActive
            })
            .frame(width: menuWidth)
            .offset(x: isMenuOpen ? 0 : -menuWidth)

            mainContent
                .cornerRadius(isMenuOpen ? 20 : 0)
                .scaleEffect(isMenuOpen ? 0.82 : 1)
                .offset(x: isMenuOpen ? menuWidth : 0)
                .shadow(color: .black.opacity(isMenuOpen ? 0.25 : 0), radius: 10)
                .disabled(isMenuOpen)
                .overlay(
                    Color.black.opacity(isMenuOpen ? 0.2 : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                )
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isMenuOpen)
        .ignoresSafeArea()
    }

    private var mainContent: some View {
        NavigationView {
            ZStack {
                // Background gradient based on AQI level - More vibrant with multiple layers
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: [
                            Color(hex: airQualityData.qualityLevel.backgroundColor),
                            Color(hex: airQualityData.qualityLevel.backgroundColor).opacity(0.7),
                            Color(hex: airQualityData.qualityLevel.color).opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Overlay gradient for depth
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.1),
                            Color.clear,
                            Color.black.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Animated rain effect
                    RainEffectView()
                        .opacity(0.6)
                }
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        headerView

                        // AQI Info Button (combines AQI Card + PM Indicators)
                        aqiInfoButton

                        // Weather Info Card
                        weatherCard

                        // Mascot Character
                        mascotView

                        // Weather Forecast
                        weatherForecast
                    }
                    .padding(.top, 20)
                    .avoidTabBar(extraPadding: 20)
                }


                // "Near Me?" floating button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {}) {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.green, .yellow, .orange, .red],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(.white, lineWidth: 1.5)
                                        )

                                    Text("AQI")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }

                                Text("Near Me?")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color("Primary"))
                                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            )
                        }
                        .padding(.trailing, 20)
                        .aboveTabBar(extraPadding: 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - View Components

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isMenuOpen.toggle()
                    }
                }) {
                    Image(systemName: isMenuOpen ? "xmark" : "line.3.horizontal")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                }
                .accessibilityLabel("Abrir menú lateral")

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .font(.subheadline)

                        Text(airQualityData.location)
                            .font(.title3.bold())
                            .foregroundColor(.white)

                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }

                    Text(airQualityData.city)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))

                    Text("Nearest Monitor : \(String(format: "%.2f", airQualityData.distance)) Km")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Search button
                Button(action: {
                    showSearchModal = true
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.2))
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showSearchModal) {
            LocationSearchModal(searchText: $searchText)
        }
    }

    private var aqiCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                            .shadow(color: .red, radius: 4)

                        Text("Live AQI")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }

                    Text("\(airQualityData.aqi)")
                        .font(.system(size: 90, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Text("Air Quality is")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.95))

                    Text(airQualityData.qualityLevel.rawValue)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(hex: airQualityData.qualityLevel.color).opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var dailyForecastButton: some View {
        NavigationLink(destination: DailyForecastView()) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("5-Day Forecast")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("View detailed daily air quality predictions")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("Secondary").opacity(0.7),
                                Color("Primary").opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        }
        .padding(.horizontal)
    }

    private var aqiInfoButton: some View {
        NavigationLink(destination: DailyForecastView()) {
            VStack(spacing: 16) {
                // AQI Card content
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                                .shadow(color: .red, radius: 4)

                            Text("Live AQI")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }

                        Text("\(airQualityData.aqi)")
                            .font(.system(size: 90, weight: .heavy))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        Text("Air Quality is")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.95))

                        Text(airQualityData.qualityLevel.rawValue)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(hex: airQualityData.qualityLevel.color).opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(.white.opacity(0.3), lineWidth: 1.5)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // PM Indicators
                HStack(spacing: 24) {
                    // PM2.5 - Simplified
                    HStack(spacing: 8) {
                        Text("PM2.5:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        Text("\(Int(airQualityData.pm25)) μg/m³")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }

                    // PM10 - Simplified
                    HStack(spacing: 8) {
                        Text("PM10:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        Text("\(Int(airQualityData.pm10)) μg/m³")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
        }
        .padding(.horizontal)
    }

    private var pmIndicators: some View {
        HStack(spacing: 24) {
            // PM2.5 - Simplified
            HStack(spacing: 8) {
                Text("PM2.5:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Text("\(Int(airQualityData.pm25)) μg/m³")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }

            // PM10 - Simplified
            HStack(spacing: 8) {
                Text("PM10:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Text("\(Int(airQualityData.pm10)) μg/m³")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
    }

    private var weatherCard: some View {
        VStack(spacing: 16) {
            // Weather scale bar
            AQIScaleBar(currentAQI: airQualityData.aqi)
                .padding(.horizontal)

            // Weather info card
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // Temperature
                    WeatherInfoItem(
                        icon: "cloud.fill",
                        value: "\(Int(airQualityData.temperature))°",
                        unit: "C",
                        label: airQualityData.weatherCondition.rawValue
                    )

                    Divider()
                        .frame(height: 60)
                        .background(.white.opacity(0.2))

                    // Humidity
                    WeatherInfoItem(
                        icon: "drop.fill",
                        value: "\(airQualityData.humidity)",
                        unit: "%",
                        label: "Humidity"
                    )

                    Divider()
                        .frame(height: 60)
                        .background(.white.opacity(0.2))

                    // Wind
                    WeatherInfoItem(
                        icon: "wind",
                        value: "\(Int(airQualityData.windSpeed))",
                        unit: "km/hr",
                        label: "Wind"
                    )

                    Divider()
                        .frame(height: 60)
                        .background(.white.opacity(0.2))

                    // UV Index
                    WeatherInfoItem(
                        icon: "sun.max.fill",
                        value: "\(airQualityData.uvIndex)",
                        unit: "",
                        label: "UV Index"
                    )
                }
                .padding(.vertical, 8)

                // Last update
                Text("Last Update:  \(airQualityData.timeAgo)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal)
        }
    }

    private var mascotView: some View {
        HStack {
            Spacer()
            MascotCharacter()
                .frame(height: 180)
                .padding(.trailing, 40)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
    }

    private var weatherForecast: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weather Forecast")
                .font(.title3.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            // Tabs
            HStack(spacing: 8) {
                ForecastTabButton(
                    title: "Hourly",
                    isSelected: selectedForecastTab == .hourly
                ) {
                    selectedForecastTab = .hourly
                }

                ForecastTabButton(
                    title: "Daily",
                    isSelected: selectedForecastTab == .daily
                ) {
                    selectedForecastTab = .daily
                }
            }
            .padding(.horizontal)

            // Forecast content with sample data
            if selectedForecastTab == .hourly {
                hourlyForecastView
            } else {
                // Daily forecast navigation button
                NavigationLink(destination: DailyForecastView()) {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.6))

                        Text("View Daily Forecast")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Tap to see 5-day forecast")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    )
                }
                .padding(.horizontal)
            }
        }
    }

    private var hourlyForecastView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                HourlyForecastItem(hour: "Now", temp: 16, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "19:00", temp: 15, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "20:00", temp: 15, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "21:00", temp: 14, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "22:00", temp: 14, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "23:00", temp: 14, icon: "cloud.rain.fill")
                HourlyForecastItem(hour: "00:00", temp: 13, icon: "cloud.moon.rain.fill")
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Views

struct PMIndicator: View {
    let title: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white.opacity(0.9))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(value))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text(unit)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct AQIScaleBar: View {
    let currentAQI: Int

    var body: some View {
        VStack(spacing: 8) {
            // Scale labels
            HStack {
                Text("Good")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Moderate")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Poor")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Unhealthy")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Severe")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Hazardous")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            // Scale bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background gradient
                    LinearGradient(
                        colors: [
                            Color(hex: "#7BC043"),
                            Color(hex: "#F9A825"),
                            Color(hex: "#FF6F00"),
                            Color(hex: "#E53935"),
                            Color(hex: "#8E24AA"),
                            Color(hex: "#6A1B4D")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Current position indicator
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 4)
                        .offset(x: CGFloat(currentAQI) / 301.0 * geometry.size.width - 10)
                }
            }
            .frame(height: 12)

            // Scale numbers
            HStack {
                ForEach([0, 50, 100, 150, 200, 301], id: \.self) { number in
                    Text("\(number)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    if number != 301 {
                        Spacer()
                    }
                }

                Text("301+")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct WeatherInfoItem: View {
    let icon: String
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.white)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ForecastTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isSelected ? .white : .white.opacity(0.1))
                )
        }
    }
}

struct HourlyForecastItem: View {
    let hour: String
    let temp: Int
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Text(hour)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))

            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .symbolRenderingMode(.multicolor)

            Text("\(temp)°")
                .font(.title3.bold())
                .foregroundColor(.white)
        }
        .frame(width: 60)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Location Search Modal

struct LocationSearchModal: View {
    @Binding var searchText: String
    @Environment(\.dismiss) var dismiss
    @State private var searchResults: [String] = []

    let quickLocations = [
        ("Mexico City, Mexico", "mappin.circle.fill"),
        ("New York, USA", "building.2.fill"),
        ("Tokyo, Japan", "building.fill"),
        ("London, UK", "building.columns.fill"),
        ("Paris, France", "sparkles")
    ]

    var body: some View {
        ZStack {
            Color("Body")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .padding(.top, 10)

                // Enhanced Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))

                    TextField("Search location...", text: $searchText)
                        .font(.body)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // Results or Quick Navigation
                ScrollView {
                    if searchText.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            // Quick Navigation Header
                            Text("Quick Navigation")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            // Quick location buttons
                            VStack(spacing: 12) {
                                ForEach(quickLocations, id: \.0) { location in
                                    Button(action: {
                                        dismiss()
                                    }) {
                                        HStack(spacing: 16) {
                                            Image(systemName: location.1)
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .frame(width: 40)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(location.0)
                                                    .font(.body.bold())
                                                    .foregroundColor(.white)

                                                Text("View air quality")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(.white.opacity(0.15))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredLocations, id: \.self) { location in
                                Button(action: {
                                    dismiss()
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .frame(width: 40)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(location)
                                                .font(.body.bold())
                                                .foregroundColor(.white)

                                            Text("Tap to view air quality")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.white.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
    }

    var filteredLocations: [String] {
        let sampleLocations = [
            "Mexico City, Mexico",
            "New York, USA",
            "Los Angeles, USA",
            "London, UK",
            "Tokyo, Japan",
            "Paris, France",
            "Berlin, Germany",
            "Madrid, Spain"
        ]

        if searchText.isEmpty {
            return sampleLocations
        } else {
            return sampleLocations.filter { $0.lowercased().contains(searchText.lowercased()) }
        }
    }
}


// MARK: - Preview

#Preview {
    AQIHomeView(showBusinessPulse: .constant(false))
}
