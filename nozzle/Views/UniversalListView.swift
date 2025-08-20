import SwiftUI

struct UniversalListView: View {
    let items: [UniversalItemDecorator]   // already adapted
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { decorator in
                    UniversalItemView(item: decorator)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}