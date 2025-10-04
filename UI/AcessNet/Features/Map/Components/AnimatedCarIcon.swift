//
//  AnimatedCarIcon.swift
//  AcessNet
//
//  Icono de auto animado con rotación suave y efectos visuales
//

import SwiftUI
import CoreLocation

struct AnimatedCarIcon: View {
    let heading: CLLocationDirection
    let isMoving: Bool
    let showPulse: Bool

    @State private var animate = false

    var body: some View {
        ZStack {
            // Pulse effect cuando está en modo Business
            if showPulse {
                AnimatedPulsingCircle(color: .cyan, size: 80)
            }

            // Shadow circular para profundidad
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.blue.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .blur(radius: 3)

            // Icono del auto
            ZStack {
                // Fondo del círculo con gradiente
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)

                // Borde blanco
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 50, height: 50)

                // Icono del auto
                Image(systemName: isMoving ? "car.fill" : "car")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(heading))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: heading)
            }

            // Indicador de movimiento (anillo rotatorio)
            if isMoving {
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AngularGradient(
                            colors: [.cyan, .blue, .cyan],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animate)
                    .onAppear { animate = true }
            }
        }
        .scaleEffect(animate ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)
    }
}

/// Versión simplificada para preview
struct SimpleCarIcon: View {
    let heading: CLLocationDirection
    var color: Color = .blue

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .shadow(radius: 3)

            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 40, height: 40)

            Image(systemName: "car.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(heading))
        }
    }
}

/// Indicador de dirección (flecha)
struct DirectionArrow: View {
    let heading: CLLocationDirection
    let color: Color

    var body: some View {
        Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 30))
            .foregroundStyle(color)
            .rotationEffect(.degrees(heading))
            .shadow(radius: 3)
    }
}

// MARK: - Preview

#Preview("Animated Car - Moving") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        AnimatedCarIcon(heading: 45, isMoving: true, showPulse: false)
    }
}

#Preview("Animated Car - With Pulse") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        AnimatedCarIcon(heading: 90, isMoving: true, showPulse: true)
    }
}

#Preview("Animated Car - Stationary") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        AnimatedCarIcon(heading: 0, isMoving: false, showPulse: false)
    }
}

#Preview("Simple Car Icon") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        VStack(spacing: 30) {
            SimpleCarIcon(heading: 0, color: .blue)
            SimpleCarIcon(heading: 90, color: .green)
            SimpleCarIcon(heading: 180, color: .orange)
            SimpleCarIcon(heading: 270, color: .red)
        }
    }
}

#Preview("Direction Arrow") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        DirectionArrow(heading: 45, color: .blue)
    }
}
