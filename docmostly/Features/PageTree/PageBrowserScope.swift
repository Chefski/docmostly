import Foundation

enum PageBrowserScope: String, CaseIterable, Identifiable {
    case recentlyUpdated
    case favorites
    case createdByMe

    var id: Self { self }

    var title: String {
        switch self {
        case .recentlyUpdated:
            "Recently Updated"
        case .favorites:
            "Favorites"
        case .createdByMe:
            "Created by Me"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyUpdated:
            "clock"
        case .favorites:
            "star"
        case .createdByMe:
            "person"
        }
    }

    var loadingTitle: String {
        switch self {
        case .recentlyUpdated:
            "Loading recent pages"
        case .favorites:
            "Loading favorites"
        case .createdByMe:
            "Loading your pages"
        }
    }

    var emptyTitle: String {
        switch self {
        case .recentlyUpdated:
            "No recently updated pages"
        case .favorites:
            "No favorite pages"
        case .createdByMe:
            "No pages created by you"
        }
    }

    var emptySystemImage: String {
        switch self {
        case .recentlyUpdated:
            "clock"
        case .favorites:
            "star"
        case .createdByMe:
            "person.crop.circle"
        }
    }
}
