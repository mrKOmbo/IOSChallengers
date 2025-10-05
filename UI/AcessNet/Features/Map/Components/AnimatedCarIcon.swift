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

    @State private var rotationAnimate = false
    @State private var pulseAnimate = false
    @State private var breatheScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Pulse effect cuando está en modo Business (más sutil)
            if showPulse {
                ForEach(0..<2) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.6), .cyan.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .scaleEffect(pulseAnimate ? 2.2 : 1.0)
                        .opacity(pulseAnimate ? 0 : 0.7)
                        .frame(width: 60, height: 60)
                        .animation(
                            .easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.9),
                            value: pulseAnimate
                        )
                }
            }

            // Shadow circular para profundidad mejorado
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.4),
                            Color.blue.opacity(0.2),
                            .clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: 35
                    )
                )
                .frame(width: 70, height: 70)
                .blur(radius: 5)

            // Icono del auto con glassmorphism
            ZStack {
                // Fondo del círculo con glassmorphism
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.95),
                                        Color.blue.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: .blue.opacity(0.5), radius: 12, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                // Borde con gradiente
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .white.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 54, height: 54)

                // Icono del auto
                Image(systemName: isMoving ? "car.fill" : "car")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .rotationEffect(.degrees(heading))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: heading)
            }
            .scaleEffect(breatheScale)

            // Indicador de movimiento (anillo rotatorio mejorado)
            if isMoving {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        AngularGradient(
                            colors: [
                                .cyan.opacity(0.9),
                                .blue.opacity(0.8),
                                .cyan.opacity(0.9)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .frame(width: 66, height: 66)
                    .rotationEffect(.degrees(rotationAnimate ? 360 : 0))

                // Segundo anillo en dirección opuesta
                Circle()
                    .trim(from: 0, to: 0.15)
                    .stroke(
                        .white.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 66, height: 66)
                    .rotationEffect(.degrees(rotationAnimate ? -360 : 0))
            }
        }
        .onAppear {
            // Animación de rotación del anillo
            if isMoving {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    rotationAnimate = true
                }
            }

            // Animación de pulso
            if showPulse {
                withAnimation {
                    pulseAnimate = true
                }
            }

            // Animación de respiración sutil
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                breatheScale = 1.06
            }
        }
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
