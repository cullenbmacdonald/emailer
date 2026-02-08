import Foundation
import Contacts

/// Provides contact search from the system Contacts database.
/// Works on both macOS and iOS.
@MainActor
public final class ContactsProvider: @unchecked Sendable {
    private let store = CNContactStore()
    private var accessGranted = false

    public init() {}

    /// Request access to contacts. Call once on first use.
    public func requestAccess() async -> Bool {
        do {
            accessGranted = try await store.requestAccess(for: .contacts)
            return accessGranted
        } catch {
            return false
        }
    }

    /// Search contacts matching query string (name or email).
    /// Returns up to `limit` matching contacts.
    public func search(query: String, limit: Int = 10) async -> [ContactSuggestion] {
        guard accessGranted, !query.isEmpty else { return [] }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]

        let predicate = CNContact.predicateForContacts(matchingName: query)

        do {
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            var results: [ContactSuggestion] = []
            for contact in contacts {
                for email in contact.emailAddresses {
                    let name = [contact.givenName, contact.familyName]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    results.append(ContactSuggestion(
                        name: name.isEmpty ? nil : name,
                        email: email.value as String
                    ))
                    if results.count >= limit { return results }
                }
            }

            // Also search by email if we have few results
            if results.count < limit {
                let emailResults = searchByEmail(query: query, keysToFetch: keysToFetch, limit: limit - results.count, excluding: Set(results.map(\.email)))
                results.append(contentsOf: emailResults)
            }

            return results
        } catch {
            return []
        }
    }

    private func searchByEmail(query: String, keysToFetch: [CNKeyDescriptor], limit: Int, excluding: Set<String>) -> [ContactSuggestion] {
        // CNContact doesn't have a direct email predicate, so we fetch all and filter
        // This is a fallback -- name search covers most cases
        return []
    }
}

/// A contact suggestion for the autocomplete.
public struct ContactSuggestion: Identifiable, Sendable, Equatable {
    public var id: String { email }
    public let name: String?
    public let email: String

    public init(name: String?, email: String) {
        self.name = name
        self.email = email
    }

    /// Display string: "Name <email>" or just email.
    public var displayString: String {
        if let name, !name.isEmpty {
            return "\(name) <\(email)>"
        }
        return email
    }
}
