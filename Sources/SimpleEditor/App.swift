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
      if store.isSidebarVisible {
        SidebarView()
          .frame(width: 240)
      }
      EditorPane()
        .overlay(alignment: .topLeading) {
          Button {
            withAnimation(.easeInOut(duration: 0.2)) {
              store.toggleSidebarVisible()
            }
          } label: {
            Image(systemName: "sidebar.leading")
              .font(.system(size: 14, weight: .medium))
              .padding(6)
          }
          .buttonStyle(.plain)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color(nsColor: .windowBackgroundColor))
          )
          .padding(.leading, 8)
          .padding(.top, 8)
          .padding(.trailing, 6)
        }
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear {
      updateWindowTitle()
    }
    .onChange(of: store.windowTitle) {
      updateWindowTitle()
    }
    .onChange(of: store.searchQuery) {
      store.updateSearchMatchesIfNeeded()
    }
    .onChange(of: store.isSearchVisible) {
      store.updateSearchMatchesIfNeeded()
    }
  }

  private func updateWindowTitle() {
    let window = NSApp.keyWindow ?? NSApp.windows.first
    guard let target = window else { return }
    target.title = store.windowTitle
  }
}

struct SidebarView: View {
  @EnvironmentObject private var store: FileStore

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button("+ New") {
          store.createNewFile()
        }
        .buttonStyle(.bordered)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)

      List(selection: $store.selectedFileIDs) {
        ForEach(store.files) { file in
          let isMatched = store.searchMatchedFileIDs.contains(file.id)
          let isSelected = store.selectedFileIDs.contains(file.id)
          VStack(alignment: .leading, spacing: 4) {
            Text(file.name)
              .font(.system(size: 13, weight: .semibold))
            Text(store.formatTimestamp(file.mtime))
              .font(.system(size: 11))
              .foregroundColor(.secondary)
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
        Color.clear.frame(height: 2)
      }
    }
    .frame(width: 240)
    .background(Color(nsColor: .windowBackgroundColor))
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
    .padding(.leading, 28)
    .padding(.trailing, 0)
    .padding(.vertical, 8)
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
