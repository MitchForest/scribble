import SwiftUI
import PencilKit

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawing = drawing
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.alwaysBounceVertical = false
        view.alwaysBounceHorizontal = false
        view.allowsFingerDrawing = false
        view.tool = PKInkingTool(.pen, color: .label, width: 6)
        return view
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let parent: PencilCanvasView

        init(parent: PencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onDrawingChanged(canvasView.drawing)
        }
    }
}
