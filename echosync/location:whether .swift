//
//  location:whether .swift
//  echo sync
//
//  Created by Owner on 6/11/25.
//

import CoreLocation
import WeatherKit
import Combine

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let service = WeatherService()
    private var locationManager = CLLocationManager()

    @Published var weather: Weather?
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        currentLocation = loc
        fetchWeather(for: loc)
        locationManager.stopUpdatingLocation()
    }

    func fetchWeather(for location: CLLocation) {
        Task {
            do {
                let weather = try await service.weather(for: location)
                DispatchQueue.main.async {
                    self.weather = weather
                }
            } catch {
                print("WeatherKit error: \(error)")
            }
        }
    }
}
