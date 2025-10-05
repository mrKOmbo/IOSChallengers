//
//  RouteSegmentMarker.swift
//  AcessNet
//
//  Vista de punto para línea de ruta elevada 3D
//

import SwiftUI

// MARK: - Route Segment Marker

struct RouteSegmentMarker: View {
    let isHighlighted: Bool

    init(isHighlighted: Bool = false) {
        self.isHighlighted = isHighlighted
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: isHighlighted ? [.cyan, .blue] : [.blue, .blue.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: isHighlighted ? 12 : 8, height: isHighlighted ? 12 : 8)
            .shadow(color: .blue.opacity(0.6), radius: isHighlighted ? 6 : 4, x: 0, y: 2)
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.8), lineWidth: isHighlighted ? 2 : 1)
            )
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
                RouteSegmentMarker(isHighlighted: false)
                Text("Normal")
                    .font(.caption)
            }

            VStack {
                RouteSegmentMarker(isHighlighted: true)
                Text("Highlighted")
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
