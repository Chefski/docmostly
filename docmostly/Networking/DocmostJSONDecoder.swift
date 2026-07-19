import Foundation

nonisolated enum DocmostJSONDecoder {
    static func make() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.userInfo[.proseMirrorDecodingBudget] = ProseMirrorDecodingBudget()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = try? Date(value, strategy: .iso8601) {
                return date
            }

            let fractionalStrategy = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            if let date = try? Date(value, strategy: fractionalStrategy) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(value)"
            )
        }
        return decoder
    }

    static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        using decoder: JSONDecoder
    ) throws -> T {
        decoder.userInfo[.proseMirrorDecodingBudget] = ProseMirrorDecodingBudget()
        return try decoder.decode(type, from: data)
    }
}
