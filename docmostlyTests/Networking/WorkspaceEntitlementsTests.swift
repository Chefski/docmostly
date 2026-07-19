import Foundation
import Testing
@testable import docmostly

struct WorkspaceEntitlementsTests {
    @Test func decodesKnownAndFutureFeatureIdentifiers() throws {
        let data = Data(#"{"cloud":false,"tier":"business","features":["ai","templates","future:feature"]}"#.utf8)

        let entitlements = try JSONDecoder().decode(DocmostWorkspaceEntitlements.self, from: data)

        #expect(entitlements.cloud == false)
        #expect(entitlements.tier == "business")
        #expect(entitlements.contains(.artificialIntelligence))
        #expect(entitlements.contains(.templates))
        #expect(entitlements.contains(.mcp) == false)
        #expect(entitlements.features.contains("future:feature"))
    }
}
