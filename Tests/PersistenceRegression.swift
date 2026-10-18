import Foundation
import SwiftData

// 독립 임시 저장소만 사용하며 앱/시뮬레이터의 사용자 데이터를 수정하지 않습니다.
@main
struct PersistenceRegression {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ggotgalpi-regression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema([Book.self, ReadingEntry.self])
        let configuration = ModelConfiguration(schema: schema,
            url: directory.appendingPathComponent("test.store"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = DemoStore(modelContext: container.mainContext)
        precondition(store.books.isEmpty && store.entries.isEmpty, "Fresh install must not seed demo records")
        let book = store.addBook(title: "테스트 책", author: "테스트 작가", category: .literature)
        let chosenDate = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        store.addEntry(bookID: book.id, date: chosenDate, pageFrom: 1, pageTo: 20,
            note: "영구 저장 확인", favoriteSentence: "기억할 문장", readingRound: 1, rating: 0.5)
        precondition(store.storageError == nil)
        let entryID = store.entries[0].id
        precondition(store.entries(on: chosenDate).count == 1)
        precondition(store.averageRating(for: book.id) == 0.5)
        store.toggleFavoriteReview(id: entryID)
        precondition(store.entries[0].isFavoriteReview)
        store.moveEntryToTrash(id: entryID)
        precondition(store.entries.isEmpty && store.trashedEntries.count == 1)
        precondition(store.averageRating(for: book.id) == nil)
        store.restoreEntry(id: entryID)
        precondition(store.entries.count == 1 && store.trashedEntries.isEmpty)
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let reloaded = DemoStore(modelContext: reopened.mainContext)
        precondition(reloaded.books.count == 1 && reloaded.entries.count == 1)
        precondition(reloaded.entries[0].note == "영구 저장 확인")
        precondition(reloaded.entries[0].ratingValue == 0.5)
        precondition(reloaded.entries[0].book?.id == book.id)
        store.moveEntryToTrash(id: entryID)
        let future = Calendar.current.date(byAdding: .day, value: 31, to: Date())!
        precondition(store.purgeExpiredEntries(referenceDate: future) == 1)
        precondition(store.trashedEntries.isEmpty)
        store.addEntry(bookID: book.id, date: chosenDate, pageFrom: 1, pageTo: 2,
            note: "cascade", readingRound: 0)
        store.deleteBook(id: book.id)
        precondition(store.books.isEmpty && store.entries.isEmpty)
        let empty = DemoStore(modelContext: container.mainContext)
        precondition(empty.books.isEmpty, "Deleted books must not reappear as sample data")
        print("PASS: empty install, selected date, half-star, favorite, trash/restore, disk reload, expiry, cascade, no reseeding")
        print("Temporary test store: \(directory.path)")
    }
}
