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
                    repositoryFactory: dependencies.repositoryFactory
                )
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
    case failed(String)
}
