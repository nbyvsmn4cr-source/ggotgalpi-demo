import SwiftUI
import SwiftData

@main
struct GgotgalpiDemoApp: App {
    @StateObject private var persistence = AppPersistence()

    var body: some Scene {
        WindowGroup {
            if let container = persistence.container, let store = persistence.store {
                ContentView()
                    .environmentObject(store)
                    .modelContainer(container)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 20) {
                    Text("기록을 열지 못했어요").font(.headline)
                    Text("기존 기록을 삭제하거나 초기화하지 않았어요. 기기의 여유 공간을 확인한 후 다시 시도해 주세요.")
                    Button("다시 시도") { persistence.load() }
                    if let message = persistence.errorMessage {
                        ScrollView { Text(message).font(.caption).textSelection(.enabled) }
                            .frame(maxHeight: 150)
                    }
                }
                .padding(28)
            }
        }
    }
}

@MainActor
private final class AppPersistence: ObservableObject {
    @Published var container: ModelContainer?
    @Published var store: DemoStore?
    @Published var errorMessage: String?

    init() {
        load()
    }

    func load() {
        do {
            let schema = Schema([Book.self, ReadingEntry.self])
            let configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.dahli4.ggotgalpi")
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.container = container
            store = DemoStore(modelContext: container.mainContext)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
