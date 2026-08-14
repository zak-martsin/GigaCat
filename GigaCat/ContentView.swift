//
//  ContentView.swift
//  GigaCat
//
//  Created by Захар Марцинкевич on 23/06/2026.
//

import SwiftUI

struct ContentView: View {
    private let appShellView: AppShellView

    init(repositoryFactory: some RepositoryFactory) {
        appShellView = AppShellView(repositoryFactory: repositoryFactory)
    }

    var body: some View {
        appShellView
    }
}
