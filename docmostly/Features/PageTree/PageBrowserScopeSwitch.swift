import SwiftUI

struct PageBrowserScopeSwitch: View {
    @Bindable var viewModel: PageBrowserViewModel

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                PageBrowserScopePills(viewModel: viewModel)
            }
            .padding(.vertical, PageBrowserMetrics.scopeSwitchVerticalOverflowPadding)
        }
        .padding(.vertical, -PageBrowserMetrics.scopeSwitchVerticalOverflowPadding)
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
    }
}

private struct PageBrowserScopePills: View {
    @Bindable var viewModel: PageBrowserViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PageBrowserScope.allCases) { scope in
                PageBrowserScopePill(
                    scope: scope,
                    isSelected: viewModel.selectedScope == scope
                ) {
                    viewModel.selectedScope = scope
                }
            }
        }
    }
}

private struct PageBrowserScopePill: View {
    let scope: PageBrowserScope
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            PageBrowserScopeLabel(scope: scope, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .glassEffect(glass, in: .capsule)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var glass: Glass {
        if isSelected {
            .regular.tint(.black).interactive()
        } else {
            .regular.interactive()
        }
    }
}
