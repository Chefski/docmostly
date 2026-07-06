import SwiftUI

struct RecentPagesRailView: View {
    let items: [PageBrowserItem]
    let isLoading: Bool
    let errorMessage: String?
    let isOffline: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PageBrowserMetrics.railSectionSpacing) {
            Text(isOffline ? "Recent cached pages" : "Recently updated")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PageBrowserMetrics.railHorizontalPadding)

            if isLoading && items.isEmpty {
                ProgressView("Loading recent pages")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PageBrowserMetrics.railHorizontalPadding)
            } else if items.isEmpty {
                ContentUnavailableView("No Recently Updated Pages", systemImage: "clock")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PageBrowserMetrics.railHorizontalPadding)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: PageBrowserMetrics.railCardSpacing) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                RecentPageCardView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, PageBrowserMetrics.railHorizontalPadding)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
                    .padding(.horizontal, PageBrowserMetrics.railHorizontalPadding)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct RecentPageCardView: View {
    let item: PageBrowserItem

    var body: some View {
        DocmostlyGlassPanel(
            cornerRadius: PageBrowserMetrics.railCardCornerRadius,
            isInteractive: true
        ) {
            VStack(alignment: .leading, spacing: PageBrowserMetrics.railCardContentSpacing) {
                PageBrowserItemIcon(icon: item.icon)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let updatedAt = item.updatedAt {
                    Text(updatedAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(PageBrowserMetrics.railCardPadding)
            .frame(
                width: PageBrowserMetrics.railCardWidth,
                height: PageBrowserMetrics.railCardHeight,
                alignment: .leading
            )
        }
        .contentShape(.rect(cornerRadius: PageBrowserMetrics.railCardCornerRadius))
        .accessibilityLabel(item.title)
    }
}
