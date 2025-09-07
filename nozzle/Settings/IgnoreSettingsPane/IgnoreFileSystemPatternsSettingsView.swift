import SwiftUI
import Defaults

struct IgnoreFileSystemPatternsSettingsView: View {
  @Default(.ignoredFilePatterns) private var ignoredFilePatterns

  @FocusState private var focus: String.ID?
  @State private var edit = ""
  @State private var selection = ""

  var body: some View {
    VStack(alignment: .leading) {
      List(selection: $selection) {
        ForEach(ignoredFilePatterns) { pattern in
          TextField("", text: Binding(
            get: { pattern },
            set: {
              guard !$0.isEmpty, pattern != $0 else { return }
              edit = $0
            })
          ).onSubmit {
            remove(pattern)
            ignoredFilePatterns.append(edit)
          }.focused($focus, equals: pattern)
        }
      }.onDeleteCommand {
        remove(selection)
      }

      HStack {
        ControlGroup {
          Button("", systemImage: "plus") {
            ignoredFilePatterns.append("*.tmp")
            focus = "*.tmp"
          }
          
          Button("", systemImage: "minus") {
            remove(selection)
          }
        }
        .frame(width: 50)

        Spacer()

        Button {
          resetToDefaults()
        } label: {
          Text("IgnoredFilePatternsReset", tableName: "IgnoreSettings")
        }
      }

      Text("IgnoredFilePatternsDescription", tableName: "IgnoreSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
    }.padding()
  }

  private func remove(_ pattern: String?) {
    guard let pattern else { return }
    ignoredFilePatterns.removeAll(where: { $0 == pattern })
  }
  
  private func resetToDefaults() {
    // Reset to the default patterns defined in Defaults.Keys
    ignoredFilePatterns = [
      ".DS_Store", ".git", "node_modules", "build", ".idea", ".trash", 
      ".gradle", ".xcuserdata", ".swiftpm", ".gitignore", ".venv",
      "__pycache__", "*.pyc", ".pytest_cache", "target", ".next",
      ".nuxt", "dist", ".cache", ".temp", ".tmp", "*.o", "*.class",
      ".env", ".env.local", ".terraform", ".vscode", "*.log",
      "DerivedData", ".bundle", "vendor/bundle", "Pods", "*.xcarchive",
      ".nyc_output", "coverage", ".sass-cache", "*.dSYM", "*.app"
    ]
  }
}

#Preview {
  IgnoreFileSystemPatternsSettingsView()
    .environment(\.locale, .init(identifier: "en"))
}