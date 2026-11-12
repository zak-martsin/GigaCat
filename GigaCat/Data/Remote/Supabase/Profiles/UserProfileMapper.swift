enum UserProfileMapper {
    static func toDomain(_ dto: UserProfileDTO) -> User {
        User(
            id: dto.id,
            selectedProgramId: dto.selectedProgramID,
            goal: dto.goal,
            level: dto.level,
            avatarPath: dto.avatarPath,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }
}
