import Foundation
import SwiftData

/// Saves training inputs through the same atomic profile/session boundary used by remote application.
struct LocalTrainingProfileWriter {
    let context: ModelContext

    func update(userID: UUID, goal: TrainingGoal?, level: TrainingLevel?) throws -> User {
        let users = FetchDescriptor<UserEntity>(predicate: #Predicate { $0.id == userID })
        guard let entity = try context.fetch(users).first else { throw RepositoryError.userNotFound }
        let current = UserMapper.toDomain(entity)
        guard current.goal != goal || current.level != level else { return current }
        let updated = current.updatingTraining(goal: goal, level: level)
        try LocalProfileApplication(context: context).apply(updated, to: entity, enqueueLocalChange: true)
        return updated
    }
}
