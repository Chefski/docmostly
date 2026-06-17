import Foundation

enum AppPhase: Equatable {
    case restoring
    case needsServer
    case unauthenticated
    case authenticated
}
