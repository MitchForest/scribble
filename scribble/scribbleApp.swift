//
//  scribbleApp.swift
//  scribble
//
//  Created by Mitchell White on 10/15/25.
//

import SwiftUI
import UIKit

@main
struct scribbleApp: App {
    @StateObject private var dataStore = PracticeDataStore()
    @UIApplicationDelegateAdaptor(OrientationAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .task {
                    HandwritingTemplateLoader.preloadTemplates(for: PracticeDataStore.focusLetters)
                }
                .onAppear {
                    OrientationManager.lock(to: .landscape, rotateTo: .landscapeLeft)
                }
        }
    }
}
