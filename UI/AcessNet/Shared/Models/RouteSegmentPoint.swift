//
//  RouteSegmentPoint.swift
//  AcessNet
//
//  Modelo para puntos densos a lo largo de la ruta (para línea elevada 3D)
//

import Foundation
import CoreLocation

// MARK: - Route Segment Point

struct RouteSegmentPoint: Identifiable, Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let distanceFromStart: Double  // Distancia desde el inicio en metros
    let segmentIndex: Int  // Índice del segmento de la ruta

    init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        distanceFromStart: Double,
        segmentIndex: Int = 0
    ) {
        self.id = id
        self.coordinate = coordinate
        self.distanceFromStart = distanceFromStart
        self.segmentIndex = segmentIndex
    }

    // MARK: - Equatable

    static func == (lhs: RouteSegmentPoint, rhs: RouteSegmentPoint) -> Bool {
        return lhs.id == rhs.id
    }
}
