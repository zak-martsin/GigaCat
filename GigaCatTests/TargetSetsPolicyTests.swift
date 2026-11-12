import Foundation
import Testing
@testable import GigaCat

struct TargetSetsPolicyTests {
    @Test(arguments: [
        (TrainingGoal.loseWeight, TrainingLevel.beginner, 2),
        (.loseWeight, .intermediate, 3), (.loseWeight, .advanced, 3),
        (.maintain, .beginner, 2), (.maintain, .intermediate, 3), (.maintain, .advanced, 3),
        (.buildMuscle, .beginner, 3), (.buildMuscle, .intermediate, 4), (.buildMuscle, .advanced, 4)
    ])
    func resolvesApprovedMatrix(goal: TrainingGoal, level: TrainingLevel, expected: Int) {
        #expect(TargetSetsPolicy().targetSets(goal: goal, level: level) == expected)
    }

    @Test
    func incompleteInputsAlwaysUseTwoSets() {
        let policy = TargetSetsPolicy()
        #expect(policy.targetSets(goal: nil, level: nil) == 2)
        for goal in TrainingGoal.allCases {
            #expect(policy.targetSets(goal: goal, level: nil) == 2)
        }
        for level in TrainingLevel.allCases {
            #expect(policy.targetSets(goal: nil, level: level) == 2)
        }
    }

    @Test
    func selectingProgramPreservesPersonalization() {
        let user = User(goal: .buildMuscle, level: .advanced, avatarPath: "user/avatar.png")
        let selected = user.selectingProgram(UUID())
        #expect(selected.goal == user.goal)
        #expect(selected.level == user.level)
        #expect(selected.avatarPath == user.avatarPath)
        #expect(selected.selectingProgram(nil).goal == user.goal)
    }
}

extension TargetSetsPolicyTests {
    @Test(arguments: TrainingGoal.allCases, TrainingLevel.allCases)
    func programOverrideAlwaysWins(goal: TrainingGoal, level: TrainingLevel) {
        #expect(TargetSetsPolicy().targetSets(goal: goal, level: level, override: 6) == 6)
    }

    @Test
    func overrideAlsoWinsForIncompleteProfiles() {
        let policy = TargetSetsPolicy()
        #expect(policy.targetSets(goal: nil, level: nil, override: 5) == 5)
        #expect(policy.targetSets(goal: .buildMuscle, level: nil, override: 5) == 5)
        #expect(policy.targetSets(goal: nil, level: .advanced, override: 5) == 5)
    }
}
