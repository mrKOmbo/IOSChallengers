//
//  SpeedIndicator.swift
//  AcessNet
//
//  Indicador de velocidad animado estilo Waze
//

import SwiftUI

// MARK: - Speed Indicator

struct SpeedIndicator: View {
    let speed: Double // km/h
    let speedLimit: Double? // km/h (opcional)

    @State private var animate = false

    private var isOverLimit: Bool {
        guard let limit = speedLimit else { return false }
        return speed > limit
    }

    private var speedColor: Color {
        if isOverLimit {
            return .red
        } else if speed > 50 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Velocímetro circular
            ZStack {
                // Fondo
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                // Anillo de progreso
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 70, height: 70)

                // Anillo de velocidad
                Circle()
                    .trim(from: 0, to: min(speed / 120, 1.0))
                    .stroke(
                        AngularGradient(
                            colors: [speedColor, speedColor.opacity(0.5)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: speed)

                // Velocidad actual
                VStack(spacing: 2) {
                    Text("\(Int(speed))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(speedColor)

                    Text("km/h")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .scaleEffect(animate ? 1.05 : 1.0)
            }

            // Límite de velocidad (si existe)
            if let limit = speedLimit {
                HStack(spacing: 4) {
                    Image(systemName: isOverLimit ? "exclamationmark.triangle.fill" : "speedometer")
                        .font(.caption2)
                        .foregroundStyle(isOverLimit ? .red : .secondary)

                    Text("Limit: \(Int(limit)) km/h")
                        .font(.caption2)
                        .foregroundStyle(isOverLimit ? .red : .secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isOverLimit ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                )
                .shake(trigger: isOverLimit)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Compact Speed Indicator

struct CompactSpeedIndicator: View {
    let speed: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.caption)
                .foregroundStyle(.blue)

            Text("\(Int(speed))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("km/h")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Navigation Info Panel

struct NavigationInfoPanel: View {
    let speed: Double
    let eta: String
    let distance: String

    var body: some View {
        HStack(spacing: 16) {
            // Velocidad
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("Speed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("\(Int(speed)) km/h")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Divider()
                .frame(height: 40)

            // ETA
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("ETA")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(eta)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Divider()
                .frame(height: 40)

            // Distancia
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(distance)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Mini Speed Badge

struct MiniSpeedBadge: View {
    let speed: Double
    let isMoving: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isMoving ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .glowEffect(color: isMoving ? .green : .clear, radius: 4)

            Text("\(Int(speed))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 3)
    }
}

// MARK: - Speed Limit Sign

struct SpeedLimitSign: View {
    let limit: Int
    let isExceeded: Bool

    var body: some View {
        ZStack {
            // Fondo del signo
            Circle()
                .fill(.white)
                .frame(width: 50, height: 50)
                .overlay {
                    Circle()
                        .stroke(isExceeded ? Color.red : Color.gray, lineWidth: 4)
                }
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)

            // Número
            Text("\(limit)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(isExceeded ? .red : .black)
        }
        .scaleEffect(isExceeded ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isExceeded)
    }
}

// MARK: - Preview

#Preview("Speed Indicator") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

        VStack(spacing: 30) {
            SpeedIndicator(speed: 65, speedLimit: 60)
            SpeedIndicator(speed: 45, speedLimit: 60)
            SpeedIndicator(speed: 0, speedLimit: nil)
        }
    }
}

#Preview("Compact Speed Indicator") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

        VStack(spacing: 20) {
            CompactSpeedIndicator(speed: 75)
            CompactSpeedIndicator(speed: 0)
        }
    }
}

#Preview("Navigation Info Panel") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

        NavigationInfoPanel(speed: 65, eta: "15 min", distance: "5.2 km")
    }
}

#Preview("Mini Speed Badge") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

        VStack(spacing: 15) {
            MiniSpeedBadge(speed: 75, isMoving: true)
            MiniSpeedBadge(speed: 0, isMoving: false)
        }
    }
}

#Preview("Speed Limit Sign") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

        HStack(spacing: 30) {
            SpeedLimitSign(limit: 60, isExceeded: false)
            SpeedLimitSign(limit: 60, isExceeded: true)
        }
    }
}
