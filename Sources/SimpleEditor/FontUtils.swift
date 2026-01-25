import AppKit

func preferredMonospacedFont(ofSize size: CGFloat) -> NSFont {
  let candidates = [
    "Osaka-Mono",
    "Hiragino Sans Mono W3",
    "Hiragino Sans Mono W6",
    "Menlo",
    "SF Mono",
  ]
  for name in candidates {
    if let font = NSFont(name: name, size: size) {
      return font
    }
  }
  return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
}
