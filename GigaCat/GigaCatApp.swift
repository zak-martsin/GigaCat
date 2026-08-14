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
                try AppCompositionRoot.makeLocalRepositoryFactory()
            )
        } catch {
            startupState = .failed(error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch startupState {
            case .ready(let repositoryFactory):
                ContentView(repositoryFactory: repositoryFactory)
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
    case ready(LocalRepositoryFactory)
    case failed(String)
}
