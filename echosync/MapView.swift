//
//  MapView.swift
//  echo sync
//
//  Created by Owner on 6/12/25.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Model
struct MapPin: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let colorName: String
    let address: String
}

// MARK: - ViewModel
@MainActor
class MapViewModel: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 44.0, longitude: -93.0),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @Published var pins: [MapPin] = []
    @Published var showingAddPin = false
    @Published var newPinCoordinate: CLLocationCoordinate2D?
    @Published var newPinName = ""
    @Published var newPinColor = "red"

    let colors = ["red", "blue", "green", "orange", "pink", "purple"]
    private let fileName = "savedPins.json"
    private let geocoder = CLGeocoder()

    init() {
        loadPins()
        requestLocation()
    }

    func requestLocation() {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        if let coord = manager.location?.coordinate {
            region.center = coord
        }
    }

    func beginAddPin(at coordinate: CLLocationCoordinate2D) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            newPinCoordinate = coordinate
            newPinName = ""
            newPinColor = "red"
            showingAddPin = true
        }
    }

    func addPin() {
        guard let coord = newPinCoordinate else { return }
        Task {
            let address = await reverseGeocode(coord)
            let pin = MapPin(
                id: UUID(),
                name: newPinName.isEmpty ? "Unnamed Pin" : newPinName,
                latitude: coord.latitude,
                longitude: coord.longitude,
                colorName: newPinColor,
                address: address
            )
            await MainActor.run {
                pins.append(pin)
                savePins()
                showingAddPin = false
                newPinCoordinate = nil
            }
        }
    }

    func deletePin(_ pin: MapPin) {
        pins.removeAll { $0.id == pin.id }
        savePins()
    }

    private func savePins() {
        let url = documentsURL.appendingPathComponent(fileName)
        if let data = try? JSONEncoder().encode(pins) {
            try? data.write(to: url)
        }
    }

    private func loadPins() {
        let url = documentsURL.appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode([MapPin].self, from: data) {
            pins = loaded
        }
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> String {
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let placemark = try? await geocoder.reverseGeocodeLocation(loc).first {
            var parts = [String]()
            if let n = placemark.name { parts.append(n) }
            if let l = placemark.locality { parts.append(l) }
            if let s = placemark.administrativeArea { parts.append(s) }
            return parts.joined(separator: ", ")
        }
        return "Unknown Address"
    }
}

// MARK: - MapView
struct MapView: View {
    @StateObject private var vm = MapViewModel()
    @State private var showingPinList = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [.blue, .black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                Map(coordinateRegion: $vm.region,
                    showsUserLocation: true,
                    annotationItems: vm.pins) { pin in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude,
                                                                     longitude: pin.longitude)) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(colorFromName(pin.colorName))
                    }
                }
                .mapStyle(.hybrid)
                .gesture(
                    LongPressGesture(minimumDuration: 1)
                        .onEnded { _ in
                            vm.beginAddPin(at: vm.region.center)
                        }
                )
            }
            .navigationTitle("Map")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingPinList = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.pink)
                    }
                }
            }
            .sheet(isPresented: $vm.showingAddPin) {
                AddPinView(vm: vm)
            }
            .sheet(isPresented: $showingPinList) {
                PinListView(vm: vm, isPresented: $showingPinList)
            }
        }
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        default: return .pink
        }
    }
}

// MARK: - PinListView
struct PinListView: View {
    @ObservedObject var vm: MapViewModel
    @Binding var isPresented: Bool
    @State private var pinToDelete: MapPin?
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationView {
            List {
                ForEach(vm.pins) { pin in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pin.name).foregroundColor(.pink)
                        Text(pin.address).font(.caption).foregroundColor(.white)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            pinToDelete = pin
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        .tint(.pink)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Your Pins")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.pink)
                }
            }
            .alert("Delete Pin?", isPresented: $showingDeleteAlert, presenting: pinToDelete) { pin in
                Button("Delete", role: .destructive) {
                    vm.deletePin(pin)
                }
                Button("Cancel", role: .cancel) {}
            } message: { pin in
                Text("Are you sure you want to delete \"\(pin.name)\"?")
            }
        }
    }
}

// MARK: - AddPinView
struct AddPinView: View {
    @ObservedObject var vm: MapViewModel

    var body: some View {
        NavigationView {
            Form {
                Section("Pin Name") {
                    TextField("Enter name", text: $vm.newPinName)
                        .foregroundColor(.pink)
                }
                Section("Pin Color") {
                    Picker("Color", selection: $vm.newPinColor) {
                        ForEach(vm.colors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(colorFromName(color))
                                    .frame(width: 20, height: 20)
                                Text(color.capitalized)
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }
            .navigationTitle("New Pin")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.addPin() }
                        .foregroundColor(.pink)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.showingAddPin = false }
                        .foregroundColor(.pink)
                }
            }
        }
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        default: return .pink
        }
    }
}
