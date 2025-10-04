//
//  ContentView.swift
//  AcessNet
//
//  Vista principal mejorada con mapa estilo Waze
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Custom Annotation Model

struct CustomAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let alertType: AlertType
    let timestamp: Date = Date()

    init(coordinate: CLLocationCoordinate2D, title: String) {
        self.coordinate = coordinate
        self.title = title
        // Convertir el title a AlertType
        self.alertType = AlertType.allCases.first { $0.rawValue == title } ?? .hazard
    }

    var timeAgo: String {
        let minutes = Int(Date().timeIntervalSince(timestamp) / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        return "\(hours) hr ago"
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var showPulseOnMap = false
    @State private var isMenuOpen = false

    let menuWidth: CGFloat = 280

    var body: some View {
        ZStack(alignment: .leading) {
            // Side Menu
            SideMenuView(onBusinessToggle: { isActive in
                self.showPulseOnMap = isActive
            })
            .frame(width: menuWidth)
            .offset(x: isMenuOpen ? 0 : -menuWidth)

            // Main Content
            mainNavigationView
                .cornerRadius(isMenuOpen ? 20 : 0)
                .scaleEffect(isMenuOpen ? 0.82 : 1)
                .offset(x: isMenuOpen ? menuWidth : 0)
                .shadow(color: .black.opacity(isMenuOpen ? 0.25 : 0), radius: 10)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isMenuOpen)
        .ignoresSafeArea()
    }

    private var mainNavigationView: some View {
        NavigationView {
            EnhancedMapView(
                locationManager: locationManager,
                showPulse: $showPulseOnMap
            )
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isMenuOpen.toggle() }) {
                        Image(systemName: isMenuOpen ? "xmark" : "line.3.horizontal")
                            .foregroundColor(.primary)
                            .font(.title2)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .bounceIn()
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            configureTransparentNavigationBar()
        }
    }

    private func configureTransparentNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Enhanced Map View

struct EnhancedMapView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showPulse: Bool

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var annotations: [CustomAnnotation] = []
    @State private var mostrarSheet = false
    @State private var tappedCoordinate: CLLocationCoordinate2D?
    @State private var selectedAnnotation: CustomAnnotation?
    @State private var mapStyle: MapStyleType = .hybrid

    private let bottomBarHeight: CGFloat = UIScreen.main.bounds.height * 0.1

    var body: some View {
        ZStack(alignment: .bottom) {
            // Mapa principal mejorado
            enhancedMapView

            // Speed Indicator (top left)
            VStack {
                HStack {
                    if locationManager.isMoving {
                        CompactSpeedIndicator(speed: locationManager.speedKmh)
                            .padding(.leading)
                            .fadeIn(delay: 0.2)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 60)

            // Barra de búsqueda inferior
            ImprovedSearchBar()
                .frame(height: bottomBarHeight)
                .fadeIn(delay: 0.1)

            // Botones flotantes
            floatingButtons
                .padding(.bottom, bottomBarHeight + 10)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $mostrarSheet, onDismiss: { tappedCoordinate = nil }) {
            EnhancedAlertSheet(addAnnotation: { title in
                if let coordinate = tappedCoordinate {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        annotations.append(CustomAnnotation(coordinate: coordinate, title: title))
                    }
                }
            })
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Map View Components

    private var enhancedMapView: some View {
        MapReader { proxy in
            Map(position: $camera) {
                // User location annotation
                if let location = locationManager.userLocation {
                    Annotation("My Location", coordinate: location) {
                        AnimatedCarIcon(
                            heading: locationManager.heading,
                            isMoving: locationManager.isMoving,
                            showPulse: showPulse
                        )
                        .bounceIn()
                    }
                }

                // Alert annotations
                ForEach(annotations) { annotation in
                    Annotation(annotation.title, coordinate: annotation.coordinate) {
                        AlertAnnotationView(
                            alertType: annotation.alertType,
                            showPulse: true
                        )
                        .bounceIn()
                        .onTapGesture {
                            selectedAnnotation = annotation
                        }
                    }
                }

                // Temporary tap marker
                if let coordinate = tappedCoordinate {
                    Annotation("New Report", coordinate: coordinate) {
                        CustomMapPin(color: .red, icon: "plus.circle.fill")
                            .pulseEffect(color: .red, duration: 1.0)
                    }
                }
            }
            .mapStyle(mapStyle.style)
            .mapControls {
                MapCompass()
                MapPitchToggle()
                MapScaleView()
            }
            .onTapGesture(coordinateSpace: .local) { screenPoint in
                handleMapTap(at: screenPoint, with: proxy)
            }
        }
    }

    private var floatingButtons: some View {
        HStack {
            Spacer()
            VStack(spacing: 15) {
                // Location button
                FloatingActionButton(
                    icon: "location.fill",
                    color: .blue,
                    size: 50
                ) {
                    centerOnUser()
                }

                // Map style toggle
                FloatingActionButton(
                    icon: mapStyle.icon,
                    color: .purple,
                    size: 50
                ) {
                    cycleMapStyle()
                }

                // Add alert button
                FloatingActionButton(
                    icon: "exclamationmark.triangle.fill",
                    color: .yellow,
                    size: 60,
                    isPrimary: true
                ) {
                    addAlertAtUserLocation()
                }
                .glowEffect(color: .yellow, radius: 10)
            }
            .padding(.trailing, 20)
        }
    }

    // MARK: - Helper Methods

    private func handleMapTap(at screenPoint: CGPoint, with proxy: MapProxy) {
        if let coordinate = proxy.convert(screenPoint, from: .local) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                tappedCoordinate = coordinate
            }
            mostrarSheet = true
        }
    }

    private func centerOnUser() {
        guard let location = locationManager.userLocation else { return }

        withAnimation(.easeInOut(duration: 1.0)) {
            camera = .camera(
                MapCamera(
                    centerCoordinate: location,
                    distance: 1000,
                    heading: locationManager.heading,
                    pitch: 60
                )
            )
        }
    }

    private func cycleMapStyle() {
        withAnimation {
            mapStyle = mapStyle.next()
        }
    }

    private func addAlertAtUserLocation() {
        tappedCoordinate = locationManager.userLocation
        mostrarSheet = true
    }
}

// MARK: - Map Style Type

enum MapStyleType {
    case standard
    case hybrid
    case imagery

    var style: MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic, pointsOfInterest: .all, showsTraffic: true)
        case .hybrid:
            return .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: true)
        case .imagery:
            return .imagery(elevation: .realistic)
        }
    }

    var icon: String {
        switch self {
        case .standard: return "map"
        case .hybrid: return "map.fill"
        case .imagery: return "globe.americas.fill"
        }
    }

    func next() -> MapStyleType {
        switch self {
        case .standard: return .hybrid
        case .hybrid: return .imagery
        case .imagery: return .standard
        }
    }
}

// MARK: - Improved Search Bar

struct ImprovedSearchBar: View {
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)

                TextField("Where to?", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .transition(.scale)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    var size: CGFloat = 50
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 28 : 22, weight: .bold))
                .foregroundColor(isPrimary ? .white : color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(
                            isPrimary ?
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [.white, .white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Enhanced Alert Sheet

struct EnhancedAlertSheet: View {
    @Environment(\.dismiss) var dismiss
    var addAnnotation: (String) -> Void

    let alertTypes: [AlertType] = AlertType.allCases

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Report an incident")
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Alert type grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(alertTypes, id: \.self) { type in
                    AlertTypeButton(alertType: type) {
                        addAnnotation(type.rawValue)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

struct AlertTypeButton: View {
    let alertType: AlertType
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: alertType.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: alertType.color.opacity(0.4), radius: 8, x: 0, y: 4)

                    Image(systemName: alertType.icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(alertType.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
