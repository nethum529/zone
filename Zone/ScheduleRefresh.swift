import SwiftUI

struct ScheduleRefresh: ViewModifier {
    @Environment(ZoneStore.self) private var store

    func body(content: Content) -> some View {
        content.task(id: store.scheduleStore.nextBoundary) {
            guard let boundary = store.scheduleStore.nextBoundary else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, boundary.timeIntervalSinceNow)))
                try Task.checkCancellation()
                store.refresh()
            } catch { }
        }
    }
}
