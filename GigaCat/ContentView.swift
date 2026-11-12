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
        email: String?,
        syncCoordinator: any SyncCoordinating,
        systemCatalogSynchronizer: any SystemCatalogSyncing,
        artworkService: any ArtworkServicing,
        profileBootstrapper: any ProfileBootstrapping,
        profileSyncRecoveryService: any ProfileSyncRecovering,
        onSignOut: @escaping () -> Void = {}
    ) {
        appShellView = AppShellView(
            repositoryFactory: repositoryFactory,
            userID: userID,
            email: email,
            syncCoordinator: syncCoordinator,
            systemCatalogSynchronizer: systemCatalogSynchronizer,
            artworkService: artworkService,
            profileBootstrapper: profileBootstrapper,
            profileSyncRecoveryService: profileSyncRecoveryService,
            onSignOut: onSignOut
        )
    }

    var body: some View {
        appShellView
    }
}
