import Foundation

nonisolated enum NativeEditorHocuspocusProtocolError: Error, Equatable, Sendable {
    case invalidUTF8
    case unexpectedEnd
    case invalidMessageType(Int)
}

nonisolated enum NativeEditorHocuspocusMessageType: Int, Sendable {
    case sync = 0
    case awareness = 1
    case auth = 2
    case queryAwareness = 3
    case stateless = 5
    case close = 7
    case syncStatus = 8
}

nonisolated enum NativeEditorHocuspocusAuthMessageType: Int, Sendable {
    case token = 0
    case permissionDenied = 1
    case authenticated = 2
}

nonisolated enum NativeEditorYjsSyncMessageType: Int, Sendable {
    case stepOne = 0
    case stepTwo = 1
    case update = 2
}

nonisolated enum NativeEditorYjsSyncMessage: Equatable, Sendable {
    case stepOne(Data)
    case stepTwo(Data)
    case update(Data)

    static func parse(decoder: inout NativeEditorLib0Decoder) throws -> NativeEditorYjsSyncMessage {
        let typeValue = try decoder.readVarUint()
        let payload = try decoder.readVarUint8Array()

        guard let type = NativeEditorYjsSyncMessageType(rawValue: typeValue) else {
            throw NativeEditorHocuspocusProtocolError.invalidMessageType(typeValue)
        }

        switch type {
        case .stepOne:
            return .stepOne(payload)
        case .stepTwo:
            return .stepTwo(payload)
        case .update:
            return .update(payload)
        }
    }

    func encode(to encoder: inout NativeEditorLib0Encoder) {
        switch self {
        case .stepOne(let stateVector):
            encoder.writeVarUint(NativeEditorYjsSyncMessageType.stepOne.rawValue)
            encoder.writeVarUint8Array(stateVector)
        case .stepTwo(let update):
            encoder.writeVarUint(NativeEditorYjsSyncMessageType.stepTwo.rawValue)
            encoder.writeVarUint8Array(update)
        case .update(let update):
            encoder.writeVarUint(NativeEditorYjsSyncMessageType.update.rawValue)
            encoder.writeVarUint8Array(update)
        }
    }
}

nonisolated enum NativeEditorCollaborationScope: String, Equatable, Sendable {
    case readWrite = "read-write"
    case readonly
    case unknown

    init(rawScope: String) {
        self = Self(rawValue: rawScope) ?? .unknown
    }
}

nonisolated struct NativeEditorHocuspocusFrame: Equatable, Sendable {
    let documentName: String
    let message: NativeEditorHocuspocusMessage

    static func parse(_ data: Data) throws -> NativeEditorHocuspocusFrame {
        var decoder = NativeEditorLib0Decoder(data: data)
        let documentName = try decoder.readVarString()
        let typeValue = try decoder.readVarUint()

        guard let type = NativeEditorHocuspocusMessageType(rawValue: typeValue) else {
            throw NativeEditorHocuspocusProtocolError.invalidMessageType(typeValue)
        }

        let message: NativeEditorHocuspocusMessage
        switch type {
        case .sync:
            message = .sync(try NativeEditorYjsSyncMessage.parse(decoder: &decoder))
        case .awareness:
            let updateData = try decoder.readVarUint8Array()
            message = .awareness(try NativeEditorAwarenessState.decodeUpdate(updateData))
        case .auth:
            message = try parseAuthMessage(decoder: &decoder)
        case .queryAwareness:
            message = .queryAwareness
        case .stateless:
            let payload = try decoder.readVarString()
            let event = try DocmostJSONDecoder.make().decode(
                NativeEditorCollaborationStatelessEvent.self,
                from: Data(payload.utf8)
            )
            message = .stateless(event)
        case .close:
            message = .close(reason: try decoder.readVarString())
        case .syncStatus:
            message = .syncStatus(try decoder.readVarUint() == 1)
        }

        return NativeEditorHocuspocusFrame(documentName: documentName, message: message)
    }

    static func authentication(documentName: String, token: String) throws -> Data {
        var encoder = NativeEditorLib0Encoder()
        encoder.writeVarString(documentName)
        encoder.writeVarUint(NativeEditorHocuspocusMessageType.auth.rawValue)
        encoder.writeVarUint(NativeEditorHocuspocusAuthMessageType.token.rawValue)
        encoder.writeVarString(token)
        return encoder.data
    }

    static func sync(documentName: String, message: NativeEditorYjsSyncMessage) -> Data {
        var encoder = NativeEditorLib0Encoder()
        encoder.writeVarString(documentName)
        encoder.writeVarUint(NativeEditorHocuspocusMessageType.sync.rawValue)
        message.encode(to: &encoder)
        return encoder.data
    }

    static func queryAwareness(documentName: String) -> Data {
        var encoder = NativeEditorLib0Encoder()
        encoder.writeVarString(documentName)
        encoder.writeVarUint(NativeEditorHocuspocusMessageType.queryAwareness.rawValue)
        return encoder.data
    }

    static func awareness(documentName: String, update: Data) -> Data {
        var encoder = NativeEditorLib0Encoder()
        encoder.writeVarString(documentName)
        encoder.writeVarUint(NativeEditorHocuspocusMessageType.awareness.rawValue)
        encoder.writeVarUint8Array(update)
        return encoder.data
    }

    static func awarenessUpdate(states: [NativeEditorAwarenessState]) throws -> Data {
        var encoder = NativeEditorLib0Encoder()
        encoder.writeVarUint(states.count)

        for state in states {
            encoder.writeVarUint(state.clientID)
            encoder.writeVarUint(state.clock)

            if let payload = state.payload {
                let data = try JSONEncoder().encode(payload)
                guard let json = String(data: data, encoding: .utf8) else {
                    throw NativeEditorHocuspocusProtocolError.invalidUTF8
                }
                encoder.writeVarString(json)
            } else {
                encoder.writeVarString("null")
            }
        }

        return encoder.data
    }

    private static func parseAuthMessage(
        decoder: inout NativeEditorLib0Decoder
    ) throws -> NativeEditorHocuspocusMessage {
        let typeValue = try decoder.readVarUint()

        guard let type = NativeEditorHocuspocusAuthMessageType(rawValue: typeValue) else {
            throw NativeEditorHocuspocusProtocolError.invalidMessageType(typeValue)
        }

        switch type {
        case .token:
            return .authTokenRequested
        case .permissionDenied:
            return .authenticationFailed(reason: try decoder.readVarString())
        case .authenticated:
            return .authenticated(scope: NativeEditorCollaborationScope(
                rawScope: try decoder.readVarString()
            ))
        }
    }
}

nonisolated enum NativeEditorHocuspocusMessage: Equatable, Sendable {
    case sync(NativeEditorYjsSyncMessage)
    case awareness([NativeEditorAwarenessState])
    case authTokenRequested
    case authenticated(scope: NativeEditorCollaborationScope)
    case authenticationFailed(reason: String)
    case queryAwareness
    case stateless(NativeEditorCollaborationStatelessEvent)
    case close(reason: String)
    case syncStatus(Bool)
}

nonisolated struct NativeEditorCollaborationStatelessEvent: Decodable, Equatable, Sendable {
    let type: String
    let updatedAt: Date?
    let lastUpdatedById: String?
    let lastUpdatedBy: DocmostPagePerson?
}

nonisolated struct NativeEditorAwarenessState: Equatable, Sendable {
    let clientID: Int
    let clock: Int
    let payload: NativeEditorAwarenessPayload?

    var user: NativeEditorAwarenessUser? {
        payload?.user
    }

    var cursor: NativeEditorAwarenessCursor? {
        payload?.cursor
    }

    static func decodeUpdate(_ data: Data) throws -> [NativeEditorAwarenessState] {
        var decoder = NativeEditorLib0Decoder(data: data)
        let count = try decoder.readVarUint()
        var states: [NativeEditorAwarenessState] = []
        states.reserveCapacity(count)

        for _ in 0..<count {
            let clientID = try decoder.readVarUint()
            let clock = try decoder.readVarUint()
            let stateJSON = try decoder.readVarString()
            let payload: NativeEditorAwarenessPayload?

            if stateJSON == "null" {
                payload = nil
            } else {
                payload = try JSONDecoder().decode(
                    NativeEditorAwarenessPayload.self,
                    from: Data(stateJSON.utf8)
                )
            }

            states.append(NativeEditorAwarenessState(clientID: clientID, clock: clock, payload: payload))
        }

        return states
    }
}

nonisolated struct NativeEditorAwarenessStateStore: Sendable {
    private var statesByClientID: [Int: NativeEditorAwarenessState] = [:]

    mutating func apply(_ updates: [NativeEditorAwarenessState]) -> [NativeEditorAwarenessState] {
        for state in updates {
            if state.payload == nil {
                statesByClientID.removeValue(forKey: state.clientID)
            } else {
                statesByClientID[state.clientID] = state
            }
        }

        return statesByClientID.values.sorted { $0.clientID < $1.clientID }
    }

    mutating func reset() {
        statesByClientID.removeAll()
    }
}

nonisolated struct NativeEditorAwarenessPayload: Codable, Equatable, Sendable {
    let user: NativeEditorAwarenessUser?
    let cursor: NativeEditorAwarenessCursor?
}

nonisolated struct NativeEditorAwarenessUser: Codable, Equatable, Sendable {
    let id: String?
    let name: String
    let color: String?
}

nonisolated struct NativeEditorAwarenessCursor: Codable, Equatable, Sendable {
    let anchor: ProseMirrorJSONValue?
    let head: ProseMirrorJSONValue?
}

nonisolated struct NativeEditorLib0Encoder: Sendable {
    private(set) var data = Data()

    mutating func writeVarUint(_ value: Int) {
        var value = value

        while value > 0x7F {
            data.append(UInt8(0x80 | (value & 0x7F)))
            value /= 128
        }

        data.append(UInt8(value & 0x7F))
    }

    mutating func writeVarString(_ value: String) {
        let bytes = Data(value.utf8)
        writeVarUint(bytes.count)
        data.append(bytes)
    }

    mutating func writeVarUint8Array(_ value: Data) {
        writeVarUint(value.count)
        data.append(value)
    }
}

nonisolated struct NativeEditorLib0Decoder: Sendable {
    private let bytes: [UInt8]
    private var offset = 0

    init(data: Data) {
        bytes = Array(data)
    }

    mutating func readVarUint() throws -> Int {
        var value = 0
        var multiplier = 1

        while offset < bytes.count {
            let byte = Int(bytes[offset])
            offset += 1
            value += (byte & 0x7F) * multiplier

            if byte < 0x80 {
                return value
            }

            multiplier *= 128
        }

        throw NativeEditorHocuspocusProtocolError.unexpectedEnd
    }

    mutating func readVarString() throws -> String {
        let data = try readVarUint8Array()
        guard let value = String(data: data, encoding: .utf8) else {
            throw NativeEditorHocuspocusProtocolError.invalidUTF8
        }
        return value
    }

    mutating func readVarUint8Array() throws -> Data {
        let length = try readVarUint()
        guard offset + length <= bytes.count else {
            throw NativeEditorHocuspocusProtocolError.unexpectedEnd
        }

        let range = offset..<(offset + length)
        offset += length
        return Data(bytes[range])
    }
}
