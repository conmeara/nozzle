import SwiftUI

struct UniversalListView: View {
    let items: [UniversalItemDecorator]   // already adapted
    @Environment(AppState.self) private var appState
    @Environment(ContentManager.self) private var contentManager
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { decorator in
                        UniversalItemView(item: decorator)
                            .id(decorator.id)
                    }
                }
            }
            .onChange(of: contentManager.focusedItemId) { _, newValue in
                if let id = newValue {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
