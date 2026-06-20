import Foundation

nonisolated enum PagePositionKeyGenerator {
    private static let digits = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    private static let first = Character("0")
    private static let last = Character("z")
    private static let firstPositive = Character("a")
    private static let mostPositive = Character("z")
    private static let firstNegative = Character("Z")
    private static let mostNegative = Character("A")

    static func key(between lower: String?, and upper: String?) throws -> String {
        if let lower {
            try validateOrderKey(lower)
        }
        if let upper {
            try validateOrderKey(upper)
        }

        switch (lower, upper) {
        case (nil, nil):
            return String(firstPositive) + String(first)
        case (nil, .some(let upper)):
            return try decrementInteger(getIntegerPart(upper))
        case (.some(let lower), nil):
            return try incrementInteger(getIntegerPart(lower))
        case (.some(let lower), .some(let upper)):
            guard lower < upper else {
                throw PagePositionKeyGeneratorError.invalidBounds
            }
            return try midpoint(lower: lower, upper: upper)
        }
    }
}

nonisolated private extension PagePositionKeyGenerator {
    static func midpoint(lower: String, upper: String) throws -> String {
        var paddedLower = lower.padding(
            toLength: max(lower.count, upper.count),
            withPad: String(first),
            startingAt: 0
        )
        let paddedUpper = upper.padding(
            toLength: max(lower.count, upper.count),
            withPad: String(first),
            startingAt: 0
        )
        var distance = try subtractCharSetKeys(paddedUpper, paddedLower)
        if distance == String(digits[1]) {
            paddedLower.append(first)
            distance = encodeToCharSet(digits.count)
        }

        let half = try halfCharSetKey(distance)
        return try addCharSetKeys(paddedLower, half)
    }

    static func addCharSetKeys(_ lhs: String, _ rhs: String) throws -> String {
        let length = max(lhs.count, rhs.count)
        let paddedLHS = lhs.leftPadding(toLength: length, with: first)
        let paddedRHS = rhs.leftPadding(toLength: length, with: first)
        var result: [Character] = []
        var carry = 0

        for (left, right) in Array(zip(paddedLHS, paddedRHS)).reversed() {
            let sum = try index(of: left) + index(of: right) + carry
            carry = sum / digits.count
            result.insert(digits[sum % digits.count], at: 0)
        }

        if carry > 0 {
            result.insert(digits[carry], at: 0)
        }

        return String(result)
    }

    static func subtractCharSetKeys(
        _ lhs: String,
        _ rhs: String,
        stripLeadingZeros: Bool = true
    ) throws -> String {
        let length = max(lhs.count, rhs.count)
        let paddedLHS = lhs.leftPadding(toLength: length, with: first)
        let paddedRHS = rhs.leftPadding(toLength: length, with: first)
        var result: [Character] = []
        var borrow = 0

        for (left, right) in Array(zip(paddedLHS, paddedRHS)).reversed() {
            var leftIndex = try index(of: left)
            let rightIndex = try index(of: right) + borrow
            if leftIndex < rightIndex {
                borrow = 1
                leftIndex += digits.count
            } else {
                borrow = 0
            }
            result.insert(digits[leftIndex - rightIndex], at: 0)
        }

        guard borrow == 0 else {
            throw PagePositionKeyGeneratorError.invalidBounds
        }

        while stripLeadingZeros, result.count > 1, result.first == first {
            result.removeFirst()
        }
        return String(result)
    }

    static func halfCharSetKey(_ key: String) throws -> String {
        var quotient: [Character] = []
        var carry = 0

        for character in key {
            let value = carry * digits.count + (try index(of: character))
            quotient.append(digits[value / 2])
            carry = value % 2
        }

        while quotient.count > 1, quotient.first == first {
            quotient.removeFirst()
        }
        return String(quotient)
    }

    static func encodeToCharSet(_ value: Int) -> String {
        if value == 0 {
            return String(first)
        }

        var remaining = value
        var result = ""
        while remaining > 0 {
            result = String(digits[remaining % digits.count]) + result
            remaining /= digits.count
        }
        return result
    }

    static func incrementKey(_ key: String) throws -> String {
        try addCharSetKeys(key, String(digits[1]))
    }

    static func decrementKey(_ key: String) throws -> String {
        try subtractCharSetKeys(key, String(digits[1]), stripLeadingZeros: false)
    }

    static func getIntegerPart(_ orderKey: String) throws -> String {
        let head = try integerHead(orderKey)
        let length = try integerLength(head)
        guard length <= orderKey.count else {
            throw PagePositionKeyGeneratorError.invalidKey
        }
        return String(orderKey.prefix(length))
    }

    static func validateOrderKey(_ orderKey: String) throws {
        _ = try getIntegerPart(orderKey)
    }

    static func validateInteger(_ integer: String) throws {
        guard try integerLength(integer) == integer.count else {
            throw PagePositionKeyGeneratorError.invalidInteger
        }
    }

    static func incrementInteger(_ integer: String) throws -> String {
        try validateInteger(integer)
        let (head, tail) = try splitInteger(integer)

        if tail.contains(where: { $0 != last }) {
            return head + (try incrementKey(tail))
        }

        let nextHead = try incrementIntegerHead(head)
        return try startOnNewHead(nextHead, limit: .lower)
    }

    static func decrementInteger(_ integer: String) throws -> String {
        try validateInteger(integer)
        let (head, tail) = try splitInteger(integer)

        if tail.contains(where: { $0 != first }) {
            return head + (try decrementKey(tail))
        }

        let nextHead = try decrementIntegerHead(head)
        return try startOnNewHead(nextHead, limit: .upper)
    }

    static func splitInteger(_ integer: String) throws -> (String, String) {
        let head = try integerHead(integer)
        return (head, String(integer.dropFirst(head.count)))
    }

    static func integerHead(_ integer: String) throws -> String {
        guard let firstCharacter = integer.first else {
            throw PagePositionKeyGeneratorError.invalidInteger
        }

        var count = 0
        let characters = Array(integer)
        if firstCharacter == mostPositive {
            while count < characters.count, characters[count] == mostPositive {
                count += 1
            }
        }
        if firstCharacter == mostNegative {
            while count < characters.count, characters[count] == mostNegative {
                count += 1
            }
        }

        return String(characters.prefix(count + 1))
    }

    static func integerLength(_ head: String) throws -> Int {
        guard let firstCharacter = head.first else {
            throw PagePositionKeyGeneratorError.invalidInteger
        }
        let firstIndex = try index(of: firstCharacter)
        guard firstIndex <= (try index(of: mostPositive)), firstIndex >= (try index(of: mostNegative)) else {
            throw PagePositionKeyGeneratorError.invalidInteger
        }

        if firstCharacter == mostPositive {
            let firstLevel = try distanceBetween(firstCharacter, firstPositive) + 1
            return try firstLevel + integerLengthFromSecondLevel(
                String(head.dropFirst()),
                direction: .positive
            )
        }

        if firstCharacter == mostNegative {
            let firstLevel = try distanceBetween(firstCharacter, firstNegative) + 1
            return try firstLevel + integerLengthFromSecondLevel(
                String(head.dropFirst()),
                direction: .negative
            )
        }

        if firstIndex >= (try index(of: firstPositive)) {
            return try distanceBetween(firstCharacter, firstPositive) + 2
        }

        return try distanceBetween(firstCharacter, firstNegative) + 2
    }

    static func integerLengthFromSecondLevel(
        _ key: String,
        direction: PagePositionIntegerDirection
    ) throws -> Int {
        guard let firstCharacter = key.first else {
            throw PagePositionKeyGeneratorError.invalidInteger
        }
        let firstIndex = try index(of: firstCharacter)
        guard firstIndex <= (try index(of: mostPositive)), firstIndex >= (try index(of: mostNegative)) else {
            throw PagePositionKeyGeneratorError.invalidInteger
        }

        if firstCharacter == mostPositive, direction == .positive {
            let room = try distanceBetween(firstCharacter, mostNegative) + 1
            return try room + integerLengthFromSecondLevel(String(key.dropFirst()), direction: direction)
        }

        if firstCharacter == mostNegative, direction == .negative {
            let room = try distanceBetween(firstCharacter, mostPositive) + 1
            return try room + integerLengthFromSecondLevel(String(key.dropFirst()), direction: direction)
        }

        if direction == .positive {
            return try distanceBetween(firstCharacter, mostNegative) + 2
        }

        return try distanceBetween(firstCharacter, mostPositive) + 2
    }

    static func incrementIntegerHead(_ head: String) throws -> String {
        let inPositiveRange = try index(of: requireHead(head)) >= index(of: firstPositive)
        let nextHead = try incrementKey(head)
        let headIsLimitMax = head.last == mostPositive
        let nextHeadIsLimitMax = nextHead.last == mostPositive

        if inPositiveRange, nextHeadIsLimitMax {
            return nextHead + String(mostNegative)
        }
        if inPositiveRange == false, headIsLimitMax {
            return String(head.dropLast())
        }
        return nextHead
    }

    static func decrementIntegerHead(_ head: String) throws -> String {
        let inPositiveRange = try index(of: requireHead(head)) >= index(of: firstPositive)
        let headIsLimitMin = head.last == mostNegative

        if inPositiveRange, headIsLimitMin {
            return try decrementKey(String(head.dropLast()))
        }
        if inPositiveRange == false, headIsLimitMin {
            return head + String(mostPositive)
        }
        return try decrementKey(head)
    }

    static func startOnNewHead(_ head: String, limit: PagePositionIntegerLimit) throws -> String {
        let length = try integerLength(head)
        let fillCharacter = limit == .upper ? last : first
        return head + String(repeating: String(fillCharacter), count: length - head.count)
    }

    static func distanceBetween(_ lhs: Character, _ rhs: Character) throws -> Int {
        abs(try index(of: lhs) - index(of: rhs))
    }

    static func index(of character: Character) throws -> Int {
        guard let index = digits.firstIndex(of: character) else {
            throw PagePositionKeyGeneratorError.invalidCharacter
        }
        return index
    }

    static func requireHead(_ head: String) throws -> Character {
        guard let character = head.first else {
            throw PagePositionKeyGeneratorError.invalidInteger
        }
        return character
    }
}

nonisolated private enum PagePositionIntegerDirection {
    case positive
    case negative
}

nonisolated private enum PagePositionIntegerLimit {
    case lower
    case upper
}

nonisolated private enum PagePositionKeyGeneratorError: Error {
    case invalidBounds
    case invalidCharacter
    case invalidInteger
    case invalidKey
}

nonisolated private extension String {
    func leftPadding(toLength length: Int, with character: Character) -> String {
        guard count < length else { return self }
        return String(repeating: String(character), count: length - count) + self
    }
}
