import SwiftUI

struct NotificationListControlsView: View {
    @Bindable var viewModel: NotificationListViewModel

    var body: some View {
        Section {
            Picker("Notification Type", selection: $viewModel.selectedType) {
                ForEach(NotificationListType.displayCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Picker("Show", selection: $viewModel.selectedFilter) {
                ForEach(NotificationFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
