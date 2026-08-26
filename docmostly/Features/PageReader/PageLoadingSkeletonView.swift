import SwiftUI

struct PageLoadingSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "Page title")
                .font(.largeTitle)
                .bold()

            Text(verbatim: "A short introduction to the page and the information it contains.")

            Text(verbatim: "Section heading")
                .font(.title2)
                .bold()
                .padding(.top)

            Text(
                verbatim: "The page continues with a few lines of useful content. "
                    + "This placeholder represents the body of the document while it is loading."
            )

            Text(verbatim: "Another paragraph provides more detail and gives the page a familiar document shape.")
                .padding(.top)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.secondary)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading page")
    }
}
