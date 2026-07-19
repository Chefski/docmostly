import Foundation

nonisolated struct CommentEmoji: Identifiable, Hashable, Sendable {
    let name: String
    let symbol: String

    var id: String { name }

    static func suggestions(matching query: String) -> [CommentEmoji] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return Array(all.prefix(8)) }
        return all.filter { emoji in
            emoji.name.localizedStandardContains(trimmedQuery)
        }
    }

    static let all: [CommentEmoji] = [
        CommentEmoji(name: "thumbs up", symbol: "👍"),
        CommentEmoji(name: "heart", symbol: "❤️"),
        CommentEmoji(name: "smile", symbol: "😊"),
        CommentEmoji(name: "laugh", symbol: "😂"),
        CommentEmoji(name: "party", symbol: "🎉"),
        CommentEmoji(name: "rocket", symbol: "🚀"),
        CommentEmoji(name: "eyes", symbol: "👀"),
        CommentEmoji(name: "thinking", symbol: "🤔"),
        CommentEmoji(name: "check", symbol: "✅"),
        CommentEmoji(name: "warning", symbol: "⚠️"),
        CommentEmoji(name: "fire", symbol: "🔥"),
        CommentEmoji(name: "sparkles", symbol: "✨"),
        CommentEmoji(name: "wave", symbol: "👋"),
        CommentEmoji(name: "pray", symbol: "🙏"),
        CommentEmoji(name: "clap", symbol: "👏"),
        CommentEmoji(name: "hundred", symbol: "💯"),
        CommentEmoji(name: "bulb", symbol: "💡"),
        CommentEmoji(name: "pin", symbol: "📌"),
        CommentEmoji(name: "link", symbol: "🔗"),
        CommentEmoji(name: "memo", symbol: "📝"),
        CommentEmoji(name: "calendar", symbol: "📅"),
        CommentEmoji(name: "bug", symbol: "🐛"),
        CommentEmoji(name: "wrench", symbol: "🔧"),
        CommentEmoji(name: "lock", symbol: "🔒")
    ]
}
