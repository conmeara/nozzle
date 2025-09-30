import SwiftUI

struct SelectedItemsView: View {
    let contextItems: [UniversalItemDecorator]
    let exampleItems: [UniversalItemDecorator]
    
    @Environment(ContentManager.self) private var contentManager
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !contextItems.isEmpty {
                        SectionHeader(title: "Context")
                        ForEach(contextItems) { decorator in
                            UniversalItemView(item: decorator)
                                .id(decorator.id)
                        }
                    }
                    if !contextItems.isEmpty && !exampleItems.isEmpty {
                        Divider()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                    }
                    if !exampleItems.isEmpty {
                        SectionHeader(title: "Examples")
                        ForEach(exampleItems) { decorator in
                            UniversalItemView(item: decorator)
                                .id(decorator.id)
                        }
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

private struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

