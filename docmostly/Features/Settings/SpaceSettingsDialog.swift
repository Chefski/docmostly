import SwiftUI

#if os(macOS)
struct SpaceSettingsDialog: View {
    let space: DocmostSpace

    var body: some View {
        NavigationStack {
            SpaceSettingsDestinationView(
                spaceID: space.id,
                showsCloseButton: true
            )
        }
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
