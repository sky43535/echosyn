//
//  WeatherView.swift
//  echo sync
//
//  Created by Owner on 6/11/25.
import SwiftUI
import CoreLocation
import WeatherKit

@MainActor
struct WeatherView: View {
    @StateObject private var weatherManager = WeatherManager()
    @State private var weather: Weather?
    @State private var location: CLLocation?
    @State private var useFahrenheit = true
    @Environment(\.dismiss) var dismiss

    private let weatherService = WeatherService()
    private let locationManager = CLLocationManager()

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue, .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    Button(action: { useFahrenheit = true }) {
                        Image(systemName: "degreesign.fahrenheit")
                            .foregroundColor(useFahrenheit ? .pink : .gray)
                    }
                    Button(action: { useFahrenheit = false }) {
                        Image(systemName: "degreesign.celsius")
                            .foregroundColor(!useFahrenheit ? .pink : .gray)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrowshape.turn.up.backward.fill")
                            .foregroundColor(.mint)
                    }
                }
                .font(.title2)
                .padding(.horizontal)

                if let weather = weather {
                    VStack(spacing: 16) {
                        Text("Current Weather")
                            .font(.title)
                            .foregroundColor(.pink)

                        weatherRow(icon: "thermometer.sun.fill",
                                   text: "\(formatTemp(weather.currentWeather.temperature)) (Feels like \(formatTemp(weather.currentWeather.apparentTemperature)))")
                        weatherRow(icon: "wind",
                                   text: "\(formatWind(weather.currentWeather.wind.speed)) mph")
                        weatherRow(icon: "cloud.rain.fill",
                                   text: "Rain Chance: \(String(format: "%.0f", weather.dailyForecast.forecast.first?.precipitationChance ?? 0))%")
                        weatherRow(icon: "sunrise.fill",
                                   text: "Sunrise: \(formatTime(weather.dailyForecast.forecast.first?.sun.sunrise))")
                        weatherRow(icon: "sunset.fill",
                                   text: "Sunset: \(formatTime(weather.dailyForecast.forecast.first?.sun.sunset))")

                        Text("Hourly Forecast")
                            .font(.headline)
                            .foregroundColor(.pink)
                            .padding(.top)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(weather.hourlyForecast.forecast.prefix(12), id: \.date) { hour in
                                    VStack {
                                        Text(formatHour(hour.date))
                                            .foregroundColor(.pink)
                                        Image(systemName: iconForCondition(hour.condition))
                                            .foregroundColor(.mint)
                                        Text(formatTemp(hour.temperature))
                                            .foregroundColor(.pink)
                                    }
                                    .frame(width: 60)
                                }
                            }
                        }

                        Text("Daily Forecast")
                            .font(.headline)
                            .foregroundColor(.pink)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(weather.dailyForecast.forecast.prefix(7), id: \.date) { day in
                                    VStack {
                                        Text(formatDay(day.date))
                                            .foregroundColor(.pink)
                                        Image(systemName: iconForCondition(day.condition))
                                            .foregroundColor(.yellow)
                                        Text("\(formatTemp(day.highTemperature)) / \(formatTemp(day.lowTemperature))")
                                            .foregroundColor(.pink)
                                    }
                                    .frame(width: 80)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    ProgressView("Loading Weather...")
                        .foregroundColor(.pink)
                        .padding()
                }
            }
        }
        .onAppear(perform: fetchLocation)
    }

    func weatherRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.mint)
            Text(text)
                .foregroundColor(.pink)
            Spacer()
        }
        .padding(.horizontal)
    }

    func fetchLocation() {
        Task {
            let manager = CLLocationManager()
            manager.requestWhenInUseAuthorization()
            if let loc = manager.location {
                location = loc
                await fetchWeather(for: loc)
            }
        }
    }

    func fetchWeather(for location: CLLocation) async {
        do {
            self.weather = try await weatherService.weather(for: location)
        } catch {
            print("Failed to fetch weather: \(error)")
        }
    }

    func formatTemp(_ measurement: Measurement<UnitTemperature>) -> String {
        let temp = useFahrenheit ? measurement.converted(to: .fahrenheit) : measurement.converted(to: .celsius)
        return String(format: "%.0f°", temp.value)
    }

    func formatWind(_ measurement: Measurement<UnitSpeed>) -> String {
        let mph = measurement.converted(to: .milesPerHour)
        return String(format: "%.0f", mph.value)
    }

    func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }

    func formatDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    func iconForCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: return "sun.max.fill"
        case .mostlyClear: return "sun.max"
        case .partlyCloudy: return "cloud.sun.fill"
        case .mostlyCloudy: return "cloud.fill"
        case .cloudy: return "smoke.fill"
        case .foggy: return "cloud.fog.fill"
        case .haze: return "sun.haze.fill"
        case .rain: return "cloud.rain.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .thunderstorms: return "cloud.bolt.rain.fill"
        case .snow: return "snow"
        case .flurries: return "cloud.snow.fill"
        case .freezingRain: return "cloud.sleet.fill"
        case .blizzard: return "wind.snow"
        default: return "cloud.fill"
        }
    }
}
