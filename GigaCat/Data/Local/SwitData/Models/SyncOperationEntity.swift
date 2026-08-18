import Foundation
import SwiftData

@Model
final class SyncOperationEntity {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var aggregateTypeRawValue: String
    var aggregateId: UUID
    var mutationRawValue: String
    var payload: Data
    var revision: Int
    var statusRawValue: String
    var createdAt: Date
    var attemptCount: Int
    var nextAttemptAt: Date?
    var lastErrorMessage: String?

    init(
        id: UUID = UUID(),
        userId: UUID,
        aggregateTypeRawValue: String,
        aggregateId: UUID,
        mutationRawValue: String,
        payload: Data,
        revision: Int,
        statusRawValue: String = SyncOperationStatus.pending.rawValue,
        createdAt: Date = Date(),
        attemptCount: Int = 0,
        nextAttemptAt: Date? = nil,
        lastErrorMessage: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.aggregateTypeRawValue = aggregateTypeRawValue
        self.aggregateId = aggregateId
        self.mutationRawValue = mutationRawValue
        self.payload = payload
        self.revision = revision
        self.statusRawValue = statusRawValue
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.nextAttemptAt = nextAttemptAt
        self.lastErrorMessage = lastErrorMessage
    }
}
