//
//  localProgramCatalogRepository.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 06/08/2026.
//

import Foundation
import SwiftData

struct LocalProgramCatalogRepository: ProgramCatalogRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchProgramCatalog() async throws -> [ProgramCatalogEntry] {
            let programDescriptor = FetchDescriptor<WorkoutProgramEntity>(
                sortBy: [
                    SortDescriptor(\.title)
                ]
            )
            let programEntities = try context.fetch(programDescriptor)

            let metadataEntities = try context.fetch(
                FetchDescriptor<ProgramCatalogMetadataEntity>()
            )

            let metadataByProgramID = Dictionary(
                uniqueKeysWithValues: metadataEntities.map {
                    ($0.programId, $0)
                }
            )

            return try programEntities.map { entity in
                let program = try WorkoutProgramMapper.toDomain(entity)
                let metadata = metadataByProgramID[program.id]

                return ProgramCatalogEntry(
                    program: program,
                    isRecommended: metadata?.isRecommended ?? false,
                    isPopular: metadata?.isPopular ?? false,
                    rateScore: metadata?.rateScore
                )
            }
        }
    }
