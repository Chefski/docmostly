import SwiftUI

struct NativeEditorColorMenu: View {
    let title: String
    let systemImage: String
    let options: [NativeEditorColorOption]
    let apply: (NativeEditorColorOption) -> Void

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    apply(option)
                } label: {
                    Label {
                        Text(option.name)
                    } icon: {
                        Circle()
                            .fill(option.color)
                    }
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .accessibilityLabel(title)
    }
}
