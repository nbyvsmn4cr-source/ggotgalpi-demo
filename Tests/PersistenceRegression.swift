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
        let book = store.addBook(title: "테스트 책", author: "테스트 작가", category: .literature,
                                 isbn: "9788996991342", coverURL: "https://example.com/cover.jpg")
        let chosenDate = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        store.addEntry(bookID: book.id, date: chosenDate, pageFrom: 1, pageTo: 20,
            note: "영구 저장 확인 English text", favoriteSentence: "기억할 문장", readingRound: 1, rating: 0.5, readingMinutes: 45)
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
        precondition(store.entries[0].readingMinutes == 45)
        store.updateEntry(id: entryID, date: chosenDate, pageFrom: 1, pageTo: 20,
                          note: "영구 저장 확인 English text", readingRound: 1, rating: 0.5)
        precondition(store.entries[0].readingMinutes == 45, "Disabled time editing must preserve saved time")
        let startedAt = chosenDate.addingTimeInterval(23 * 3600)
        let endedAt = startedAt.addingTimeInterval(90 * 60)
        store.updateEntry(id: entryID, date: chosenDate, pageFrom: 1, pageTo: 20,
                          note: "영구 저장 확인 English text", readingRound: 1, rating: 0.5,
                          readingMinutes: 90, readingStartedAt: startedAt,
                          readingEndedAt: endedAt, updatesReadingTime: true)
        store.updateEntry(id: entryID, date: chosenDate, pageFrom: 1, pageTo: 20,
                          note: "영구 저장 확인 English text", readingRound: 1, rating: 0.5)
        precondition(store.entries[0].readingStartedAt == startedAt)
        precondition(store.entries[0].readingEndedAt == endedAt)
        // Trashing clears the representative flag; set it again before testing replacement.
        if !store.entries[0].isFavoriteReview { store.toggleFavoriteReview(id: entryID) }
        store.updateBook(id: book.id, title: "온라인 책 정보", author: "온라인 작가", publisher: "출판사",
                         category: book.category, readingStatus: book.readingStatus,
                         isHiddenFromCalendar: book.isHiddenFromCalendar,
                         isbn: "9780000000002", coverURL: "https://example.com/replaced.jpg")
        precondition(store.storageError == nil)
        precondition(store.books.count == 1 && store.entries[0].id == entryID)
        precondition(store.entries[0].isFavoriteReview && store.entries[0].date == chosenDate)
        // Ordinary manual edits must not clear the linked catalog metadata.
        store.updateBook(id: book.id, title: "수정한 제목", author: book.author, publisher: book.publisher,
                         category: book.category, readingStatus: book.readingStatus,
                         isHiddenFromCalendar: book.isHiddenFromCalendar)
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let reloaded = DemoStore(modelContext: reopened.mainContext)
        precondition(reloaded.books.count == 1 && reloaded.entries.count == 1)
        precondition(reloaded.books[0].title == "수정한 제목")
        precondition(reloaded.books[0].isbn == "9780000000002")
        precondition(reloaded.books[0].coverURL == "https://example.com/replaced.jpg")
        precondition(reloaded.entries[0].note == "영구 저장 확인 English text")
        precondition(reloaded.entries[0].readingMinutes == 90)
        precondition(reloaded.entries[0].readingStartedAt == startedAt)
        precondition(reloaded.entries[0].readingEndedAt == endedAt)
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
        let original = store.addBook(title: "인간 실격", author: "다자이 오사무", category: .literature, isbn: "9788937461033")
        let reused = store.addBook(title: "인간실격", author: "다자이오사무", category: .literature, isbn: "893746103X 9788937461033")
        precondition(original.id == reused.id && store.books.count == 1)
        let manual = Book(title: "인간실격", author: "다자이 오사무", category: .literature)
        let duplicate = Book(title: "인간 실격", author: "다자이 오사무", category: .literature)
        duplicate.isbn = "9788937461033"
        container.mainContext.insert(manual)
        container.mainContext.insert(duplicate)
        let active = ReadingEntry(book: manual, date: chosenDate, pageFrom: 1, pageTo: 10,
                                  note: "합치기 보존", favoriteSentence: "문장", readingRound: 2, rating: 4.5,
                                  readingMinutes: 90, readingStartedAt: startedAt, readingEndedAt: endedAt)
        active.isFavoriteReview = true
        let trashed = ReadingEntry(book: duplicate, date: chosenDate, pageFrom: 11, pageTo: 20,
                                   note: "휴지통 보존", readingRound: 2, deletedAt: Date())
        container.mainContext.insert(active)
        container.mainContext.insert(trashed)
        try container.mainContext.save()
        store.mergeDuplicateBooks()
        precondition(store.storageError == nil && store.books.count == 1)
        precondition(store.entries.count == 1 && store.trashedEntries.count == 1)
        precondition(active.bookID == store.books[0].id && trashed.bookID == store.books[0].id)
        precondition(active.note == "합치기 보존" && active.isFavoriteReview && active.ratingValue == 4.5)
        precondition(active.readingStartedAt == startedAt && active.readingEndedAt == endedAt)
        store.mergeDuplicateBooks()
        precondition(store.books.count == 1 && store.entries.count == 1)
        let mergedContainer = try ModelContainer(for: schema, configurations: [configuration])
        let mergedStore = DemoStore(modelContext: mergedContainer.mainContext)
        precondition(mergedStore.entries.count == 1 && mergedStore.trashedEntries.count == 1)
        precondition(mergedStore.entries[0].book?.id == mergedStore.books[0].id)
        let otherEdition = store.addBook(title: "인간 실격", author: "다자이 오사무", category: .literature, isbn: "9780000000002")
        precondition(otherEdition.id != store.books[0].id || store.books.count == 2)
        precondition(store.books.count == 2)
        precondition(store.matchingBook(title: "인간실격", author: "다자이오사무", isbn: "") == nil,
                     "Ambiguous editions must not be merged by title")
        print("PASS: empty install, selected date, half-star, favorite, trash/restore, disk reload, expiry, cascade, no reseeding")
        print("Temporary test store: \(directory.path)")
    }
}
