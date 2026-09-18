import Foundation

extension MockSeedData {
    static func makeUsers(_ context: MockSeedContext) -> [User] {
        [
            User(
                id: context.currentUserID,
                selectedProgramId: context.currentProgramID,
                createdAt: context.createdAt,
                updatedAt: context.createdAt
            ),
            User(
                id: context.secondUserID,
                selectedProgramId: context.secondUserProgramID,
                createdAt: context.createdAt.addingTimeInterval(600),
                updatedAt: context.createdAt.addingTimeInterval(600)
            )
        ]
    }
}
