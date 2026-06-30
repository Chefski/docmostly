import Foundation

extension NativeEditorMention {
    init(pageSearchResult result: DocmostSearchResult) {
        self.init(
            identifier: NativeEditorMentionNodeID.make(),
            label: result.title.isEmpty ? "Untitled" : result.title,
            entityType: "page",
            entityID: result.id,
            slugID: result.slugId,
            creatorID: result.creatorId
        )
    }

    init(pageSuggestion page: DocmostMentionPageSuggestion, creatorID: String?) {
        self.init(
            identifier: NativeEditorMentionNodeID.make(),
            label: page.title.isEmpty ? "Untitled" : page.title,
            entityType: "page",
            entityID: page.id,
            slugID: page.slugId,
            creatorID: creatorID
        )
    }

    init(
        createdPage page: DocmostPage,
        creatorID: String?,
        identifier: String = NativeEditorMentionNodeID.make()
    ) {
        self.init(
            identifier: identifier,
            label: page.title.isEmpty ? "Untitled" : page.title,
            entityType: "page",
            entityID: page.id,
            slugID: page.slugId,
            creatorID: creatorID
        )
    }

    init(userSuggestion user: DocmostMentionUserSuggestion, creatorID: String?) {
        self.init(
            identifier: NativeEditorMentionNodeID.make(),
            label: user.name,
            entityType: "user",
            entityID: user.id,
            creatorID: creatorID
        )
    }
}

private enum NativeEditorMentionNodeID {
    private static let hexDigits = Array("0123456789abcdef")

    static func make(now: Date = Date()) -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let timestamp = timestampMilliseconds(from: now) & 0x0000_FFFF_FFFF_FFFF

        bytes[0] = UInt8((timestamp >> 40) & 0xFF)
        bytes[1] = UInt8((timestamp >> 32) & 0xFF)
        bytes[2] = UInt8((timestamp >> 24) & 0xFF)
        bytes[3] = UInt8((timestamp >> 16) & 0xFF)
        bytes[4] = UInt8((timestamp >> 8) & 0xFF)
        bytes[5] = UInt8(timestamp & 0xFF)

        for index in 6..<bytes.count {
            bytes[index] = UInt8.random(in: UInt8.min...UInt8.max)
        }

        bytes[6] = (bytes[6] & 0x0F) | 0x70
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return uuidString(from: bytes)
    }

    private static func timestampMilliseconds(from date: Date) -> UInt64 {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite, milliseconds > 0 else { return 0 }
        return UInt64(milliseconds.rounded(.down))
    }

    private static func uuidString(from bytes: [UInt8]) -> String {
        var result = ""
        result.reserveCapacity(36)

        for (index, byte) in bytes.enumerated() {
            if index == 4 || index == 6 || index == 8 || index == 10 {
                result.append("-")
            }
            appendHex(byte, to: &result)
        }

        return result
    }

    private static func appendHex(_ byte: UInt8, to result: inout String) {
        result.append(hexDigits[Int(byte >> 4)])
        result.append(hexDigits[Int(byte & 0x0F)])
    }
}
