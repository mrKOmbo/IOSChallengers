import Foundation
import MapKit
import Combine

/// A simple search manager that performs local place searches using MapKit
/// and exposes results and loading state for SwiftUI bindings.
final class LocationSearchManager: ObservableObject {
    // MARK: - Published State
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var searchQuery: String = "" {
        didSet { performSearchIfNeeded() }
    }

    // MARK: - Private State
    private var searchRegion: MKCoordinateRegion?
    private var currentSearch: MKLocalSearch?

    // MARK: - Public API

    /// Update the preferred search region around a coordinate.
    func updateSearchRegion(center: CLLocationCoordinate2D) {
        // Use a reasonable default span (~5km x 5km)
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        searchRegion = MKCoordinateRegion(center: center, span: span)
    }

    /// Clear the current search query and results.
    func clearSearch() {
        currentSearch?.cancel()
        currentSearch = nil
        searchQuery = ""
        searchResults = []
        isSearching = false
    }

    /// Resolve the coordinate for a given result. If the result already has a map item,
    /// use it, otherwise issue a lightweight search to find the first matching item.
    func selectResult(_ result: SearchResult, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        if let coordinate = result.mapItem?.placemark.coordinate {
            completion(coordinate)
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [result.title, result.subtitle].joined(separator: " ")
        if let region = searchRegion { request.region = region }

        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            let coordinate = response?.mapItems.first?.placemark.coordinate
            completion(coordinate)
        }
    }

    // MARK: - Internal Search Logic

    private func performSearchIfNeeded() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            // Empty query: clear results and stop searching
            currentSearch?.cancel()
            currentSearch = nil
            searchResults = []
            isSearching = false
            return
        }
        performSearch(query: query)
    }

    private func performSearch(query: String) {
        // Cancel any in-flight search
        currentSearch?.cancel()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region = searchRegion { request.region = region }

        isSearching = true
        let search = MKLocalSearch(request: request)
        currentSearch = search
        search.start { [weak self] response, error in
            guard let self = self else { return }
            defer {
                self.isSearching = false
                if self.currentSearch === search { self.currentSearch = nil }
            }

            if let items = response?.mapItems, error == nil {
                self.searchResults = items.map { item in
                    SearchResult(title: item.name ?? "Unknown", subtitle: item.placemark.title ?? "", mapItem: item)
                }
            } else {
                self.searchResults = []
            }
        }
    }
}

/// A simple model representing a place search result for use in SwiftUI lists.
struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    /// Optional MKMapItem for direct coordinate access when available.
    let mapItem: MKMapItem?
}
