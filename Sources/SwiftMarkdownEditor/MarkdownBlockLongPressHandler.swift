#if canImport(UIKit)
import UIKit

/// Adds block commands without taking over the text view's delegate or selection.
@MainActor
final class MarkdownBlockLongPressHandler: NSObject, UIGestureRecognizerDelegate {
    var onLongPress: ((Int) -> Void)?
    private weak var textView: UITextView?
    private var recognizer: UILongPressGestureRecognizer?

    func attach(to textView: UITextView) {
        guard self.textView !== textView else { return }
        if let oldView = self.textView, let recognizer { oldView.removeGestureRecognizer(recognizer) }
        self.textView = textView
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handle(_:)))
        recognizer.minimumPressDuration = 0.52
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        textView.addGestureRecognizer(recognizer)
        self.recognizer = recognizer
    }

    @objc private func handle(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let textView, textView.markedTextRange == nil else { return }
        let point = recognizer.location(in: textView)
        guard let position = textView.closestPosition(to: point) else { return }
        let offset = textView.offset(from: textView.beginningOfDocument, to: position)
        onLongPress?(offset)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
#else
final class MarkdownBlockLongPressHandler {}
#endif
