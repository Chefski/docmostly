import SwiftUI

struct PageBrowserScopeSwitch: View {
    @Bindable var viewModel: PageBrowserViewModel

    var body: some View {
        ScrollView(.horizontal) {
            Group {
                if #available(iOS 26.0, macOS 26.0, *) {
                    GlassEffectContainer(spacing: 8) {
                        PageBrowserScopePills(viewModel: viewModel)
                    }
                } else {
                    PageBrowserScopePills(viewModel: viewModel)
                }
            }
            .padding(.vertical, PageBrowserMetrics.scopeSwitchVerticalOverflowPadding)
        }
        .padding(.vertical, -PageBrowserMetrics.scopeSwitchVerticalOverflowPadding)
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
        Group {
            if #available(iOS 26.0, macOS 26.0, *) {
                Button(action: select) {
                    PageBrowserScopeLabel(scope: scope, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .glassEffect(glass, in: .capsule)
            } else {
                Button(action: select) {
                    PageBrowserScopeLabel(scope: scope, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .background(isSelected ? Color.black : Color.clear, in: .capsule)
                .background(.regularMaterial, in: .capsule)
                .overlay {
                    if isSelected {
                        Capsule()
                            .strokeBorder(.primary.opacity(0.18))
                    }
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var glass: Glass {
        if isSelected {
            .regular.tint(.black).interactive()
        } else {
            .regular.interactive()
        }
    }
}
