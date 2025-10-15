//
//  scribbleApp.swift
//  scribble
//
//  Created by Mitchell White on 10/15/25.
//

import SwiftUI

@main
struct scribbleApp: App {
    @StateObject private var dataStore = PracticeDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .task {
                    HandwritingTemplateLoader.preloadTemplates(for: PracticeDataStore.focusLetters)
                }
        }
    }
}
