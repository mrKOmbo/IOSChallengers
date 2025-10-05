//
//  ElevatedRoutePoint.swift
//  AcessNet
//
//  Punto elevado visible sobre edificios 3D en la ruta
//

import SwiftUI

// MARK: - Elevated Route Point

struct ElevatedRoutePoint: View {
    let index: Int
    let total: Int

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.6),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .frame(width: 24, height: 24)
                .blur(radius: 4)
                .scaleEffect(isPulsing ? 1.3 : 1.0)

            // Main point
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0, green: 1, blue: 1), // Cyan
                            Color(red: 0.04, green: 0.52, blue: 1.0) // Blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 10, height: 10)
                .shadow(color: .cyan.opacity(0.8), radius: 4, x: 0, y: 2)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 1.5)
                )
        }
        .onAppear {
            // Stagger animation based on index for wave effect
            let delay = Double(index) * 0.03

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Elevated Route Points") {
    VStack(spacing: 30) {
        Text("Elevated Route Point")
            .font(.title2.bold())
            .padding()

        HStack(spacing: 40) {
            VStack {
                ElevatedRoutePoint(index: 0, total: 10)
                Text("First Point")
                    .font(.caption)
            }

            VStack {
                ElevatedRoutePoint(index: 5, total: 10)
                Text("Mid Point")
                    .font(.caption)
            }

            VStack {
                ElevatedRoutePoint(index: 9, total: 10)
                Text("Last Point")
                    .font(.caption)
            }
        }

        Spacer()
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
