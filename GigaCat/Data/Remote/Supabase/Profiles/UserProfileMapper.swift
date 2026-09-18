enum UserProfileMapper {
    static func toDomain(_ dto: UserProfileDTO) -> User {
        User(
            id: dto.id,
            selectedProgramId: dto.selectedProgramID,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }
}
