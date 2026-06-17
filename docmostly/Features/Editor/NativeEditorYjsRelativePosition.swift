import Foundation

nonisolated struct NativeEditorYjsID: Codable, Equatable, Hashable, Sendable {
    let client: Int
    let clock: Int
}

nonisolated enum NativeEditorYjsRelativePositionType: Codable, Equatable, Hashable, Sendable {
    case name(String)
    case id(NativeEditorYjsID)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let name = try? container.decode(String.self) {
            self = .name(name)
        } else if let id = try? container.decode(NativeEditorYjsID.self) {
            self = .id(id)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported Yjs relative position type."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .name(let name):
            try container.encode(name)
        case .id(let id):
            try container.encode(id)
        case .null:
            try container.encodeNil()
        }
    }
}

nonisolated struct NativeEditorYjsRelativePosition: Codable, Equatable, Hashable, Sendable {
    static let docmostFragmentName = "default"

    let type: NativeEditorYjsRelativePositionType?
    let targetName: String?
    let item: NativeEditorYjsID?
    let assoc: Int?

    var targetsDocmostDefaultFragment: Bool {
        targetName == Self.docmostFragmentName
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case targetName = "tname"
        case item
        case assoc
    }
}

nonisolated struct NativeEditorYjsSelection: Codable, Equatable, Sendable {
    let anchor: NativeEditorYjsSelectionPosition
    let head: NativeEditorYjsSelectionPosition
}

nonisolated struct NativeEditorYjsSelectionPosition: Codable, Equatable, Sendable {
    let type: NativeEditorYjsID
    let targetName: String?
    let item: NativeEditorYjsID?
    let assoc: Int

    init(type: NativeEditorYjsID, targetName: String?, item: NativeEditorYjsID?, assoc: Int) {
        self.type = type
        self.targetName = targetName
        self.item = item
        self.assoc = assoc
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        type = try container.decode(NativeEditorYjsID.self, forKey: .type)
        targetName = try container.decodeIfPresent(String.self, forKey: .targetName)
        item = try container.decodeIfPresent(NativeEditorYjsID.self, forKey: .item)
        assoc = try container.decode(Int.self, forKey: .assoc)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(type, forKey: .type)
        if let targetName {
            try container.encode(targetName, forKey: .targetName)
        } else {
            try container.encodeNil(forKey: .targetName)
        }

        if let item {
            try container.encode(item, forKey: .item)
        } else {
            try container.encodeNil(forKey: .item)
        }
        try container.encode(assoc, forKey: .assoc)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case targetName = "tname"
        case item
        case assoc
    }
}
