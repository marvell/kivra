enum UpdateAvailability: Equatable {
    case available(version: String)
    case ready(version: String)

    var title: String {
        switch self {
        case .available(let version):
            "Update \(version) Available…"
        case .ready(let version):
            "Update \(version) Ready…"
        }
    }

    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }

    var version: String {
        switch self {
        case .available(let version), .ready(let version):
            version
        }
    }
}

struct UpdateAvailabilityState {
    private(set) var availability: UpdateAvailability?

    mutating func found(version: String) {
        guard availability?.version != version else {
            return
        }
        availability = .available(version: version)
    }

    mutating func prepared(version: String) {
        availability = .ready(version: version)
    }

    mutating func noUpdateFound() {
        // A prepared installer can outlive the check that discovers no newer release.
        if availability?.isReady != true {
            availability = nil
        }
    }

    mutating func clear() {
        availability = nil
    }
}
