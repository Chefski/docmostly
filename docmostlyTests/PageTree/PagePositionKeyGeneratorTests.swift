import Testing
@testable import docmostly

struct PagePositionKeyGeneratorTests {
    @Test func createsInitialAndAdjacentKeysCompatibleWithDocmostWeb() throws {
        #expect(try PagePositionKeyGenerator.key(between: nil, and: nil) == "a0")
        #expect(try PagePositionKeyGenerator.key(between: "a0", and: nil) == "a1")
        #expect(try PagePositionKeyGenerator.key(between: nil, and: "a0") == "Zz")
    }

    @Test func createsKeysBetweenExistingNeighbors() throws {
        #expect(try PagePositionKeyGenerator.key(between: "a0", and: "a1") == "a0V")
        #expect(try PagePositionKeyGenerator.key(between: "a0", and: "a0V") == "a0F")
        #expect(try PagePositionKeyGenerator.key(between: "a0V", and: "a1") == "a0k")
    }
}
