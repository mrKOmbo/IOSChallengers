//
//  RouteSegmentMarker.swift
//  AcessNet
//
//  Vista de punto para línea de ruta elevada 3D
//

import SwiftUI

// MARK: - Route Segment Marker

struct RouteSegmentMarker: View {
    let segmentIndex: Int
    let totalSegments: Int
    @State private var animationPhase: CGFloat = 0

    init(segmentIndex: Int = 0, totalSegments: Int = 100) {
        self.segmentIndex = segmentIndex
        self.totalSegments = totalSegments
    }

    var body: some View {
        Circle()
            .fill(
                AngularGradient(
                    gradient: Gradient(colors: [
                        .cyan.opacity(0.8),
                        .blue,
                        .blue.opacity(0.6),
                        .cyan.opacity(0.8)
                    ]),
                    center: .center,
                    startAngle: .degrees(animationPhase),
                    endAngle: .degrees(animationPhase + 360)
                )
            )
            .frame(width: 8, height: 8)
            .shadow(color: .blue.opacity(0.6), radius: 4, x: 0, y: 2)
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 1.5)
            )
            .onAppear {
                // Delay basado en la posición en la ruta para efecto "wave"
                let delay = Double(segmentIndex) * 0.02

                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    animationPhase = 360
                }
            }
    }
}

// MARK: - Compact Route Segment (para zoom lejano)

struct CompactRouteSegment: View {
    var body: some View {
        Circle()
            .fill(.blue)
            .frame(width: 6, height: 6)
            .shadow(color: .blue.opacity(0.4), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview("Route Segment Markers") {
    VStack(spacing: 30) {
        Text("Route Segment Marker Styles")
            .font(.title2.bold())
            .padding()

        HStack(spacing: 40) {
            VStack {
                RouteSegmentMarker(segmentIndex: 0, totalSegments: 100)
                Text("First Segment")
                    .font(.caption)
            }

            VStack {
                RouteSegmentMarker(segmentIndex: 50, totalSegments: 100)
                Text("Mid Segment")
                    .font(.caption)
            }

            VStack {
                CompactRouteSegment()
                Text("Compact")
                    .font(.caption)
            }
        }

        Spacer()
    }
    .padding()
}
