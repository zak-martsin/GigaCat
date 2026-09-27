//
//  ContentView.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 23/06/2026.
//

import SwiftUI

struct ContentView: View {
    private let appShellView: AppShellView

    init(
        repositoryFactory: some RepositoryFactory,
        userID: UUID,
        syncCoordinator: any SyncCoordinating,
        systemCatalogSynchronizer: any SystemCatalogSyncing,
        programArtworkService: any ProgramArtworkServicing,
        profileBootstrapper: any ProfileBootstrapping,
        profileSyncRecoveryService: any ProfileSyncRecovering,
        onSignOut: @escaping () -> Void = {}
    ) {
        appShellView = AppShellView(
            repositoryFactory: repositoryFactory,
            userID: userID,
            syncCoordinator: syncCoordinator,
            systemCatalogSynchronizer: systemCatalogSynchronizer,
            programArtworkService: programArtworkService,
            profileBootstrapper: profileBootstrapper,
            profileSyncRecoveryService: profileSyncRecoveryService,
            onSignOut: onSignOut
        )
    }

    var body: some View {
        appShellView
    }
}
