import Testing
@testable import GigaCat

@MainActor
extension WorkoutExerciseViewModelTests {
    @Test
    func addSetNotifiesParentAboutChangedSetCount() throws {
        let fixture = try Fixture()
        var receivedEvent: WorkoutExerciseEvent?
        let viewModel = fixture.makeViewModel(
            initialDayExerciseID: fixture.first.dayExercise.id,
            onEvent: { receivedEvent = $0 }
        )

        viewModel.addSet()

        #expect(
            receivedEvent == .setCountChanged(
                dayExerciseID: fixture.first.dayExercise.id,
                count: 4
            )
        )
    }
}
