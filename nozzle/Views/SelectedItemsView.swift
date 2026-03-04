import SwiftUI

struct SelectedItemsView: View {
    let selectedItems: [UniversalItemDecorator]
    
    @Environment(ContentManager.self) private var contentManager
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(selectedItems) { decorator in
                        UniversalItemView(item: decorator)
                            .id(decorator.id)
                    }
                }
            }
            .onChange(of: contentManager.focusedItemId) { _, newValue in
                if let id = newValue {
                    // Use default macOS scroll behavior (only scroll if item is out of view)
                    proxy.scrollTo(id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
