//
//  ProgramCatalogMetadataEntity.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 06/08/2026.
//

import Foundation
import SwiftData

@Model
final class ProgramCatalogMetadataEntity {
    @Attribute(.unique) var programId: UUID
    var isRecommended: Bool
    var isPopular: Bool
    var rateScore: Double?

    init(
        programId: UUID,
        isRecommended: Bool,
        isPopular: Bool,
        rateScore: Double?
    ) {
        self.programId = programId
        self.isRecommended = isRecommended
        self.isPopular = isPopular
        self.rateScore = rateScore
    }
}
