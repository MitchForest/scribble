import Foundation

@MainActor
final class FreePracticeViewModel: ObservableObject {
    @Published var targetText: String {
        didSet {
            if targetText != oldValue {
                rebuildTimeline()
            }
        }
    }

    @Published private(set) var timelineSnapshot: PracticeTimeline

    init(initialText: String = "a a a") {
        let snapshot = PracticeTimelineBuilder.build(from: initialText)
        self.targetText = initialText
        self.timelineSnapshot = snapshot
    }

    func rebuildTimeline() {
        timelineSnapshot = PracticeTimelineBuilder.build(from: targetText)
    }
}

extension FreePracticeViewModel {
    var timeline: [LetterTimelineItem] { timelineSnapshot.items }
}
