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
        onSignOut: @escaping () -> Void = {}
    ) {
        appShellView = AppShellView(
            repositoryFactory: repositoryFactory,
            onSignOut: onSignOut
        )
    }

    var body: some View {
        appShellView
    }
}
