//
//  EnhancedAirQualityDashboard.swift
//  AcessNet
//
//  Dashboard mejorado con gráficos y visualizaciones avanzadas
//

import SwiftUI

// MARK: - Enhanced Air Quality Dashboard

/// Dashboard completo con gráficos y estadísticas visuales
struct EnhancedAirQualityDashboard: View {
    @Binding var isExpanded: Bool
    let statistics: AirQualityGridManager.GridStatistics?

    @State private var animateCharts: Bool = false
    @State private var glowIntensity: Double = 0.3

    var body: some View {
        VStack(spacing: 0) {
            // Header siempre visible
            headerView
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

            // Contenido expandido
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .background(
            ZStack {
                // Glass morphism background
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)

                // Gradient overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                dominantColor.opacity(0.15),
                                dominantColor.opacity(0.05),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: dominantColor.opacity(0.2), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Animated AQI indicator
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                dominantColor.opacity(glowIntensity),
                                dominantColor.opacity(glowIntensity * 0.5),
                                .clear
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)
                    .blur(radius: 6)

                // Main circle
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                dominantColor,
                                dominantColor.opacity(0.8),
                                dominantColor,
                            ],
                            center: .center
                        )
                    )
                    .frame(width: 40, height: 40)

                // Icon
                Image(systemName: "aqi.medium")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Air Quality")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                if let stats = statistics {
                    HStack(spacing: 6) {
                        Text("AQI")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("\(Int(stats.averageAQI))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(dominantColor)

                        // Trend indicator
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(dominantColor)
                            .opacity(0.7)
                    }
                }
            }

            Spacer()

            // Expand/Collapse indicator
            ZStack {
                Circle()
                    .fill(dominantColor.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(dominantColor)
            }
        }
        .padding(16)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: 20) {
            Divider()
                .padding(.horizontal, 16)

            // Donut Chart + Stats
            HStack(spacing: 24) {
                // Donut chart
                donutChartView
                    .frame(width: 120, height: 120)

                // Stats breakdown
                statsBreakdownView
            }
            .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)

            // Level distribution bars
            levelDistributionView
                .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)

            // Breathability Index integrado
            breathabilitySection
                .padding(.horizontal, 16)

            // Quick insights
            quickInsightsView
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Donut Chart

    private var donutChartView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: 20)

            // Animated segments
            if let stats = statistics, animateCharts {
                ForEach(Array(levelSegments.enumerated()), id: \.offset) { index, segment in
                    Circle()
                        .trim(from: segment.start, to: segment.end)
                        .stroke(
                            segment.color,
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }

            // Center content
            VStack(spacing: 2) {
                if let stats = statistics {
                    Text("\(stats.totalZones)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("zones")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Stats Breakdown

    private var statsBreakdownView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let stats = statistics {
                StatRow(
                    icon: "leaf.fill",
                    label: "Good",
                    count: stats.goodCount,
                    color: Color(hex: "#7BC043")
                )

                StatRow(
                    icon: "leaf",
                    label: "Moderate",
                    count: stats.moderateCount,
                    color: Color(hex: "#F9A825")
                )

                StatRow(
                    icon: "exclamationmark.triangle.fill",
                    label: "Poor",
                    count: stats.poorCount,
                    color: Color(hex: "#FF6F00")
                )

                StatRow(
                    icon: "xmark.shield.fill",
                    label: "Unhealthy",
                    count: stats.unhealthyCount + stats.severeCount + stats.hazardousCount,
                    color: Color(hex: "#E53935")
                )
            }
        }
    }

    // MARK: - Level Distribution

    private var levelDistributionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Level Distribution")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if let stats = statistics {
                DistributionBar(
                    segments: [
                        (stats.goodCount, Color(hex: "#7BC043")),
                        (stats.moderateCount, Color(hex: "#F9A825")),
                        (stats.poorCount, Color(hex: "#FF6F00")),
                        (stats.unhealthyCount + stats.severeCount + stats.hazardousCount, Color(hex: "#E53935"))
                    ],
                    total: stats.totalZones,
                    animate: animateCharts
                )
            }
        }
    }

    // MARK: - Breathability Section

    private var breathabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breathability")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if let stats = statistics {
                HStack(spacing: 16) {
                    // Animated lungs
                    animatedLungsIcon

                    // Breathability info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(breathabilityDescription)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(dominantColor)

                        Text(breathabilityDetail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    // Score indicator
                    breathabilityScoreRing
                }
                .padding(16)
                .background(dominantColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(dominantColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private var animatedLungsIcon: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(dominantColor.opacity(0.15))
                .frame(width: 52, height: 52)
                .scaleEffect(1.0 + (glowIntensity - 0.3) * 0.3)

            // Lungs icon
            Image(systemName: "lungs.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(dominantColor)
                .scaleEffect(1.0 + (glowIntensity - 0.3) * 0.4)

            // Breathing particles
            ForEach(0..<3) { i in
                Circle()
                    .fill(dominantColor.opacity(0.4))
                    .frame(width: 3, height: 3)
                    .offset(y: -20 - (glowIntensity - 0.3) * 15)
                    .opacity(1.0 - (glowIntensity - 0.3) * 2)
                    .blur(radius: 1)
                    .offset(x: CGFloat(i - 1) * 6)
            }
        }
    }

    private var breathabilityScoreRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 44, height: 44)

            // Progress ring
            Circle()
                .trim(from: 0, to: breathabilityScore / 100)
                .stroke(
                    dominantColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))

            // Score text
            Text("\(Int(breathabilityScore))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(dominantColor)
        }
    }

    private var breathabilityScore: Double {
        guard let stats = statistics else { return 0 }
        return max(0, min(100, 100 - (stats.averageAQI / 2)))
    }

    private var breathabilityDescription: String {
        guard let stats = statistics else { return "N/A" }
        switch stats.dominantLevel {
        case .good: return "Excellent"
        case .moderate: return "Good"
        case .poor: return "Fair"
        case .unhealthy: return "Poor"
        case .severe: return "Very Poor"
        case .hazardous: return "Hazardous"
        }
    }

    private var breathabilityDetail: String {
        guard let stats = statistics else { return "" }
        switch stats.dominantLevel {
        case .good:
            return "Perfect for outdoor breathing"
        case .moderate:
            return "Safe for most people"
        case .poor:
            return "Consider mask for sensitive groups"
        case .unhealthy:
            return "Limit outdoor exposure"
        case .severe:
            return "Wear mask, reduce activity"
        case .hazardous:
            return "Stay indoors, use purifiers"
        }
    }

    // MARK: - Quick Insights

    private var quickInsightsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Insights")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if let stats = statistics {
                HStack(spacing: 12) {
                    InsightCard(
                        icon: "chart.line.uptrend.xyaxis",
                        value: "\(Int(stats.averageAQI))",
                        label: "Avg AQI",
                        color: dominantColor
                    )

                    InsightCard(
                        icon: dominantLevelIcon,
                        value: dominantLevelName,
                        label: "Dominant",
                        color: dominantColor
                    )
                }
            }
        }
    }

    // MARK: - Helper Components

    private struct StatRow: View {
        let icon: String
        let label: String
        let count: Int
        let color: Color

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private struct DistributionBar: View {
        let segments: [(Int, Color)]
        let total: Int
        let animate: Bool

        var body: some View {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        let percentage = Double(segment.0) / Double(max(total, 1))
                        let width = geometry.size.width * percentage

                        RoundedRectangle(cornerRadius: 4)
                            .fill(segment.1)
                            .frame(width: animate ? width : 0)
                    }
                }
            }
            .frame(height: 12)
        }
    }

    private struct InsightCard: View {
        let icon: String
        let value: String
        let label: String
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)

                    Text(value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Computed Properties

    private var dominantColor: Color {
        guard let stats = statistics else { return .gray }

        let level = stats.dominantLevel
        switch level {
        case .good: return Color(hex: "#7BC043")
        case .moderate: return Color(hex: "#F9A825")
        case .poor: return Color(hex: "#FF6F00")
        case .unhealthy: return Color(hex: "#E53935")
        case .severe: return Color(hex: "#8E24AA")
        case .hazardous: return Color(hex: "#6A1B4D")
        }
    }

    private var dominantLevelName: String {
        statistics?.dominantLevel.rawValue ?? "N/A"
    }

    private var dominantLevelIcon: String {
        guard let stats = statistics else { return "questionmark" }
        return stats.dominantLevel.routingIcon
    }

    private var levelSegments: [(start: Double, end: Double, color: Color)] {
        guard let stats = statistics else { return [] }

        var segments: [(Double, Double, Color)] = []
        var currentPosition: Double = 0

        let levels: [(Int, Color)] = [
            (stats.goodCount, Color(hex: "#7BC043")),
            (stats.moderateCount, Color(hex: "#F9A825")),
            (stats.poorCount, Color(hex: "#FF6F00")),
            (stats.unhealthyCount + stats.severeCount + stats.hazardousCount, Color(hex: "#E53935"))
        ]

        for level in levels {
            guard level.0 > 0 else { continue }
            let percentage = Double(level.0) / Double(stats.totalZones)
            segments.append((currentPosition, currentPosition + percentage, level.1))
            currentPosition += percentage
        }

        return segments
    }

    // MARK: - Animations

    private func startAnimations() {
        // Glow animation
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.6
        }

        // Chart animation with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animateCharts = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Enhanced Dashboard") {
    ZStack {
        Color.black.opacity(0.05)

        VStack {
            Spacer()

            EnhancedAirQualityDashboard(
                isExpanded: .constant(true),
                statistics: AirQualityGridManager.GridStatistics(
                    totalZones: 49,
                    averageAQI: 78,
                    goodCount: 15,
                    moderateCount: 20,
                    poorCount: 10,
                    unhealthyCount: 3,
                    severeCount: 1,
                    hazardousCount: 0
                )
            )
            .frame(maxWidth: 320)
            .padding()

            Spacer()
        }
    }
}
