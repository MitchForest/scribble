import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore
    @State private var showOnboarding = true

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingFlowView {
                    showOnboarding = false
                }
                .environmentObject(dataStore)
            } else {
                HomeView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PracticeDataStore())
}
