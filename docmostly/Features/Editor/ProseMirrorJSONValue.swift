import Foundation

enum ProseMirrorJSONValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: ProseMirrorJSONValue])
    case array([ProseMirrorJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: ProseMirrorJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([ProseMirrorJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported ProseMirror JSON value."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            value
        case .double(let value):
            Int(value)
        case .string(let value):
            Int(value)
        default:
            nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    var displayString: String? {
        switch self {
        case .string(let value):
            value
        case .int(let value):
            value.formatted()
        case .double(let value):
            value.formatted(.number)
        case .bool(let value):
            value ? "true" : "false"
        case .object, .array, .null:
            nil
        }
    }
}
