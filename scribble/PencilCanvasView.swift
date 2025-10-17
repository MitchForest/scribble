import SwiftUI
import PencilKit
import Foundation

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var onDrawingChanged: (PKDrawing) -> Void
    var onLiveStrokeSample: ((CanvasStrokeSample) -> Void)? = nil
    var onLiveStrokeDidEnd: (() -> Void)? = nil
    var allowFingerFallback: Bool = false
    var lineWidth: CGFloat = 6

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawing = drawing
        view.delegate = context.coordinator
        context.coordinator.attach(to: view)
        view.backgroundColor = .clear
        view.alwaysBounceVertical = false
        view.alwaysBounceHorizontal = false
        view.minimumZoomScale = 1
        view.maximumZoomScale = 1
        view.isScrollEnabled = false
        view.contentOffset = .zero
        view.contentInset = .zero
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
        if uiView.minimumZoomScale != 1 {
            uiView.minimumZoomScale = 1
        }
        if uiView.maximumZoomScale != 1 {
            uiView.maximumZoomScale = 1
        }
        if uiView.isScrollEnabled {
            uiView.isScrollEnabled = false
        }
        if uiView.alwaysBounceVertical {
            uiView.alwaysBounceVertical = false
        }
        if uiView.alwaysBounceHorizontal {
            uiView.alwaysBounceHorizontal = false
        }
        if uiView.contentInset != .zero {
            uiView.contentInset = .zero
        }
        if drawing.strokes.isEmpty {
            if uiView.zoomScale != 1 {
                uiView.setZoomScale(1, animated: false)
            }
            if uiView.contentOffset != .zero {
                uiView.setContentOffset(.zero, animated: false)
            }
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

        context.coordinator.attach(to: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let parent: PencilCanvasView
        private weak var observedCanvasView: PKCanvasView?

        init(parent: PencilCanvasView) {
            self.parent = parent
        }

        func attach(to canvasView: PKCanvasView) {
            if observedCanvasView !== canvasView {
                observedCanvasView?.drawingGestureRecognizer.removeTarget(self,
                                                                          action: #selector(handleDrawingGesture(_:)))
                observedCanvasView = canvasView
                canvasView.drawingGestureRecognizer.addTarget(self,
                                                              action: #selector(handleDrawingGesture(_:)))
            }
        }

        deinit {
            observedCanvasView?.drawingGestureRecognizer.removeTarget(self,
                                                                      action: #selector(handleDrawingGesture(_:)))
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let updatedDrawing = canvasView.drawing
            DispatchQueue.main.async { [weak self, canvasView, updatedDrawing] in
                guard let self else { return }
                self.parent.drawing = updatedDrawing
                self.parent.onDrawingChanged(updatedDrawing)
                self.emitLiveSample(from: canvasView)
            }
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [weak self, canvasView] in
                self?.emitLiveSample(from: canvasView)
            }
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async { [parent = parent] in
                parent.onLiveStrokeDidEnd?()
            }
        }

        @objc private func handleDrawingGesture(_ recognizer: UIGestureRecognizer) {
            guard let canvasView = observedCanvasView else { return }
            switch recognizer.state {
            case .began, .changed:
                emitLiveSample(from: canvasView)
            case .ended, .cancelled, .failed:
                DispatchQueue.main.async { [parent = parent] in
                    parent.onLiveStrokeDidEnd?()
                }
            default:
                break
            }
        }

        private func emitLiveSample(from canvasView: PKCanvasView) {
            guard let handler = parent.onLiveStrokeSample else { return }
            let gesture = canvasView.drawingGestureRecognizer
            if gesture.state == .began || gesture.state == .changed {
                let location = gesture.location(in: canvasView)
                let timestamp = Date().timeIntervalSinceReferenceDate
                handler(CanvasStrokeSample(location: location, timestamp: timestamp))
            }
        }
    }
}
