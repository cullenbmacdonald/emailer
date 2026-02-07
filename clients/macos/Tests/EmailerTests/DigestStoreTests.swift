import Foundation
import Testing
import EmailClientKit
@testable import EmailerLib

@Suite("DigestStore")
@MainActor
struct DigestStoreTests {
    private func makeDigest(isRead: Bool = false) -> DailyDigest {
        DailyDigest(
            id: "d1",
            digestType: .morning,
            generatedAt: Date(),
            isRead: isRead,
            sections: []
        )
    }

    @Test("Initial state has no digest")
    func initialState() {
        let store = DigestStore()
        #expect(store.latestDigest == nil)
        #expect(!store.hasNewDigest)
    }

    @Test("hasNewDigest is true when unread digest exists")
    func hasNewDigestUnread() {
        let store = DigestStore()
        store.setLatestDigest(makeDigest(isRead: false))
        #expect(store.hasNewDigest)
    }

    @Test("hasNewDigest is false when digest is read")
    func hasNewDigestRead() {
        let store = DigestStore()
        store.setLatestDigest(makeDigest(isRead: true))
        #expect(!store.hasNewDigest)
    }

    @Test("digestAvailable event creates placeholder digest")
    func digestAvailable() {
        let store = DigestStore()
        let event = WebSocketEvent(
            type: .digestAvailable,
            payload: .digestAvailable(DigestAvailablePayload(
                digestId: "d1",
                digestType: .morning,
                generatedAt: Date()
            ))
        )
        store.handleEvent(event)
        #expect(store.latestDigest != nil)
        #expect(store.latestDigest?.id == "d1")
        #expect(store.hasNewDigest)
    }

    @Test("markAsRead marks digest as read")
    func markAsRead() {
        let store = DigestStore()
        store.setLatestDigest(makeDigest(isRead: false))
        #expect(store.hasNewDigest)

        store.markAsRead()
        #expect(!store.hasNewDigest)
        #expect(store.latestDigest?.isRead == true)
    }

    @Test("Non-digest events are ignored")
    func ignoresOtherEvents() {
        let store = DigestStore()
        let event = WebSocketEvent(type: .pong, payload: .pong)
        store.handleEvent(event)
        #expect(store.latestDigest == nil)
    }
}
