import AppKit

final class LineNumberRuler: NSRulerView {
  private weak var textView: NSTextView?
  private let padding: CGFloat = 6

  init(textView: NSTextView) {
    self.textView = textView
    super.init(scrollView: textView.enclosingScrollView!, orientation: .verticalRuler)
    clientView = textView
    ruleThickness = 46
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func drawHashMarksAndLabels(in rect: NSRect) {
    guard let textView = textView,
      let layoutManager = textView.layoutManager,
      let textContainer = textView.textContainer
    else {
      return
    }

    let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? .zero
    let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
    let characterRange = layoutManager.characterRange(
      forGlyphRange: glyphRange, actualGlyphRange: nil)

    let text = textView.string as NSString
    let lineRanges = lineRangesFor(text: text, in: characterRange)

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .right
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: textView.font?.pointSize ?? 12, weight: .regular),
      .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.25),
      .paragraphStyle: paragraphStyle,
    ]

    for (lineNumber, range) in lineRanges {
      let glyphRangeForLine = layoutManager.glyphRange(
        forCharacterRange: range, actualCharacterRange: nil)
      let rectForLine = layoutManager.boundingRect(
        forGlyphRange: glyphRangeForLine, in: textContainer)
      let y = rectForLine.minY - visibleRect.minY + textView.textContainerInset.height
      let label = NSAttributedString(string: "\(lineNumber)", attributes: attributes)
      let size = label.size()
      let x = ruleThickness - padding - size.width
      label.draw(at: NSPoint(x: x, y: y))
    }

    let extraRect = layoutManager.extraLineFragmentRect
    if extraRect.height > 0, textView.string.hasSuffix("\n") {
      let lastNumber = (lineRanges.last?.0 ?? 1) + 1
      let y = extraRect.minY - visibleRect.minY + textView.textContainerInset.height
      if y >= rect.minY && y <= rect.maxY {
        let label = NSAttributedString(string: "\(lastNumber)", attributes: attributes)
        let size = label.size()
        let x = ruleThickness - padding - size.width
        label.draw(at: NSPoint(x: x, y: y))
      }
    }
  }

  private func lineRangesFor(text: NSString, in range: NSRange) -> [(Int, NSRange)] {
    var results: [(Int, NSRange)] = []
    var lineNumber = 1
    var location = 0

    while location < text.length {
      let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
      if NSIntersectionRange(lineRange, range).length > 0 {
        results.append((lineNumber, lineRange))
      }
      location = NSMaxRange(lineRange)
      lineNumber += 1
    }

    if results.isEmpty {
      results.append((1, NSRange(location: 0, length: 0)))
    }

    return results
  }
}
