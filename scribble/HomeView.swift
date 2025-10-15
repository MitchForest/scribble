import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var dataStore: PracticeDataStore

    @State private var showingSettings = false

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(PracticeDataStore.focusLetters, id: \.self) { letterId in
                        let mastery = dataStore.mastery(for: letterId)
                        NavigationLink(value: Route.practice(letterId: letterId)) {
                            LetterTile(letterId: letterId,
                                       mastery: mastery,
                                       unlocked: mastery.unlocked,
                                       displayName: dataStore.displayName(for: letterId))
                        }
                        .buttonStyle(.plain)
                        .disabled(!mastery.unlocked)
                        .overlay {
                            if !mastery.unlocked {
                                LockedOverlay()
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Letters")
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .practice(let letterId):
                    PracticeSessionView(letterId: letterId)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Open settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(dataStore)
            }
        }
    }

    private enum Route: Hashable {
        case practice(letterId: String)
    }
}

private struct LetterTile: View {
    let letterId: String
    let mastery: LetterMasteryRecord
    let unlocked: Bool
    let displayName: String

    private var progress: Double {
        Double(mastery.bestScore) / 100.0
    }

    private var subheadline: String {
        if mastery.bestScore == 0 {
            return unlocked ? "Not attempted" : "Locked"
        }
        return "Best \(mastery.bestScore)"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))

            VStack(spacing: 12) {
                ProgressRing(progress: progress, letter: displayName)

                VStack(spacing: 4) {
                    Text(displayName)
                        .font(.title3.weight(.semibold))
                    Text(subheadline)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
        }
        .frame(height: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName) letter card")
        .accessibilityValue(mastery.bestScore > 0 ? "Best score \(mastery.bestScore)" : (unlocked ? "Not attempted" : "Locked"))
    }
}

private struct ProgressRing: View {
    let progress: Double
    let letter: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 10)

            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .foregroundColor(progress >= 0.8 ? .green : .blue)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            Text(letter)
                .font(.system(size: 32, weight: .bold, design: .rounded))
        }
        .frame(width: 88, height: 88)
    }
}

private struct LockedOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.black.opacity(0.25))
            .overlay {
                Image(systemName: "lock.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.9))
            }
    }
}
