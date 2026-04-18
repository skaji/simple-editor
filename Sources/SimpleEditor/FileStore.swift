import Foundation

struct FileEntry: Identifiable, Hashable {
  let id: String
  let name: String
  let mtime: Date
}

final class FileStore: ObservableObject {
  private enum DefaultsValue {
    static let fontSize = 18
    static let minFontSize = 10
    static let maxFontSize = 28
  }

  private struct AppConfig: Codable {
    var fontSize: Int
    var wrapLines: Bool
    var isSidebarVisible: Bool

    init(fontSize: Int, wrapLines: Bool, isSidebarVisible: Bool) {
      self.fontSize = fontSize
      self.wrapLines = wrapLines
      self.isSidebarVisible = isSidebarVisible
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      fontSize = (try? container.decode(Int.self, forKey: .fontSize)) ?? DefaultsValue.fontSize
      wrapLines = (try? container.decode(Bool.self, forKey: .wrapLines)) ?? false
      isSidebarVisible =
        (try? container.decode(Bool.self, forKey: .isSidebarVisible)) ?? true
    }
  }

  @Published var files: [FileEntry] = []
  @Published var selectedFileIDs: Set<String> = []
  @Published var currentFileID: String? = nil
  @Published var content: String = ""
  @Published var searchQuery: String = ""
  @Published var isSearchVisible: Bool = false
  @Published var searchFocusToken: Int = 0
  @Published var searchMatchedFileIDs: Set<String> = []
  @Published var showAllFiles: Bool = false
  @Published private(set) var fontSize: Int = 16
  @Published private(set) var wrapLines: Bool = false
  @Published private(set) var isSidebarVisible: Bool = true

  private let baseURL: URL
  private let configURL: URL
  private var saveWorkItem: DispatchWorkItem?
  private var loading = false
  private var isDirty = false
  private var lastLoadedContent = ""
  private var isComposing = false

  init() {
    let home = FileManager.default.homeDirectoryForCurrentUser
    baseURL = home.appendingPathComponent(".simple-editor", isDirectory: true)
    configURL = baseURL.appendingPathComponent("_config.json")
    loadConfig()
  }

  func loadFilesIfNeeded() {
    refreshFiles()
    if currentFileID == nil, let first = preferredVisibleFile() {
      currentFileID = first.id
      selectedFileIDs = [first.id]
      loadSelectedFile()
    }
  }

  func refreshFiles() {
    do {
      try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
      let entries = try FileManager.default.contentsOfDirectory(
        at: baseURL, includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles])
      let mapped = entries.compactMap { url -> FileEntry? in
        let name = url.lastPathComponent
        if name.hasPrefix(".") || name.hasPrefix("_") { return nil }
        guard
          let mtime =
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        else {
          return nil
        }
        return FileEntry(id: name, name: name, mtime: mtime)
      }
      files = mapped.sorted { $0.name > $1.name }
      updateSearchMatchesIfNeeded()
    } catch {
      files = []
    }
  }

  var visibleFiles: [FileEntry] {
    guard !showAllFiles else { return files }
    return files.filter { file in
      isRecentlyModified(file) || selectedFileIDs.contains(file.id) || currentFileID == file.id
    }
  }

  var olderHiddenFileCount: Int {
    files.filter { file in
      !isRecentlyModified(file) && !selectedFileIDs.contains(file.id) && currentFileID != file.id
    }.count
  }

  var shouldShowFileVisibilityToggle: Bool {
    showAllFiles || olderHiddenFileCount > 0
  }

  func toggleShowAllFiles() {
    showAllFiles.toggle()
  }

  func formatRelativeTimestamp(_ date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 {
      return "just now"
    }

    let minutes = seconds / 60
    if minutes < 60 {
      return "\(minutes) \(minutes == 1 ? "minute" : "minutes") ago"
    }

    let hours = minutes / 60
    if hours < 24 {
      return "\(hours) \(hours == 1 ? "hour" : "hours") ago"
    }

    if Calendar.current.isDateInYesterday(date) {
      return "yesterday"
    }

    let days = hours / 24
    if days < 30 {
      return "\(days) \(days == 1 ? "day" : "days") ago"
    }

    let months = days / 30
    if months < 12 {
      return "\(months) \(months == 1 ? "month" : "months") ago"
    }

    let years = months / 12
    return "\(years) \(years == 1 ? "year" : "years") ago"
  }

  private func isRecentlyModified(_ file: FileEntry) -> Bool {
    guard let cutoff = Calendar.current.date(byAdding: .month, value: -2, to: Date()) else {
      return true
    }
    return file.mtime >= cutoff
  }

  private func preferredVisibleFile() -> FileEntry? {
    if showAllFiles {
      return files.first
    }
    return files.first(where: { isRecentlyModified($0) }) ?? files.first
  }

  func createNewFile() {
    do {
      try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = "yyyyMMdd-HHmmss"
      let stamp = formatter.string(from: Date())
      var name = "\(stamp).txt"
      var candidate = baseURL.appendingPathComponent(name)
      var index = 0
      while FileManager.default.fileExists(atPath: candidate.path) {
        index += 1
        name = "\(stamp)-\(index).txt"
        candidate = baseURL.appendingPathComponent(name)
      }
      FileManager.default.createFile(atPath: candidate.path, contents: nil)
      refreshFiles()
      currentFileID = name
      selectedFileIDs = [name]
      loadSelectedFile()
    } catch {
      return
    }
  }

  func loadSelectedFile() {
    guard let selected = currentFileID else { return }
    let url = baseURL.appendingPathComponent(selected)
    loading = true
    if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
      content = text
      lastLoadedContent = text
    } else {
      content = ""
      lastLoadedContent = ""
    }
    isDirty = false
    loading = false
  }

  func editorDidChange(isComposing composing: Bool) {
    guard !loading else { return }
    isComposing = composing
    if composing {
      saveWorkItem?.cancel()
    }
    if content == lastLoadedContent && !isDirty {
      return
    }
    isDirty = true
    if !composing {
      scheduleSave()
    }
  }

  func updateSearchMatchesIfNeeded() {
    guard !searchQuery.isEmpty else {
      if !searchMatchedFileIDs.isEmpty {
        searchMatchedFileIDs = []
      }
      return
    }
    var matches: Set<String> = []
    for file in files {
      let text: String
      if file.id == currentFileID {
        text = content
      } else {
        let url = baseURL.appendingPathComponent(file.id)
        guard let data = try? Data(contentsOf: url),
          let loaded = String(data: data, encoding: .utf8)
        else {
          continue
        }
        text = loaded
      }
      if text.range(of: searchQuery, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
        matches.insert(file.id)
      }
    }
    searchMatchedFileIDs = matches
  }

  private func scheduleSave() {
    saveWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
      self?.saveNow()
    }
    saveWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
  }

  private func saveNow() {
    guard isDirty else { return }
    guard !isComposing else { return }
    guard let selected = currentFileID else { return }
    let url = baseURL.appendingPathComponent(selected)
    do {
      try content.data(using: .utf8)?.write(to: url)
      lastLoadedContent = content
      isDirty = false
      refreshFiles()
    } catch {
      return
    }
  }

  func compositionDidEndIfNeeded() {
    if !isComposing, isDirty {
      scheduleSave()
    }
  }

  func softDelete(file: FileEntry) {
    let url = baseURL.appendingPathComponent(file.name)
    let ext = url.pathExtension
    let base = url.deletingPathExtension().lastPathComponent
    for i in 0..<100 {
      let suffix = i == 0 ? "" : "-\(i)"
      let newName = "_\(base)\(suffix).\(ext)"
      let newURL = baseURL.appendingPathComponent(newName)
      if FileManager.default.fileExists(atPath: newURL.path) {
        continue
      }
      do {
        try FileManager.default.moveItem(at: url, to: newURL)
        break
      } catch {
        break
      }
    }
    refreshFiles()
    if currentFileID == file.id {
      currentFileID = preferredVisibleFile()?.id
      if let current = currentFileID {
        selectedFileIDs = [current]
      } else {
        selectedFileIDs = []
      }
      loadSelectedFile()
    }
  }

  func saveSelectedFile() {
    guard let selected = currentFileID else { return }
    if selected.isEmpty {
      return
    }
    if content == lastLoadedContent && !isDirty {
      return
    }
    isDirty = true
    saveNow()
  }

  func handleSelectionChange() {
    if selectedFileIDs.isEmpty {
      return
    }
    if selectedFileIDs.count == 1 {
      let id = selectedFileIDs.first!
      if currentFileID != id {
        currentFileID = id
        loadSelectedFile()
      }
      return
    }
    if let current = currentFileID, selectedFileIDs.contains(current) {
      return
    }
    let next = selectedFileIDs.sorted().first
    if currentFileID != next {
      currentFileID = next
      loadSelectedFile()
    }
  }

  func saveSelectedFiles() {
    guard !selectedFileIDs.isEmpty else {
      saveSelectedFile()
      return
    }
    if let current = currentFileID, selectedFileIDs.contains(current) {
      saveSelectedFile()
    }
  }

  func softDeleteSelectedFiles() {
    let targets = selectedFileIDs
    guard !targets.isEmpty else {
      return
    }
    for fileID in targets {
      if let entry = files.first(where: { $0.id == fileID }) {
        softDelete(file: entry)
      }
    }
    refreshFiles()
    if let first = preferredVisibleFile() {
      currentFileID = first.id
      selectedFileIDs = [first.id]
      loadSelectedFile()
    } else {
      currentFileID = nil
      selectedFileIDs = []
      content = ""
    }
  }

  func setFontSize(_ size: Int) {
    let clamped = min(DefaultsValue.maxFontSize, max(DefaultsValue.minFontSize, size))
    fontSize = clamped
    saveConfig()
  }

  func bumpFontSize(_ delta: Int) {
    setFontSize(fontSize + delta)
  }

  func resetFontSize() {
    setFontSize(DefaultsValue.fontSize)
  }

  func setWrapLines(_ value: Bool) {
    wrapLines = value
    saveConfig()
  }

  func setSidebarVisible(_ value: Bool) {
    guard isSidebarVisible != value else { return }
    isSidebarVisible = value
    saveConfig()
  }

  func toggleSidebarVisible() {
    setSidebarVisible(!isSidebarVisible)
  }

  var lineCount: Int {
    if content.isEmpty {
      return 1
    }
    var count = 1
    for ch in content {
      if ch.isNewline {
        count += 1
      }
    }
    return count
  }

  var windowTitle: String {
    let name = currentFileID ?? "SimpleEditor"
    return "\(name) — \(lineCount) lines"
  }

  private func loadConfig() {
    do {
      try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
      let data = try Data(contentsOf: configURL)
      let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
      fontSize = min(DefaultsValue.maxFontSize, max(DefaultsValue.minFontSize, decoded.fontSize))
      wrapLines = decoded.wrapLines
      isSidebarVisible = decoded.isSidebarVisible
    } catch {
      fontSize = DefaultsValue.fontSize
      wrapLines = false
      isSidebarVisible = true
      saveConfig()
    }
  }

  private func saveConfig() {
    let config = AppConfig(
      fontSize: fontSize, wrapLines: wrapLines, isSidebarVisible: isSidebarVisible)
    do {
      try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(config)
      try data.write(to: configURL, options: .atomic)
    } catch {
      return
    }
  }
}
