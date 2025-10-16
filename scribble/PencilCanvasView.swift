import SwiftUI
import PencilKit

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var onDrawingChanged: (PKDrawing) -> Void
    var allowFingerFallback: Bool = false
    var lineWidth: CGFloat = 6

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawing = drawing
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.alwaysBounceVertical = false
        view.alwaysBounceHorizontal = false
        if #available(iOS 14.0, *) {
            view.drawingPolicy = allowFingerFallback ? .anyInput : .pencilOnly
        } else {
            view.allowsFingerDrawing = allowFingerFallback
        }
        view.tool = PKInkingTool(.pen, color: .label, width: lineWidth)
        return view
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        if #available(iOS 14.0, *) {
            let desiredPolicy: PKCanvasViewDrawingPolicy = allowFingerFallback ? .anyInput : .pencilOnly
            if uiView.drawingPolicy != desiredPolicy {
                uiView.drawingPolicy = desiredPolicy
            }
        } else {
            if uiView.allowsFingerDrawing != allowFingerFallback {
                uiView.allowsFingerDrawing = allowFingerFallback
            }
        }

        if let inkingTool = uiView.tool as? PKInkingTool {
            if inkingTool.width != lineWidth {
                uiView.tool = PKInkingTool(inkingTool.inkType, color: inkingTool.color, width: lineWidth)
            }
        } else {
            uiView.tool = PKInkingTool(.pen, color: .label, width: lineWidth)
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
