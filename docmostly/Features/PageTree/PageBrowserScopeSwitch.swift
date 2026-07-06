import SwiftUI

struct PageBrowserScopeSwitch: View {
    @Bindable var viewModel: PageBrowserViewModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                ForEach(PageBrowserScope.allCases) { scope in
                    Button {
                        viewModel.selectedScope = scope
                    } label: {
                        PageBrowserScopeLabel(
                            scope: scope,
                            isSelected: viewModel.selectedScope == scope
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(viewModel.selectedScope == scope ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
    }
}
