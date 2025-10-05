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
    @Binding var showBusinessPulse: Bool
    @StateObject private var locationManager = LocationManager()

    init(showBusinessPulse: Binding<Bool>) {
        self._showBusinessPulse = showBusinessPulse
    }

    var body: some View {
        EnhancedMapView(
            locationManager: locationManager,
            showPulse: $showBusinessPulse
        )
        .ignoresSafeArea()
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
    @StateObject private var routePreferences = RoutePreferencesModel()
    @StateObject private var routeAnimations = RouteAnimationController()
    @State private var routingMode: Bool = false
    @State private var destination: DestinationPoint?
    @State private var showRoutePreferences: Bool = false
    @State private var selectedRouteIndex: Int? = nil

    // MARK: - Location Info State
    @State private var showLocationInfo: Bool = false
    @State private var selectedLocationInfo: LocationInfo?

    // MARK: - Search State
    @StateObject private var searchManager = LocationSearchManager()
    @FocusState private var isSearchFocused: Bool
    @State private var showRouteToast = false
    @State private var routeToastMessage = ""

    // MARK: - Route Arrows State
    @State private var routeArrows: [RouteArrowAnnotation] = []

    // MARK: - Route Animation State (Optimizado)
    @State private var dashPhase: CGFloat = 0  // Marching ants

    // MARK: - Air Quality Overlay State
    @StateObject private var airQualityGridManager = AirQualityGridManager()
    @State private var showAirQualityLayer: Bool = false
    @State private var showAirQualityLegend: Bool = false
    @State private var selectedZone: AirQualityZone?
    @State private var showZoneDetail: Bool = false

    // MARK: - App Settings (Performance Controls)
    @StateObject private var appSettings = AppSettings.shared

    // Enhanced tab bar height - usando constante global
    private let tabBarHeight: CGFloat = AppConstants.enhancedTabBarTotalHeight

    // Computed property para verificar si hay ruta activa
    private var hasActiveRoute: Bool {
        routeManager.currentRoute != nil || routeManager.isCalculating
    }

    // MARK: - Proximity Filtering (10km Radius)

    /// Zonas de calidad del aire dentro del rango de visibilidad (10km)
    private var visibleAirQualityZones: [AirQualityZone] {
        guard let userLocation = locationManager.userLocation else {
            return airQualityGridManager.zones
        }

        guard appSettings.enableProximityFiltering else {
            return airQualityGridManager.zones
        }

        return ProximityFilter.filterZones(
            airQualityGridManager.zones,
            from: userLocation,
            maxRadius: appSettings.proximityRadiusMeters
        )
    }

    /// Alerts dentro del rango de visibilidad (10km)
    private var visibleAnnotations: [CustomAnnotation] {
        guard let userLocation = locationManager.userLocation else {
            return annotations
        }

        guard appSettings.enableProximityFiltering else {
            return annotations
        }

        return ProximityFilter.filterAnnotations(
            annotations,
            from: userLocation,
            maxRadius: appSettings.proximityRadiusMeters
        )
    }

    /// Route arrows dentro del rango de visibilidad (10km)
    private var visibleRouteArrows: [RouteArrowAnnotation] {
        guard let userLocation = locationManager.userLocation else {
            return routeArrows
        }

        guard appSettings.enableProximityFiltering else {
            return routeArrows
        }

        return ProximityFilter.filterRouteArrows(
            routeArrows,
            from: userLocation,
            maxRadius: appSettings.proximityRadiusMeters
        )
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

            // Controles superiores: barra de búsqueda
            VStack(alignment: .leading, spacing: 0) {
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
                .layoutPriority(1)
                .fadeIn(delay: 0.1)
                .padding(.horizontal)
                .padding(.top, AppConstants.safeAreaTop + 12)

                if !searchManager.searchResults.isEmpty || searchManager.isSearching {
                    SearchResultsView(
                        results: searchManager.searchResults,
                        isSearching: searchManager.isSearching,
                        userLocation: locationManager.userLocation,
                        onSelect: handleSearchResultSelection
                    )
                    .padding(.horizontal)
                    .padding(.top, -10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }

            // Route Preference Selector (sheet modal)
            if showRoutePreferences {
                RoutePreferenceSelector(
                    isPresented: $showRoutePreferences,
                    preferences: routePreferences,
                    onApply: {
                        // Aplicar nuevas preferencias
                        applyRoutePreferences()

                        // Recalcular rutas con nuevas preferencias
                        if let destination = destination {
                            guard let userLocation = locationManager.userLocation else { return }

                            // Actualizar zonas de calidad del aire en RouteManager
                            routeManager.updateAirQualityZones(airQualityGridManager.zones)

                            // Recalcular
                            routeManager.calculateRoute(from: userLocation, to: destination.coordinate)
                        }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(100)
            }

            // Location Info Card (cuando se hace long press)
            if !isSearchFocused && showLocationInfo, let locationInfo = selectedLocationInfo {
                VStack {
                    Spacer()

                    LocationInfoCard(
                        locationInfo: locationInfo,
                        onCalculateRoute: {
                            // Calcular ruta desde ubicación actual al punto seleccionado
                            guard let userLocation = locationManager.userLocation else { return }

                            // Ocultar location info card
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showLocationInfo = false
                            }

                            // Actualizar datos en el RouteManager
                            routeManager.updateActiveIncidents(annotations)
                            routeManager.updateAirQualityZones(airQualityGridManager.zones)

                            // Aplicar preferencias
                            applyRoutePreferences()

                            // Calcular ruta considerando todos los factores
                            routeManager.calculateRoute(from: userLocation, to: locationInfo.coordinate)

                            // Hacer zoom para mostrar toda la ruta después de calcularla
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                zoomToRoute()
                            }

                            // Mostrar toast
                            showRouteToast(to: locationInfo.title)
                        },
                        onCancel: {
                            // Limpiar destino y ocultar card
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showLocationInfo = false
                                selectedLocationInfo = nil
                                destination = nil
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal)
                    .padding(.bottom, tabBarHeight + 12)
                }
            }

            // Route Info Card o Calculating Indicator
            if !isSearchFocused && !showLocationInfo {
                VStack {
                    Spacer()

                    // Contenido de ruta
                    VStack(spacing: 12) {
                        // Selector de rutas múltiples
                        if !routeManager.allScoredRoutes.isEmpty {
                            RouteCardsSelector(
                                routes: routeManager.allScoredRoutes,
                                selectedIndex: $selectedRouteIndex,
                                onSelectRoute: { index in
                                    routeManager.selectRoute(at: index)

                                    // Haptic feedback
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if routeManager.isCalculating {
                            CalculatingRouteView()
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if let routeInfo = routeManager.currentRoute {
                            RouteInfoCard(
                                routeInfo: routeInfo,
                                scoredRoute: routeManager.currentScoredRoute,
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
                    .padding(.horizontal)
                    .padding(.bottom, tabBarHeight + 12)
                }
            }

            // Enhanced Air Quality Dashboard (superior derecha)
            if showAirQualityLayer && !isSearchFocused {
                VStack {
                    HStack {
                        Spacer()

                        // Enhanced Dashboard con gráficos y breathability integrado
                        EnhancedAirQualityDashboard(
                            isExpanded: $showAirQualityLegend,
                            statistics: airQualityGridManager.getStatistics()
                        )
                        .frame(maxWidth: 320)
                        .padding(.trailing)
                    }
                    .padding(.top, AppConstants.safeAreaTop + 80)

                    Spacer()
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // Hero Air Quality Card (cuando se toca una zona)
            if showZoneDetail, let zone = selectedZone, !isSearchFocused {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showZoneDetail = false
                            selectedZone = nil
                        }
                    }

                VStack {
                    Spacer()

                    HeroAirQualityCard(zone: zone) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showZoneDetail = false
                            selectedZone = nil
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 20)
                    .padding(.bottom, tabBarHeight + 12)

                    Spacer()
                        .frame(height: 40)
                }
            }

            // Botones flotantes (ocultar cuando búsqueda está activa, hay ruta, o se muestra location info)
            if !isSearchFocused && !hasActiveRoute && !showLocationInfo {
                floatingButtons
                    .padding(.bottom, tabBarHeight + 20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Actualizar región de búsqueda inicial
            if let location = locationManager.userLocation {
                searchManager.updateSearchRegion(center: location)
            }
        }
        .onChange(of: showAirQualityLayer) { _, newValue in
            if newValue {
                // Activar capa de calidad del aire
                if let userLocation = locationManager.userLocation {
                    airQualityGridManager.startAutoUpdate(center: userLocation)
                }
            } else {
                // Desactivar capa
                airQualityGridManager.stopAutoUpdate()
            }
        }
        .onReceive(locationManager.$userLocation) { newLocation in
            // Actualizar región de búsqueda cuando cambie ubicación del usuario
            if let location = newLocation {
                searchManager.updateSearchRegion(center: location)

                // Actualizar grid de calidad del aire si está activo
                if showAirQualityLayer {
                    airQualityGridManager.updateGrid(center: location)
                }
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
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "2b4c9c"),
                    Color(hex: "65c2c8")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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
                    }
                }

                // Alert annotations (filtradas por proximidad)
                ForEach(visibleAnnotations) { annotation in
                    Annotation(annotation.title, coordinate: annotation.coordinate) {
                        AlertAnnotationView(
                            alertType: annotation.alertType,
                            showPulse: true
                        )
                        .onTapGesture {
                            selectedAnnotation = annotation
                        }
                    }
                }

                // Destination annotation (Punto B)
                if let dest = destination {
                    Annotation(dest.title, coordinate: dest.coordinate) {
                        DestinationAnnotationView()
                            .onTapGesture {
                                // Opcional: mostrar detalles del destino
                            }
                    }
                }

                // 🎨 MÚLTIPLES RUTAS OPTIMIZADAS
                if !routeManager.allScoredRoutes.isEmpty {
                    MultiRouteOverlay(
                        scoredRoutes: routeManager.allScoredRoutes,
                        selectedIndex: selectedRouteIndex,
                        animationPhase: dashPhase
                    )
                } else if let routeInfo = routeManager.currentRoute {
                    // Fallback: ruta única (modo legacy)
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
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
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
                                lineWidth: 3,
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
                            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                        )
                }

                // Directional arrows along route (filtradas por proximidad)
                ForEach(Array(visibleRouteArrows.enumerated()), id: \.element.id) { index, arrow in
                    Annotation("", coordinate: arrow.coordinate) {
                        DirectionalArrowView(
                            heading: arrow.heading,
                            isNext: index == 0, // Primera flecha es la siguiente
                            size: 30
                        )
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

                // 🌍 AIR QUALITY ZONES OVERLAY - Optimized (Proximity Filtered + Static)
                if showAirQualityLayer {
                    ForEach(Array(visibleAirQualityZones.enumerated()), id: \.element.id) { index, zone in
                        // MapCircle estático para mostrar área de cobertura (500m radius)
                        MapCircle(center: zone.coordinate, radius: zone.radius)
                            .foregroundStyle(zone.fillColor)
                            .stroke(zone.strokeColor, lineWidth: 0.5)

                        // Annotation estático con icono central (sin animaciones)
                        Annotation("", coordinate: zone.coordinate) {
                            EnhancedAirQualityOverlay(
                                zone: zone,
                                isVisible: showAirQualityLayer,
                                index: index,
                                settingsKey: "\(appSettings.enableAirQualityRotation)"
                            )
                            .environmentObject(appSettings)
                            .onTapGesture {
                                handleZoneTap(zone)
                            }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(mapStyle.style)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        switch value {
                        case .second(true, let drag):
                            if let location = drag?.location {
                                handleLongPress(at: location, with: proxy)
                            }
                        default:
                            break
                        }
                    }
            )
            .onTapGesture(coordinateSpace: .local) { screenPoint in
                handleMapTap(at: screenPoint, with: proxy)
            }
            }
        }
    }

    private var floatingButtons: some View {
        HStack {
            VStack(spacing: 15) {
                // Location button
                FloatingActionButton(
                    icon: "location.fill",
                    color: .green,
                    size: 50
                ) {
                    centerOnUser()
                }

                // Map style button
                FloatingActionButton(
                    icon: mapStyle.icon,
                    color: .purple,
                    size: 50
                ) {
                    cycleMapStyle()
                }

                // Air Quality Layer button
                FloatingActionButton(
                    icon: "aqi.medium",
                    color: showAirQualityLayer ? .blue : .gray,
                    size: 50,
                    isPrimary: showAirQualityLayer
                ) {
                    toggleAirQualityLayer()
                }

                // Route Preferences button (solo si hay ruta activa)
                if routeManager.currentRoute != nil {
                    FloatingActionButton(
                        icon: "slider.horizontal.3",
                        color: .orange,
                        size: 50
                    ) {
                        showRoutePreferences = true
                    }
                }
            }
            .padding(.leading, 20)

            Spacer()
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

    private func handleLongPress(at screenPoint: CGPoint, with proxy: MapProxy) {
        guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }

        // Haptic feedback fuerte para indicar long press detectado
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // Centrar cámara en el punto seleccionado
        centerCamera(on: coordinate, distance: 800)

        // Generar datos de calidad del aire simulados para esta ubicación
        let airQuality = AirQualityDataGenerator.shared.generateAirQuality(
            for: coordinate,
            includeExtendedMetrics: true
        )

        print("📊 AQI generado para \(coordinate.latitude), \(coordinate.longitude): \(Int(airQuality.aqi)) (\(airQuality.level.rawValue))")

        // Obtener información del lugar con reverse geocoding
        searchManager.reverseGeocode(coordinate: coordinate) { address in
            DispatchQueue.main.async {
                // Calcular distancia desde el usuario
                let distanceText: String
                if let userLocation = locationManager.userLocation {
                    let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    let selectedCLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    let distance = userCLLocation.distance(from: selectedCLLocation)

                    if distance < 1000 {
                        distanceText = String(format: "%.0f m de tu ubicación", distance)
                    } else {
                        distanceText = String(format: "%.1f km de tu ubicación", distance / 1000.0)
                    }
                } else {
                    distanceText = "Ubicación desconocida"
                }

                // Dividir dirección para obtener nombre y detalles
                let parsedAddress = splitAddress(address)

                // Crear LocationInfo con datos enriquecidos
                let locationInfo = LocationInfo(
                    coordinate: coordinate,
                    title: parsedAddress.title,
                    subtitle: parsedAddress.subtitle,
                    distanceFromUser: distanceText,
                    airQuality: airQuality
                )

                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedLocationInfo = locationInfo
                    showLocationInfo = true
                }

                // Actualizar destino para mostrar etiqueta adecuada en el mapa
                destination = DestinationPoint(
                    coordinate: coordinate,
                    title: parsedAddress.title,
                    subtitle: parsedAddress.subtitle
                )
            }
        }
    }

    /// Divide la dirección recibida en un título principal y detalles opcionales
    private func splitAddress(_ address: String?) -> (title: String, subtitle: String?) {
        guard let rawAddress = address?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawAddress.isEmpty else {
            return ("Ubicación Seleccionada", nil)
        }

        let components = rawAddress
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let firstComponent = components.first else {
            return (rawAddress, nil)
        }

        let remaining = components.dropFirst().joined(separator: ", ")
        return (String(firstComponent), remaining.isEmpty ? nil : remaining)
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

    private func setDestination(at coordinate: CLLocationCoordinate2D, title: String = "Destination", subtitle: String? = nil, calculateRoute: Bool = true) {
        // Establecer destino con nombre
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            destination = DestinationPoint(
                coordinate: coordinate,
                title: title,
                subtitle: subtitle
            )
        }

        // Solo calcular ruta si se solicita
        if calculateRoute {
            guard let origin = locationManager.userLocation else {
                print("⚠️ No se puede calcular ruta sin ubicación del usuario")
                return
            }

            // Actualizar datos en el RouteManager
            routeManager.updateActiveIncidents(annotations)
            routeManager.updateAirQualityZones(airQualityGridManager.zones)

            // Aplicar preferencias
            applyRoutePreferences()

            // Calcular ruta considerando todos los factores
            routeManager.calculateRoute(from: origin, to: coordinate)

            // Hacer zoom para mostrar toda la ruta después de calcularla con delay mayor
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                zoomToRoute()
            }
        }
    }

    private func clearRoute() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            destination = nil
            routeManager.clearRoute()
            selectedRouteIndex = nil
        }
    }

    private func applyRoutePreferences() {
        // Determinar la preferencia basada en los pesos
        let preference: RoutePreference

        if routePreferences.speedWeight > 0.6 {
            preference = .fastest
        } else if routePreferences.safetyWeight > 0.5 {
            preference = .safest
        } else if routePreferences.airQualityWeight > 0.5 {
            preference = .cleanestAir
        } else if routePreferences.safetyWeight > 0.3 && routePreferences.airQualityWeight > 0.3 {
            preference = .balancedSafety
        } else {
            preference = .balanced
        }

        routeManager.setPreference(preference)
    }

    private func zoomToRoute() {
        guard let mapRect = routeManager.getRouteBounds() else { return }

        // Convertir MKMapRect a región para la cámara con padding extra para ver toda la ruta
        var region = MKCoordinateRegion(mapRect)

        // Expandir región 50% para dar espacio visual
        region.span.latitudeDelta *= 1.5
        region.span.longitudeDelta *= 1.5

        withAnimation(.easeInOut(duration: 1.5)) {
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

    // MARK: - Air Quality Methods

    private func toggleAirQualityLayer() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showAirQualityLayer.toggle()

            // Expandir leyenda automáticamente la primera vez
            if showAirQualityLayer && !showAirQualityLegend {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAirQualityLegend = true
                    }
                }
            }
        }

        // Si se activa, inicializar grid
        if showAirQualityLayer, let userLocation = locationManager.userLocation {
            airQualityGridManager.startAutoUpdate(center: userLocation)
        }
    }

    private func handleZoneTap(_ zone: AirQualityZone) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Mostrar detalle de la zona
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedZone = zone
            showZoneDetail = true
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
    ContentView(showBusinessPulse: .constant(false))
}
