import Foundation

// @covers AC-HOME-04, AC-SYNC-01

enum ServiceProviderFieldMerge {
    static func apply(_ row: ServiceProviderDTO, to cached: CachedServiceProvider) {
        cached.companyName = row.companyName
        cached.serviceType = row.serviceType
        cached.accountNumber = row.accountNumber
        cached.phone = row.phone
        cached.website = row.website
        cached.hours = row.hours
        cached.notes = row.notes
        cached.providerVisibility = row.visibility
        cached.serverUpdatedAt = row.updatedAt
        cached.sync = .synced
    }
}
