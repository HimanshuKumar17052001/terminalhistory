import Foundation
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    static let shared = LoginItemController()
    @Published var enabled: Bool = false
    private let service = SMAppService.mainApp

    private init() { refresh() }

    func refresh() {
        enabled = (service.status == .enabled)
    }

    func setEnabled(_ on: Bool) {
        do {
            if on { try service.register() } else { try service.unregister() }
        } catch {
            FileHandle.standardError.write(Data("login item: \(error)\n".utf8))
        }
        refresh()
    }
}
