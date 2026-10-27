import SwiftUI
import MapKit
import CoreLocation

struct DirectionsSearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    var userLocation: CLLocationCoordinate2D?
    var onDestinationSelected: (CLLocationCoordinate2D, String) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                    
                    TextField("Search for a place or address", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.words)
                        .onChange(of: searchText) { _, newValue in
                            if !newValue.isEmpty {
                                searchForLocations(query: newValue)
                            } else {
                                searchResults = []
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 8)
                    }
                }
                .padding(10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Search results
                if isSearching {
                    ProgressView()
                        .padding()
                } else if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { result in
                        Button(action: {
                            selectDestination(result)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.name ?? "Unknown")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let address = result.placemark.title {
                                    Text(address)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else if !searchText.isEmpty {
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                            .padding()
                        Text("No results found")
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    VStack {
                        Image(systemName: "map.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                            .padding()
                        Text("Search for a destination")
                            .foregroundColor(.gray)
                        Text("Type an address or place name")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Search Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func searchForLocations(query: String) {
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        // Use user location for better results
        if let userLocation = userLocation {
            request.region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            if let error = error {
                errorMessage = "Search error: \(error.localizedDescription)"
                showError = true
                return
            }
            
            searchResults = response?.mapItems ?? []
        }
    }
    
    private func selectDestination(_ mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        let name = mapItem.name ?? mapItem.placemark.title ?? "Selected Location"
        onDestinationSelected(coordinate, name)
        dismiss()
    }
}
