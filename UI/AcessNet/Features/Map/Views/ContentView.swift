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

    // MARK: - Supreme Route Animation States
    @State private var dashPhase: CGFloat = 0  // Marching ants
    @State private var hueRotation: Double = 0  // Gradient shimmer
    @State private var travelingParticles: [TravelingParticle] = []  // Flowing particles
    @State private var energyPulses: [EnergyPulse] = []  // Expansion pulses
    @State private var multicolorPoints: [MulticolorElevatedPoint] = []  // Elevated multicolor points

    // MARK: - Animation Timers
    @State private var particleTimer: Timer?
    @State private var pulseTimer: Timer?

    private let bottomBarHeight: CGFloat = UIScreen.main.bounds.height * 0.1

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

            // Search Results (arriba de la barra de búsqueda)
            if isSearchFocused && (!searchManager.searchResults.isEmpty || searchManager.isSearching) {
                VStack {
                    Spacer()

                    SearchResultsView(
                        results: searchManager.searchResults,
                        isSearching: searchManager.isSearching,
                        userLocation: locationManager.userLocation,
                        onSelect: handleSearchResultSelection
                    )
                    .padding(.horizontal)
                    .padding(.bottom, bottomBarHeight + 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Route Info Card o Calculating Indicator
            if !isSearchFocused {
                VStack {
                    Spacer()

                    if routeManager.isCalculating {
                        CalculatingRouteView()
                            .padding(.bottom, bottomBarHeight + 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if let routeInfo = routeManager.currentRoute {
                        RouteInfoCard(
                            routeInfo: routeInfo,
                            isCalculating: routeManager.isCalculating,
                            onClear: clearRoute,
                            onStartNavigation: nil // Opcional: implementar navegación
                        )
                        .padding(.horizontal)
                        .padding(.bottom, bottomBarHeight + 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if let errorMessage = routeManager.errorMessage {
                        RouteErrorView(message: errorMessage, onDismiss: {
                            routeManager.clearRoute()
                        })
                        .padding(.horizontal)
                        .padding(.bottom, bottomBarHeight + 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }

            // Barra de búsqueda inferior
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
            .padding(.bottom, 10)
            .fadeIn(delay: 0.1)

            // Botones flotantes (ocultar cuando búsqueda está activa)
            if !isSearchFocused {
                floatingButtons
                    .padding(.bottom, bottomBarHeight + 10)
            }
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
                // 🎯 Calcular flechas direccionales
                routeArrows = routeManager.calculateDirectionalArrows()

                // 🌈 Inicializar animaciones de polyline
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    dashPhase = 25  // Marching ants
                }

                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    hueRotation = 360  // Shimmer gradiente
                }

                // ⚡ Generar partículas viajeras
                travelingParticles = routeManager.generateTravelingParticles(count: 5)
                startParticleAnimation()

                // 🔮 Iniciar timer de pulsos de energía
                startEnergyPulseTimer()

                // 🌟 Generar puntos elevados multicolor
                multicolorPoints = routeManager.generateMulticolorElevatedPoints()

                print("✅ Animación suprema iniciada!")
                print("   - Flechas: \(routeArrows.count)")
                print("   - Partículas: \(travelingParticles.count)")
                print("   - Puntos multicolor: \(multicolorPoints.count)")

            } else {
                // Limpiar todo al quitar ruta
                stopAllAnimations()
                routeArrows = []
                travelingParticles = []
                energyPulses = []
                multicolorPoints = []
                dashPhase = 0
                hueRotation = 0
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

                // 🌈 SUPREME ROUTE ANIMATION - 5 CAPAS COMBINADAS 🌈
                if let routeInfo = routeManager.currentRoute {

                    // ✨ CAPA 1: Gradiente Multicolor Brillante
                    MapPolyline(routeInfo.polyline)
                        .stroke(
                            Gradient(colors: [.cyan, .blue, .purple, .pink]),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                        )

                    // 🔷 CAPA 2: Marching Ants Overlay (blanco semitransparente)
                    MapPolyline(routeInfo.polyline)
                        .stroke(
                            .white.opacity(0.6),
                            style: StrokeStyle(
                                lineWidth: 6,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [12, 8],
                                dashPhase: dashPhase
                            )
                        )
                }

                // ⚡ CAPA 3: Partículas Viajando con Trail
                ForEach(travelingParticles) { particle in
                    Annotation("", coordinate: particle.coordinate) {
                        TravelingParticleView(particle: particle)
                    }
                    .annotationTitles(.hidden)
                }

                // 🔮 CAPA 4: Pulsos de Energía
                ForEach(energyPulses) { pulse in
                    Annotation("", coordinate: pulse.coordinate) {
                        EnergyPulseView(pulse: pulse)
                    }
                    .annotationTitles(.hidden)
                }

                // 🌟 CAPA 5: Puntos Elevados Multicolor con Glow
                ForEach(multicolorPoints) { point in
                    Annotation("", coordinate: point.coordinate) {
                        ElevatedRoutePoint(index: point.index, total: multicolorPoints.count)
                    }
                    .annotationTitles(.hidden)
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
        guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }

        if routingMode {
            // Modo ruteo: establecer destino y calcular ruta
            setDestination(at: coordinate)
        } else {
            // Modo normal: mostrar sheet de alertas
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

            // Limpiar búsqueda y cerrar teclado
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                searchManager.clearSearch()
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

    // MARK: - Supreme Animation Methods

    private func startParticleAnimation() {
        // Detener timer anterior si existe
        particleTimer?.invalidate()

        // Timer para actualizar partículas cada 0.1s
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            guard !travelingParticles.isEmpty else { return }

            // Actualizar cada partícula
            for i in 0..<travelingParticles.count {
                var particle = travelingParticles[i]
                // Incrementar progreso (0.02 = 2% cada 0.1s = viaje completo en 5s)
                particle.progress += 0.02

                // Si llega al final, reiniciar al inicio
                if particle.progress >= 1.0 {
                    particle.progress = 0.0
                }

                // Actualizar posición usando RouteManager
                travelingParticles[i] = routeManager.updateParticle(particle, progress: particle.progress)
            }
        }
    }

    private func startEnergyPulseTimer() {
        // Detener timer anterior si existe
        pulseTimer?.invalidate()

        // Timer para crear pulsos cada 5 segundos
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [self] _ in
            guard let polyline = routeManager.currentRoute?.route.polyline,
                  let startPoint = polyline.pointAt(fraction: 0.0) else { return }

            // Crear nuevo pulso en el inicio
            let pulse = EnergyPulse(coordinate: startPoint, progress: 0, scale: 1.0, opacity: 1.0)
            energyPulses.append(pulse)

            // Animar el pulso a lo largo de la ruta
            animateEnergyPulse(pulse)
        }

        // Crear primer pulso inmediatamente
        if let polyline = routeManager.currentRoute?.route.polyline,
           let startPoint = polyline.pointAt(fraction: 0.0) {
            let pulse = EnergyPulse(coordinate: startPoint, progress: 0, scale: 1.0, opacity: 1.0)
            energyPulses.append(pulse)
            animateEnergyPulse(pulse)
        }
    }

    private func animateEnergyPulse(_ pulse: EnergyPulse) {
        // Timer para actualizar pulso cada 0.05s durante 3s
        var currentProgress: Double = 0.0
        let updateInterval: TimeInterval = 0.05
        let duration: TimeInterval = 3.0
        let steps = Int(duration / updateInterval)

        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            currentProgress += 1.0 / Double(steps)

            if currentProgress >= 1.0 {
                timer.invalidate()
                // Remover pulso cuando termine
                energyPulses.removeAll { $0.id == pulse.id }
                return
            }

            // Actualizar pulso en el array
            if let index = energyPulses.firstIndex(where: { $0.id == pulse.id }) {
                var updatedPulse = energyPulses[index]
                updatedPulse.update(progress: currentProgress)

                // Actualizar coordenada a lo largo de la ruta
                if let polyline = routeManager.currentRoute?.route.polyline,
                   let newCoord = polyline.pointAt(fraction: currentProgress) {
                    updatedPulse.coordinate = newCoord
                }

                energyPulses[index] = updatedPulse
            }
        }
    }

    private func stopAllAnimations() {
        particleTimer?.invalidate()
        particleTimer = nil

        pulseTimer?.invalidate()
        pulseTimer = nil

        print("⏹️ Todas las animaciones detenidas")
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
