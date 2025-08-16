import Defaults
import SwiftUI

struct FooterView: View {
  @Bindable var footer: Footer

  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags
  @Default(.showFooter) private var showFooter

  var body: some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)

      ForEach(footer.items) { item in
        FooterItemView(item: item)
      }
    }
    .opacity(showFooter ? 1 : 0)
    .frame(maxHeight: showFooter ? nil : 0)
  }
}
