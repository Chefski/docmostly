import SwiftUI

struct PageBrowserScopeLabel: View {
    let scope: PageBrowserScope
    let isSelected: Bool

    var body: some View {
        Label(scope.title, systemImage: scope.systemImage)
            .font(.callout)
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(.capsule)
    }
}
