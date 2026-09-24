//
//  GigaCatApp.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 23/06/2026.
//

import SwiftUI

@main
@MainActor
struct GigaCatApp: App {
    private let startupState: AppStartupState

    init() {
        #if DEBUG
        if UITestAppDependencies.isRequested {
            do {
                startupState = .uiTesting(try UITestAppDependencies.make())
            } catch {
                startupState = .failed(error.localizedDescription)
            }
            return
        }
        #endif

        do {
            startupState = .ready(
                try AppCompositionRoot.makeDependencies()
            )
        } catch {
            startupState = .failed(error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch startupState {
            case .ready(let dependencies):
                AuthenticationRootView(
                    authenticationService: dependencies.authenticationService,
                    currentUserIDStore: dependencies.currentUserContext,
                    profileBootstrapper: dependencies.profileBootstrapService,
                    syncCoordinator: dependencies.syncCoordinator,
                    systemCatalogSynchronizer: dependencies.systemCatalogSyncService,
                    programArtworkService: dependencies.programArtworkService,
                    profileSyncRecoveryService: dependencies.profileSyncRecoveryService,
                    repositoryFactory: dependencies.repositoryFactory
                )
            #if DEBUG
            case .uiTesting(let dependencies):
                ContentView(
                    repositoryFactory: dependencies.repositoryFactory,
                    userID: dependencies.userID,
                    syncCoordinator: dependencies.syncCoordinator,
                    systemCatalogSynchronizer: dependencies.systemCatalogSynchronizer,
                    programArtworkService: dependencies.programArtworkService,
                    profileBootstrapper: dependencies.profileBootstrapper,
                    profileSyncRecoveryService: dependencies.profileSyncRecoveryService
                )
            #endif
            case .failed(let message):
                ContentUnavailableView(
                    "Local data unavailable",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(message)
                )
            }
        }
    }
}

private enum AppStartupState {
    case ready(AppDependencies)
    #if DEBUG
    case uiTesting(UITestAppDependencies)
    #endif
    case failed(String)
}
