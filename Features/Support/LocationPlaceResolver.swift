//
//  LocationPlaceResolver.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
//

import CoreLocation
import Foundation
import Observation

enum LocationResolveError: Error, LocalizedError {
    case permissionDenied
    case locationUnavailable
    case geocodeFailed
    case municipalityNotMatched

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return L10n.t("locate_error_denied")
        case .locationUnavailable: return L10n.t("locate_error_unavailable")
        case .geocodeFailed: return L10n.t("locate_error_geocode")
        case .municipalityNotMatched: return L10n.t("locate_error_nomatch")
        }
    }
}

/// CoreLocation + CLGeocoder（ja_JP）解析当前市区町村。
@Observable
@MainActor
final class LocationPlaceResolver: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPlaceResolver()

    private(set) var isLocating = false
    private(set) var lastError: String?

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func resolveMunicipality(in catalog: RegionCatalog) async throws -> (PrefectureEntry, CatalogCityEntry) {
        isLocating = true
        lastError = nil
        defer { isLocating = false }

        let location = try await requestLocation()
        let placemark = try await reverseGeocodeJapan(location)
        guard let matched = MunicipalityMatcher.match(
            in: catalog,
            administrativeArea: placemark.administrativeArea,
            locality: placemark.locality,
            subLocality: placemark.subLocality,
            thoroughfare: placemark.thoroughfare
        ) else {
            lastError = LocationResolveError.municipalityNotMatched.localizedDescription
            throw LocationResolveError.municipalityNotMatched
        }
        return matched
    }

    private func requestLocation() async throws -> CLLocation {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // 等待用户授权后再取位置
            try await waitForAuthorization()
        case .denied, .restricted:
            throw LocationResolveError.permissionDenied
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            self.manager.requestLocation()
        }
    }

    private func waitForAuthorization() async throws {
        for _ in 0..<40 {
            try await Task.sleep(nanoseconds: 100_000_000)
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                return
            case .denied, .restricted:
                throw LocationResolveError.permissionDenied
            default:
                continue
            }
        }
        throw LocationResolveError.permissionDenied
    }

    private func reverseGeocodeJapan(_ location: CLLocation) async throws -> CLPlacemark {
        let geocoder = CLGeocoder()
        let locale = Locale(identifier: "ja_JP")
        do {
            let marks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: locale)
            guard let mark = marks.first else { throw LocationResolveError.geocodeFailed }
            return mark
        } catch {
            throw LocationResolveError.geocodeFailed
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                locationContinuation?.resume(throwing: LocationResolveError.locationUnavailable)
                locationContinuation = nil
                return
            }
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: LocationResolveError.locationUnavailable)
            locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // waitForAuthorization 轮询即可
    }
}
