import Foundation

// @covers FR-HOME-02, AC-HOME-04

struct ServiceProviderDTO: Codable, Sendable {
    let id: UUID
    let homeId: UUID
    let companyName: String
    let serviceType: String
    let accountNumber: String?
    let phone: String?
    let website: String?
    let hours: String?
    let notes: String?
    let visibility: Visibility
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, phone, website, hours, notes, visibility
        case homeId = "home_id"
        case companyName = "company_name"
        case serviceType = "service_type"
        case accountNumber = "account_number"
        case updatedAt = "updated_at"
    }
}

struct ServiceProviderSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let homeId: UUID
    let companyName: String
    let serviceType: String
    let accountNumber: String?
    let phone: String?
    let website: String?
    let hours: String?
    let notes: String?
    let visibility: Visibility

    /// Digits-only phone for a `tel:` URL; nil when the number has no digits.
    var telURL: URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard digits.contains(where: \.isNumber) else { return nil }
        return URL(string: "tel:\(digits)")
    }

    var websiteURL: URL? {
        guard var website, !website.isEmpty else { return nil }
        if !website.lowercased().hasPrefix("http") {
            website = "https://\(website)"
        }
        return URL(string: website)
    }
}

/// Draft fields for the create/edit form (AC-HOME-04).
struct ServiceProviderDraft: Sendable, Equatable {
    var companyName = ""
    var serviceType = ""
    var accountNumber = ""
    var phone = ""
    var website = ""
    var hours = ""
    var notes = ""
    var visibility: Visibility = .manager

    init() { /* default empty draft */ }

    init(from summary: ServiceProviderSummary) {
        companyName = summary.companyName
        serviceType = summary.serviceType
        accountNumber = summary.accountNumber ?? ""
        phone = summary.phone ?? ""
        website = summary.website ?? ""
        hours = summary.hours ?? ""
        notes = summary.notes ?? ""
        visibility = summary.visibility
    }

    var isValid: Bool {
        !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !serviceType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
