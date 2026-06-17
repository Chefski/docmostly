import Foundation

enum NativeEditorRealtimeStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case conflict
    case failed(String)
    case unsupported(String)
}

struct NativeEditorRemoteUpdate: Equatable, Sendable {
    var updatedAt: Date?
    var title: String
    var lastUpdatedBy: DocmostPagePerson?
}

nonisolated enum NativeEditorCollaborationEvent: Equatable, Sendable {
    case authenticated(NativeEditorCollaborationScope)
    case awareness(states: [NativeEditorAwarenessState], localClientID: Int)
    case stateless(NativeEditorCollaborationStatelessEvent)
    case syncStatus(Bool)
}

nonisolated struct NativeEditorCollaborationSessionContext: Sendable {
    let url: URL
    let token: String
    let documentName: String
    let user: DocmostUser?
    let syncDriver: NativeEditorCollaborationSyncDriver?
    let localAwarenessCursor: (@Sendable () async -> NativeEditorAwarenessCursor?)?
    let localAwarenessUpdates: AsyncStream<Void>?
}

enum NativeEditorCollaboratorSource: Equatable, Sendable {
    case presence
    case recentEditor
}

struct NativeEditorCollaborator: Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var colorName: String
    var source: NativeEditorCollaboratorSource

    init(
        id: String,
        name: String,
        colorName: String,
        source: NativeEditorCollaboratorSource = .presence
    ) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.source = source
    }

    init(person: DocmostPagePerson) {
        id = person.id
        name = person.name
        colorName = Self.colorName(for: person.id)
        source = .recentEditor
    }

    init(awarenessState: NativeEditorAwarenessState) {
        let user = awarenessState.payload?.user
        let identifier = user?.id ?? "client-\(awarenessState.clientID)"
        id = identifier
        name = user?.name ?? "Someone"
        colorName = user?.color ?? Self.colorName(for: identifier)
        source = .presence
    }

    private static func colorName(for identifier: String) -> String {
        let palette = ["gray", "blue", "green", "orange", "purple"]
        let index = abs(identifier.hashValue) % palette.count
        return palette[index]
    }
}

enum NativeEditorPresenceStatusText {
    static func editingTitle(for collaborators: [NativeEditorCollaborator]) -> String? {
        let names = collaborators
            .filter { $0.source == .presence }
            .map(\.name)

        guard let firstName = names.first else { return nil }

        switch names.count {
        case 1:
            return "\(firstName) is editing"
        case 2:
            return "\(firstName) and \(names[1]) are editing"
        default:
            return "\(firstName) and \(names.count - 1) others are editing"
        }
    }
}

nonisolated enum NativeEditorPresenceColor {
    static func color(for identifier: String) -> String {
        let palette = ["#6B7280", "#2563EB", "#059669", "#EA580C", "#7C3AED"]
        let index = stableHash(for: identifier) % palette.count
        return palette[index]
    }

    private static func stableHash(for value: String) -> Int {
        value.unicodeScalars.reduce(0) { result, scalar in
            ((result &* 31) &+ Int(scalar.value)) & Int.max
        }
    }
}

nonisolated enum NativeEditorAwarenessTiming {
    static let staleStateInterval: TimeInterval = 30
    static let staleStateCheckDelay: Duration = .seconds(3)
    static let localStateRefreshDelay: Duration = .seconds(15)
}

nonisolated struct NativeEditorAwarenessStateStore: Sendable {
    private var statesByClientID: [Int: NativeEditorAwarenessState] = [:]
    private var latestClockByClientID: [Int: Int] = [:]
    private var lastSeenByClientID: [Int: Date] = [:]

    mutating func apply(
        _ updates: [NativeEditorAwarenessState],
        receivedAt: Date = .now
    ) -> [NativeEditorAwarenessState] {
        for state in updates {
            if let latestClock = latestClockByClientID[state.clientID], state.clock <= latestClock {
                continue
            }

            latestClockByClientID[state.clientID] = state.clock

            if state.payload == nil {
                statesByClientID.removeValue(forKey: state.clientID)
                lastSeenByClientID.removeValue(forKey: state.clientID)
            } else {
                statesByClientID[state.clientID] = state
                lastSeenByClientID[state.clientID] = receivedAt
            }
        }

        return visibleStates
    }

    mutating func pruneStaleStates(
        now: Date = .now,
        staleStateInterval: TimeInterval = NativeEditorAwarenessTiming.staleStateInterval
    ) -> [NativeEditorAwarenessState]? {
        let staleClientIDs = statesByClientID.keys.filter { clientID in
            guard let lastSeen = lastSeenByClientID[clientID] else { return true }
            return now.timeIntervalSince(lastSeen) >= staleStateInterval
        }

        guard staleClientIDs.isEmpty == false else { return nil }

        for clientID in staleClientIDs {
            statesByClientID.removeValue(forKey: clientID)
            lastSeenByClientID.removeValue(forKey: clientID)
        }

        return visibleStates
    }

    mutating func reset() {
        statesByClientID.removeAll()
        latestClockByClientID.removeAll()
        lastSeenByClientID.removeAll()
    }

    private var visibleStates: [NativeEditorAwarenessState] {
        statesByClientID.values.sorted { $0.clientID < $1.clientID }
    }
}

enum NativeEditorCollaborationEndpoint {
    static func webSocketURL(serverBaseURL: URL) throws -> URL {
        guard var components = URLComponents(url: serverBaseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.scheme = webSocketScheme(for: components.scheme)
        components.path = "/collab"
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private static func webSocketScheme(for scheme: String?) -> String {
        scheme == "https" ? "wss" : "ws"
    }
}
