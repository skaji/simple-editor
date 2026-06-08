import SwiftUI

@main
struct SimpleEditorApp: App {
  @StateObject private var store = FileStore()
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .onAppear {
          store.loadFilesIfNeeded()
        }
    }
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(after: .textEditing) {
        Button("Find") {
          store.isSearchVisible = true
          store.searchFocusToken &+= 1
        }
        .keyboardShortcut("f", modifiers: [.command])

        Button("Hide Find") {
          store.isSearchVisible = false
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
      }
      CommandGroup(after: .textFormatting) {
        Button("Bigger Text") {
          store.bumpFontSize(2)
        }
        .keyboardShortcut("=", modifiers: [.command])

        Button("Smaller Text") {
          store.bumpFontSize(-2)
        }
        .keyboardShortcut("-", modifiers: [.command])

        Button("Reset Text Size") {
          store.resetFontSize()
        }
        .keyboardShortcut("0", modifiers: [.command])
      }
    }
    Settings {
      SettingsView()
        .environmentObject(store)
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    NSApp.windows.first?.makeKeyAndOrderFront(nil)
    UserDefaults.standard.set(false, forKey: "ApplePressAndHoldEnabled")
    UserDefaults.standard.set(false, forKey: "NSAutomaticPeriodSubstitutionEnabled")
    UserDefaults.standard.set(false, forKey: "NSAutomaticTextReplacementEnabled")
    UserDefaults.standard.set(false, forKey: "NSAutomaticSpellingCorrectionEnabled")
    UserDefaults.standard.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
    UserDefaults.standard.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
  }
}

struct ContentView: View {
  @EnvironmentObject private var store: FileStore

  var body: some View {
    HStack(spacing: 0) {
      SidebarView()
        .frame(width: 240)
      EditorContainer()
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .ignoresSafeArea(.container, edges: .top)
    .background(WindowTitleConfigurator(title: store.windowTitle))
    .onChange(of: store.searchQuery) {
      store.updateSearchMatchesIfNeeded()
    }
    .onChange(of: store.isSearchVisible) {
      store.updateSearchMatchesIfNeeded()
    }
  }
}

struct WindowTitleConfigurator: NSViewRepresentable, Equatable {
  let title: String

  static func == (lhs: WindowTitleConfigurator, rhs: WindowTitleConfigurator) -> Bool {
    lhs.title == rhs.title
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    DispatchQueue.main.async {
      configureWindow(for: view, coordinator: context.coordinator)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      configureWindow(for: nsView, coordinator: context.coordinator)
    }
  }

  private func configureWindow(for view: NSView, coordinator: Coordinator) {
    guard let window = view.window else { return }
    coordinator.configure(window: window, title: title)
  }

  final class Coordinator {
    private weak var window: NSWindow?
    private var title = ""

    func configure(window: NSWindow, title: String) {
      let didChangeWindow = self.window !== window
      let didChangeTitle = self.title != title
      self.window = window
      self.title = title
      if didChangeWindow {
        window.isMovableByWindowBackground = true
      }
      if didChangeWindow || didChangeTitle {
        window.title = title
      }
    }
  }
}

struct SidebarView: View {
  @EnvironmentObject private var store: FileStore
  @State private var isNewButtonHovered = false

  var body: some View {
    VStack(spacing: 0) {
      SidebarHeader()

      HStack {
        Button {
          store.createNewFile()
        } label: {
          Label("New file", systemImage: "square.and.pencil")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              RoundedRectangle(cornerRadius: 6)
                .fill(
                  isNewButtonHovered
                    ? Color(nsColor: .quaternaryLabelColor).opacity(0.8) : Color.clear
                )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
          isNewButtonHovered = hovering
        }
      }
      .padding(.horizontal, 12)
      .padding(.top, 6)
      .padding(.bottom, 8)

      List(selection: $store.selectedFileIDs) {
        ForEach(store.visibleFiles) { file in
          let isMatched = store.searchMatchedFileIDs.contains(file.id)
          let isSelected = store.selectedFileIDs.contains(file.id)
          VStack(alignment: .leading, spacing: 4) {
            Text(file.name)
              .font(.system(size: 13, weight: .semibold))
            TimelineView(.periodic(from: Date(), by: 60)) { context in
              Text(store.formatRelativeTimestamp(file.mtime, now: context.date))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
          }
          .contextMenu {
            Button("Save Selected Files") {
              if store.selectedFileIDs.isEmpty {
                store.selectedFileIDs = [file.id]
              }
              store.handleSelectionChange()
              store.saveSelectedFiles()
            }
            Button("Delete Selected Files") {
              if store.selectedFileIDs.isEmpty {
                store.selectedFileIDs = [file.id]
              }
              store.handleSelectionChange()
              store.softDeleteSelectedFiles()
            }
          }
          .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
          .listRowBackground(
            Group {
              if isMatched && !isSelected {
                RoundedRectangle(cornerRadius: 8)
                  .fill(Color(nsColor: .systemYellow).opacity(0.25))
                  .padding(.vertical, 2)
                  .padding(.horizontal, 8)
              } else {
                Color.clear
              }
            }
          )
          .tag(file.id)
        }
      }
      .listStyle(.sidebar)
      .scrollContentBackground(.hidden)
      .safeAreaInset(edge: .top) {
        Color.clear.frame(height: 0)
      }

      if store.shouldShowFileVisibilityToggle {
        Button {
          store.toggleShowAllFiles()
        } label: {
          Text(store.showAllFiles ? "Show less" : "Show more")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }
    }
    .frame(width: 240)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

struct SidebarHeader: View {
  var body: some View {
    Color.clear.frame(height: EditorLayout.titlebarContentHeight)
  }
}

struct EditorContainer: View {
  var body: some View {
    VStack(spacing: 0) {
      EditorTitlebar()
      EditorPane()
    }
    .background(Color(nsColor: .textBackgroundColor))
  }
}

struct EditorTitlebar: View {
  @EnvironmentObject private var store: FileStore
  @State private var isWrapButtonHovered = false

  var body: some View {
    HStack(spacing: 8) {
      TitlebarFilenameText(title: store.currentFileID ?? "SimpleEditor")
        .equatable()
      Spacer()
      Button {
        store.setWrapLines(!store.wrapLines)
      } label: {
        Image(systemName: "return")
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(
            store.wrapLines
              ? Color(nsColor: .labelColor).opacity(0.62)
              : Color(nsColor: .secondaryLabelColor).opacity(0.62)
          )
          .frame(width: 28, height: 28)
          .background(
            RoundedRectangle(cornerRadius: 6)
              .fill(
                store.wrapLines || isWrapButtonHovered
                  ? Color(nsColor: .quaternaryLabelColor).opacity(0.7) : Color.clear
              )
          )
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())
      .help(store.wrapLines ? "Disable text wrap" : "Enable text wrap")
      .accessibilityLabel(store.wrapLines ? "Disable text wrap" : "Enable text wrap")
      .onHover { hovering in
        isWrapButtonHovered = hovering
      }
    }
    .padding(.leading, EditorLayout.lineNumberRulerWidth + 16)
    .padding(.trailing, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: EditorLayout.titlebarContentHeight)
    .background(Color(nsColor: .textBackgroundColor))
  }
}

struct TitlebarFilenameText: View, Equatable {
  let title: String

  var body: some View {
    Text(title)
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(Color(nsColor: NSColor.secondaryLabelColor.withAlphaComponent(0.28)))
      .lineLimit(1)
      .truncationMode(.middle)
  }
}

struct EditorPane: View {
  @EnvironmentObject private var store: FileStore
  @FocusState private var isSearchFieldFocused: Bool

  var body: some View {
    EditorView(
      text: $store.content, fontSize: store.fontSize, wrapLines: store.wrapLines,
      onEditorChanged: { composing in
        store.editorDidChange(isComposing: composing)
        if !composing {
          store.compositionDidEndIfNeeded()
        }
      }, searchQuery: $store.searchQuery
    )
    .id(store.wrapLines)
    .onChange(of: store.selectedFileIDs) {
      store.handleSelectionChange()
    }
    .padding(.trailing, 0)
    .padding(.top, 2)
    .padding(.bottom, 8)
    .overlay(alignment: .topTrailing) {
      if store.isSearchVisible {
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.secondary)
          TextField("Find", text: $store.searchQuery)
            .textFieldStyle(.plain)
            .frame(width: 200)
            .focused($isSearchFieldFocused)
            .onExitCommand {
              store.isSearchVisible = false
            }
          Button {
            store.isSearchVisible = false
            store.searchQuery = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
        }
        .padding(8)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .padding(.top, 8)
        .padding(.trailing, 10)
      }
    }
    .onChange(of: store.isSearchVisible) { _, isVisible in
      if isVisible {
        isSearchFieldFocused = true
      } else {
        isSearchFieldFocused = false
      }
    }
    .onChange(of: store.searchFocusToken) { _, _ in
      if store.isSearchVisible {
        isSearchFieldFocused = true
      }
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: FileStore

  var body: some View {
    Form {
      Toggle(
        "Wrap lines",
        isOn: Binding(
          get: {
            store.wrapLines
          },
          set: { newValue in
            store.setWrapLines(newValue)
          }))
      HStack {
        Text("Font size")
        Slider(
          value: Binding(
            get: {
              Double(store.fontSize)
            },
            set: { newValue in
              store.setFontSize(Int(newValue))
            }), in: 10...28, step: 1)
        Text("\(store.fontSize)px")
          .frame(width: 50, alignment: .trailing)
      }
    }
    .padding(20)
    .frame(width: 360)
  }
}
