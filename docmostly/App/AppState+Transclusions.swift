import Foundation

extension AppState {
    func loadTransclusion(
        sourcePageId: String,
        transclusionId: String
    ) async throws -> DocmostTransclusionLookupItem {
        let reference = DocmostTransclusionReference(
            sourcePageId: sourcePageId,
            transclusionId: transclusionId
        )
        let results = try await loadTransclusions([reference])
        guard let result = results.first else {
            throw APIError.decodingFailed("The synced block lookup returned no result.")
        }
        return result
    }

    func loadTransclusions(
        _ references: [DocmostTransclusionReference]
    ) async throws -> [DocmostTransclusionLookupItem] {
        guard references.isEmpty == false else { return [] }
        guard let apiClient else {
            throw APIError.connectionFailed("Synced blocks require a network connection.")
        }

        var results: [DocmostTransclusionLookupItem] = []
        var startIndex = references.startIndex

        while startIndex < references.endIndex {
            let endIndex = min(
                startIndex + DocmostTransclusionLookupRequest.maximumReferences,
                references.endIndex
            )
            let batch = Array(references[startIndex..<endIndex])
            let request = DocmostTransclusionLookupRequest(references: batch)
            let response: DocmostTransclusionLookupResponse = try await apiClient.send(.transclusionLookup(request))
            try validateTransclusionResponse(response.items, expectedReferences: batch)
            results.append(contentsOf: response.items)
            startIndex = endIndex
        }

        isOffline = false
        return results
    }

    private func validateTransclusionResponse(
        _ items: [DocmostTransclusionLookupItem],
        expectedReferences: [DocmostTransclusionReference]
    ) throws {
        guard items.count == expectedReferences.count,
              zip(items, expectedReferences).allSatisfy({ pair in
                  pair.0.reference == pair.1
              })
        else {
            throw APIError.decodingFailed("The synced block lookup response did not match its request.")
        }
    }
}
