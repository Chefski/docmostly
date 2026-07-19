import Foundation

protocol DocumentUpdateIndexer: Sendable {
    func documentUpdateCommitted(_ update: CommittedDocumentUpdate) async
}

actor NoopDocumentUpdateIndexer: DocumentUpdateIndexer {
    func documentUpdateCommitted(_ update: CommittedDocumentUpdate) { }
}
