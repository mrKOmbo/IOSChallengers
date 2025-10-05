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
    @State private var is3DMode: Bool = false

    // MARK: - Routing State
    @StateObject private var routeManager = RouteManager()
    @State private var routingMode: Bool = false
    @State private var destination: DestinationPoint?

    // MARK: - Search State
    @StateObject private var searchManager = LocationSearchManager()
    @FocusState private var isSearchFocused: Bool
    @State private var showRouteToast = false
    @State private var routeToastMessage = ""

    // MARK: - Route Arrows State
    @State private var routeArrows: [RouteArrowAnnotation] = []

    // MARK: - Route Animation State (Optimizado)
    @State private var dashPhase: CGFloat = 0  // Marching ants

    private let bottomBarHeight: CGFloat = UIScreen.main.bounds.height * 0.1

    // Computed property para verificar si hay ruta activa
    private var hasActiveRoute: Bool {
        routeManager.currentRoute != nil || routeManager.isCalculating
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Mapa principal mejorado
            enhancedMapView

            // Dimmer de fondo cuando búsqueda está activa
            if isSearchFocused {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchFocused = false
                            searchManager.clearSearch()
                        }
                    }
                    .transition(.opacity)
            }

            // Route Toast Notification
            if showRouteToast {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)

                        Text(routeToastMessage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.top, 60)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Speed Indicator (top left)
            VStack {
                HStack {
                    if locationManager.isMoving && !isSearchFocused {
                        CompactSpeedIndicator(speed: locationManager.speedKmh)
                            .padding(.leading)
                            .fadeIn(delay: 0.2)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 60)

            // Top buttons (2D/3D and Map Style) - Por debajo del safe area
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 15) {
                        // 2D/3D toggle button
                        FloatingActionButton(
                            icon: is3DMode ? "view.2d" : "view.3d",
                            color: .green,
                            size: 50
                        ) {
                            toggle3DMode()
                        }

                        // Map style toggle
                        FloatingActionButton(
                            icon: mapStyle.icon,
                            color: .purple,
                            size: 50
                        ) {
                            cycleMapStyle()
                        }
                    }
                    .padding(.trailing, 20)
                }
                Spacer()
            }
            .padding(.top, 60)

            // Search Results (arriba de la barra de búsqueda)
            if !searchManager.searchResults.isEmpty || searchManager.isSearching {
                VStack {
                    Spacer()

                    SearchResultsView(
                        results: searchManager.searchResults,
                        isSearching: searchManager.isSearching,
                        userLocation: locationManager.userLocation,
                        onSelect: handleSearchResultSelection
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 160)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Route Info Card o Calculating Indicator
            if !isSearchFocused {
                VStack {
                    Spacer()

                    HStack(alignment: .bottom, spacing: 12) {
                        // Contenido de ruta
                        VStack(spacing: 0) {
                            if routeManager.isCalculating {
                                CalculatingRouteView()
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            } else if let routeInfo = routeManager.currentRoute {
                                RouteInfoCard(
                                    routeInfo: routeInfo,
                                    isCalculating: routeManager.isCalculating,
                                    onClear: clearRoute,
                                    onStartNavigation: nil // Opcional: implementar navegación
                                )
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            } else if let errorMessage = routeManager.errorMessage {
                                RouteErrorView(message: errorMessage, onDismiss: {
                                    routeManager.clearRoute()
                                })
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }

                        // Botón de ubicación al lado de la ruta
                        if hasActiveRoute {
                            FloatingActionButton(
                                icon: "location.fill",
                                color: .blue,
                                size: 50
                            ) {
                                centerOnUser()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 160)
                }
            }

            // Barra de búsqueda inferior
            VStack {
                Spacer()
                SearchBarView(
                    searchText: $searchManager.searchQuery,
                    isFocused: $isSearchFocused,
                    placeholder: "Where to?",
                    onSubmit: {
                        // Opcional: submit search
                    },
                    onClear: {
                        searchManager.clearSearch()
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 80)
                .fadeIn(delay: 0.1)
            }

            // Botones flotantes (ocultar cuando búsqueda está activa o hay ruta)
            if !isSearchFocused && !hasActiveRoute {
                floatingButtons
                    .padding(.bottom, 160)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Actualizar región de búsqueda inicial
            if let location = locationManager.userLocation {
                searchManager.updateSearchRegion(center: location)
            }
        }
        .onReceive(locationManager.$userLocation) { newLocation in
            // Actualizar región de búsqueda cuando cambie ubicación del usuario
            if let location = newLocation {
                searchManager.updateSearchRegion(center: location)
            }
        }
        .onReceive(routeManager.$currentRoute) { newRoute in
            if newRoute != nil {
                // Calcular flechas direccionales
                routeArrows = routeManager.calculateDirectionalArrows()

                // Inicializar animación de marching ants (simplificada)
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    dashPhase = 22
                }

                print("✅ Animación de ruta iniciada!")
                print("   - Flechas direccionales: \(routeArrows.count)")

            } else {
                // Limpiar ruta
                routeArrows = []
                dashPhase = 0
            }
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

                // Destination annotation (Punto B)
                if let dest = destination {
                    Annotation(dest.title, coordinate: dest.coordinate) {
                        DestinationAnnotationView()
                            .bounceIn()
                            .onTapGesture {
                                // Opcional: mostrar detalles del destino
                            }
                    }
                }

                // 🎨 ROUTE ANIMATION - Optimizada (3 capas elegantes)
                if let routeInfo = routeManager.currentRoute {

                    // CAPA 1: Base de ruta con gradiente suave
                    MapPolyline(routeInfo.polyline)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.8),
                                    Color.cyan.opacity(0.7),
                                    Color.blue.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                        )

                    // CAPA 2: Línea animada con marching ants elegante
                    MapPolyline(routeInfo.polyline)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.7), .white.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(
                                lineWidth: 5,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [10, 12],
                                dashPhase: dashPhase
                            )
                        )

                    // CAPA 3: Borde exterior sutil para profundidad
                    MapPolyline(routeInfo.polyline)
                        .stroke(
                            Color.blue.opacity(0.3),
                            style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                        )
                }

                // Directional arrows along route
                ForEach(Array(routeArrows.enumerated()), id: \.element.id) { index, arrow in
                    Annotation("", coordinate: arrow.coordinate) {
                        DirectionalArrowView(
                            heading: arrow.heading,
                            isNext: index == 0, // Primera flecha es la siguiente
                            size: 40
                        )
                        .bounceIn()
                    }
                    .annotationTitles(.hidden)
                }

                // Temporary tap marker
                if let coordinate = tappedCoordinate, !routingMode {
                    Annotation("New Report", coordinate: coordinate) {
                        CustomMapPin(color: .red, icon: "plus.circle.fill")
                            .pulseEffect(color: .red, duration: 1.0)
                    }
                }
            }
            .mapStyle(mapStyle.style)
            .mapControls {
                MapCompass()
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
            }
            .padding(.trailing, 20)
        }
    }

    // MARK: - Helper Methods

    private func handleMapTap(at screenPoint: CGPoint, with proxy: MapProxy) {
        guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }

        if routingMode {
            // Modo ruteo: establecer destino y calcular ruta
            setDestination(at: coordinate)
        }
        // Removido: modo de agregar alertas manualmente
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

    private func toggle3DMode() {
        guard let location = locationManager.userLocation else { return }

        is3DMode.toggle()

        withAnimation(.easeInOut(duration: 1.0)) {
            camera = .camera(
                MapCamera(
                    centerCoordinate: location,
                    distance: 1000,
                    heading: locationManager.heading,
                    pitch: is3DMode ? 60 : 0
                )
            )
        }
    }

    private func addAlertAtUserLocation() {
        tappedCoordinate = locationManager.userLocation
        mostrarSheet = true
    }

    // MARK: - Routing Methods

    private func toggleRoutingMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            routingMode.toggle()
        }

        if !routingMode {
            // Si se desactiva el modo ruteo, limpiar todo
            clearRoute()
        }
    }

    private func setDestination(at coordinate: CLLocationCoordinate2D, title: String = "Destination", subtitle: String? = nil) {
        guard let origin = locationManager.userLocation else {
            print("⚠️ No se puede calcular ruta sin ubicación del usuario")
            return
        }

        // Establecer destino con nombre
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            destination = DestinationPoint(
                coordinate: coordinate,
                title: title,
                subtitle: subtitle
            )
        }

        // Calcular ruta
        routeManager.calculateRoute(from: origin, to: coordinate)

        // Hacer zoom para mostrar toda la ruta después de calcularla
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            zoomToRoute()
        }
    }

    private func clearRoute() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            destination = nil
            routeManager.clearRoute()
        }
    }

    private func zoomToRoute() {
        guard let mapRect = routeManager.getRouteBounds() else { return }

        // Convertir MKMapRect a región para la cámara
        let region = MKCoordinateRegion(mapRect)

        withAnimation(.easeInOut(duration: 1.2)) {
            camera = .region(region)
        }
    }

    // MARK: - Search Methods

    private func handleSearchResultSelection(_ result: SearchResult) {
        // Obtener coordenadas del resultado
        searchManager.selectResult(result) { coordinate in
            guard let coordinate = coordinate else {
                print("⚠️ No se pudo obtener coordenadas del resultado")
                return
            }

            // SIEMPRE establecer destino y calcular ruta
            setDestination(
                at: coordinate,
                title: result.title,
                subtitle: result.subtitle
            )

            // Mostrar toast de confirmación
            showRouteToast(to: result.title)

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Solo cerrar teclado, mantener búsqueda
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSearchFocused = false
            }
        }
    }

    private func centerCamera(on coordinate: CLLocationCoordinate2D, distance: Double = 1000) {
        withAnimation(.easeInOut(duration: 1.0)) {
            camera = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: distance,
                    heading: 0,
                    pitch: 45
                )
            )
        }
    }

    private func showRouteToast(to placeName: String) {
        routeToastMessage = "Calculando ruta a \(placeName)"
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showRouteToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.25)) {
                showRouteToast = false
            }
        }
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


// MARK: - Floating Action Button (Modernizado)

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    var size: CGFloat = 50
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.3

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: isPrimary ? .medium : .light)
            impact.impactOccurred()

            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    isPressed = false
                }
            }
            action()
        }) {
            ZStack {
                // Glow effect para botón primario
                if isPrimary {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(glowIntensity),
                                    color.opacity(glowIntensity * 0.5),
                                    .clear
                                ],
                                center: .center,
                                startRadius: size * 0.3,
                                endRadius: size * 0.9
                            )
                        )
                        .frame(width: size * 1.3, height: size * 1.3)
                        .blur(radius: 8)
                }

                // Fondo del botón
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .fill(
                                isPrimary ?
                                LinearGradient(
                                    colors: [
                                        color.opacity(0.95),
                                        color.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.9),
                                        .white.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: isPrimary ?
                                    [.white.opacity(0.6), .white.opacity(0.2)] :
                                    [.black.opacity(0.1), .black.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isPrimary ? 2 : 1.5
                            )
                    )
                    .shadow(
                        color: isPrimary ? color.opacity(0.4) : .black.opacity(0.15),
                        radius: isPressed ? 8 : 12,
                        x: 0,
                        y: isPressed ? 3 : 6
                    )
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: 3,
                        x: 0,
                        y: 2
                    )

                // Icono
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 28 : 22, weight: .semibold))
                    .foregroundStyle(
                        isPrimary ?
                        LinearGradient(
                            colors: [.white, .white.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [color, color.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: isPrimary ? .black.opacity(0.3) : .clear,
                        radius: 1,
                        x: 0,
                        y: 1
                    )
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
        .onAppear {
            if isPrimary {
                // Animación de glow pulsante
                withAnimation(
                    .easeInOut(duration: 1.8)
                    .repeatForever(autoreverses: true)
                ) {
                    glowIntensity = 0.5
                }
            }
        }
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
            // Haptic feedback mejorado
            HapticAction.alertAdded.trigger()

            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isPressed = false
                action()
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Glow effect sutil
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    alertType.color.opacity(0.3),
                                    alertType.color.opacity(0.15),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 25,
                                endRadius: 35
                            )
                        )
                        .frame(width: 70, height: 70)
                        .blur(radius: 6)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    alertType.gradientColors[0],
                                    alertType.gradientColors[1]
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 62, height: 62)

                    Image(systemName: alertType.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .shadow(color: alertType.color.opacity(0.4), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                Text(alertType.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

