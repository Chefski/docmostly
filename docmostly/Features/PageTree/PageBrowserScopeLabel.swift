import SwiftUI

struct PageBrowserScopeLabel: View {
    let scope: PageBrowserScope
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Label(scope.title, systemImage: scope.systemImage)
                .font(.callout)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Capsule()
                .fill(isSelected ? Color.primary : Color.clear)
                .frame(height: 2)
        }
        .padding(.top, 6)
        .contentShape(.rect)
    }
}
