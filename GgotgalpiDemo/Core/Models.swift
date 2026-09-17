import Foundation
import SwiftData
import SwiftUI

enum BookCategory: String, CaseIterable, Identifiable {
    case all = "전체"
    case literature = "문학"
    case nonfiction = "비문학"
    case study = "학습"

    var id: String { rawValue }
}

enum ReadingStatus: String, CaseIterable, Identifiable {
    case all = "모두"
    case wantToRead = "보고 싶은"
    case finished = "읽은"
    case reading = "읽고 있는"

    var id: String { rawValue }
}

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var publisher: String
    private var categoryRawValue: String
    private var readingStatusRawValue: String
    private var coverColorIndex: Int
    var isHiddenFromCalendar: Bool
    @Relationship(deleteRule: .cascade, inverse: \ReadingEntry.book) var entries: [ReadingEntry] = []

    var category: BookCategory {
        get { BookCategory(rawValue: categoryRawValue) ?? .literature }
        set { categoryRawValue = newValue.rawValue }
    }

    var readingStatus: ReadingStatus {
        get { ReadingStatus(rawValue: readingStatusRawValue) ?? .wantToRead }
        set { readingStatusRawValue = newValue.rawValue }
    }

    var coverColor: Color {
        Self.coverColors[coverColorIndex % Self.coverColors.count]
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        publisher: String = "",
        category: BookCategory,
        readingStatus: ReadingStatus = .wantToRead,
        coverColorIndex: Int = 0,
        isHiddenFromCalendar: Bool = false
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.publisher = publisher
        self.categoryRawValue = category.rawValue
        self.readingStatusRawValue = readingStatus.rawValue
        self.coverColorIndex = coverColorIndex
        self.isHiddenFromCalendar = isHiddenFromCalendar
    }

    private static let coverColors: [Color] = [
        Color(red: 0.55, green: 0.65, blue: 0.61),
        Color(red: 0.66, green: 0.56, blue: 0.45),
        Color(red: 0.42, green: 0.48, blue: 0.58)
    ]
}

@Model
final class ReadingEntry {
    @Attribute(.unique) var id: UUID
    var bookID: UUID
    var date: Date
    var createdAt: Date
    var pageFrom: Int
    var pageTo: Int
    var note: String
    var favoriteSentence: String
    var readingRound: Int
    // 기존 정수 별점 필드는 유지해 저장된 기록을 그대로 읽습니다.
    var rating: Int = 0
    var hasHalfStar: Bool = false
    var deletedAt: Date?
    var book: Book?

    var ratingValue: Double {
        get { Double(rating) + (hasHalfStar ? 0.5 : 0) }
        set {
            let value = ReadingRating.normalized(newValue)
            rating = Int(value)
            hasHalfStar = value != Double(rating)
        }
    }

    init(
        id: UUID = UUID(),
        book: Book,
        date: Date,
        createdAt: Date = Date(),
        pageFrom: Int,
        pageTo: Int,
        note: String,
        favoriteSentence: String = "",
        readingRound: Int,
        rating: Double = 0,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.bookID = book.id
        self.book = book
        self.date = date
        self.createdAt = createdAt
        self.pageFrom = pageFrom
        self.pageTo = pageTo
        self.note = note
        self.favoriteSentence = favoriteSentence
        self.readingRound = readingRound
        self.deletedAt = deletedAt
        self.ratingValue = rating
    }
}

enum ReadingRating {
    /// 0은 미선택, 선택한 별점은 0.5~5점 사이의 0.5점 단위입니다.
    static func normalized(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return (min(5, max(0.5, value)) * 2).rounded() / 2
    }

    static func label(for value: Double) -> String {
        value == 0 ? "선택 안 함" : "\(value.formatted(.number.precision(.fractionLength(0...1))))점"
    }

    static func symbol(for value: Double, at position: Int) -> String {
        if value >= Double(position) { return "star.fill" }
        if value >= Double(position) - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

@MainActor
final class DemoStore: ObservableObject {
    static let trashRetentionDaysKey = "ggotgalpi.settings.trash-retention-days"
    static let defaultTrashRetentionDays = 30

    static var trashRetentionDays: Int {
        let selectedDays = UserDefaults.standard.integer(forKey: trashRetentionDaysKey)
        return [7, 14, 30].contains(selectedDays) ? selectedDays : defaultTrashRetentionDays
    }

    @Published private(set) var books: [Book] = []
    @Published private(set) var entries: [ReadingEntry] = []
    @Published private(set) var trashedEntries: [ReadingEntry] = []
    @Published private var calendarBookOrders: [String: [UUID]] = [:]

    private let modelContext: ModelContext
    private let calendarBookOrdersKey = "ggotgalpi.calendar-book-orders.v1"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCalendarBookOrders()
        refresh()
        purgeExpiredEntries()

        if books.isEmpty {
            seedSampleData()
        }
    }

    func book(for id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    func entries(for bookID: UUID) -> [ReadingEntry] {
        entries
            .filter { $0.bookID == bookID }
            .sorted { $0.date == $1.date ? $0.createdAt > $1.createdAt : $0.date > $1.date }
    }

    func entries(on date: Date) -> [ReadingEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func addBook(title: String, author: String, publisher: String = "", category: BookCategory) {
        let book = Book(
            title: title,
            author: author,
            publisher: publisher,
            category: category,
            coverColorIndex: books.count % 3
        )
        modelContext.insert(book)
        saveChanges()
    }

    func addEntry(
        bookID: UUID,
        date: Date,
        pageFrom: Int,
        pageTo: Int,
        note: String,
        favoriteSentence: String = "",
        readingRound: Int,
        rating: Double = 0
    ) {
        guard let book = book(for: bookID) else { return }
        modelContext.insert(
            ReadingEntry(
                book: book,
                date: date,
                pageFrom: pageFrom,
                pageTo: pageTo,
                note: note,
                favoriteSentence: favoriteSentence,
                readingRound: readingRound,
                rating: rating
            )
        )
        saveChanges()
    }

    func updateEntry(
        id: UUID,
        date: Date,
        pageFrom: Int,
        pageTo: Int,
        note: String,
        favoriteSentence: String = "",
        readingRound: Int,
        rating: Double = 0
    ) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        entry.date = date
        entry.pageFrom = pageFrom
        entry.pageTo = pageTo
        entry.note = note
        entry.favoriteSentence = favoriteSentence
        entry.readingRound = readingRound
        entry.ratingValue = rating
        saveChanges()
    }

    func moveEntryToTrash(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        entry.deletedAt = Date()
        saveChanges()
    }

    func restoreEntry(id: UUID) {
        guard let entry = trashedEntries.first(where: { $0.id == id }) else { return }
        entry.deletedAt = nil
        saveChanges()
    }

    func permanentlyDeleteEntry(id: UUID) {
        guard let entry = trashedEntries.first(where: { $0.id == id }) else { return }
        modelContext.delete(entry)
        saveChanges()
    }

    @discardableResult
    func purgeExpiredEntries(referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        guard let expirationThreshold = calendar.date(
            byAdding: .day,
            value: -Self.trashRetentionDays,
            to: referenceDate
        ) else { return 0 }

        do {
            let allEntries = try modelContext.fetch(FetchDescriptor<ReadingEntry>())
            let expiredEntries = allEntries.filter { entry in
                guard let deletedAt = entry.deletedAt else { return false }
                return deletedAt <= expirationThreshold
            }

            guard !expiredEntries.isEmpty else { return 0 }
            expiredEntries.forEach(modelContext.delete)
            try modelContext.save()
            refresh()
            return expiredEntries.count
        } catch {
            assertionFailure("만료된 휴지통 기록을 삭제하지 못했습니다: \(error.localizedDescription)")
            return 0
        }
    }

    func permanentDeletionDate(for entry: ReadingEntry) -> Date? {
        guard let deletedAt = entry.deletedAt else { return nil }
        return Calendar.current.date(
            byAdding: .day,
            value: Self.trashRetentionDays,
            to: deletedAt
        )
    }

    func daysUntilPermanentDeletion(for entry: ReadingEntry, referenceDate: Date = Date()) -> Int {
        guard let permanentDeletionDate = permanentDeletionDate(for: entry) else { return 0 }
        return max(
            0,
            Calendar.current.dateComponents(
                [.day],
                from: referenceDate,
                to: permanentDeletionDate
            ).day ?? 0
        )
    }

    func markBookAsFinished(id: UUID) {
        guard let book = book(for: id) else { return }
        book.readingStatus = .finished
        saveChanges()
    }

    func updateBook(
        id: UUID,
        title: String,
        author: String,
        publisher: String,
        category: BookCategory,
        readingStatus: ReadingStatus,
        isHiddenFromCalendar: Bool
    ) {
        guard let book = book(for: id) else { return }
        book.title = title
        book.author = author
        book.publisher = publisher
        book.category = category
        book.readingStatus = readingStatus
        book.isHiddenFromCalendar = isHiddenFromCalendar
        saveChanges()
    }

    func deleteBook(id: UUID) {
        guard let book = book(for: id) else { return }
        modelContext.delete(book)
        calendarBookOrders = calendarBookOrders.mapValues { $0.filter { $0 != id } }
        saveCalendarBookOrders()
        saveChanges()
    }

    func orderedBookIDs(for date: Date, defaultOrder: [UUID]) -> [UUID] {
        let dateKey = calendarDateKey(for: date)
        guard let savedOrder = calendarBookOrders[dateKey] else { return defaultOrder }

        let validSavedOrder = savedOrder.filter { defaultOrder.contains($0) }
        let newBookIDs = defaultOrder.filter { !validSavedOrder.contains($0) }
        return validSavedOrder + newBookIDs
    }

    func saveCalendarBookOrder(_ bookIDs: [UUID], for date: Date) {
        calendarBookOrders[calendarDateKey(for: date)] = bookIDs
        saveCalendarBookOrders()
    }

    private func refresh() {
        do {
            books = try modelContext.fetch(FetchDescriptor<Book>())
            let allEntries = try modelContext.fetch(FetchDescriptor<ReadingEntry>())
            entries = allEntries.filter { $0.deletedAt == nil }
            trashedEntries = allEntries
                .filter { $0.deletedAt != nil }
                .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
        } catch {
            assertionFailure("SwiftData 데이터를 불러오지 못했습니다: \(error.localizedDescription)")
            books = []
            entries = []
            trashedEntries = []
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
            refresh()
        } catch {
            assertionFailure("SwiftData 데이터를 저장하지 못했습니다: \(error.localizedDescription)")
        }
    }

    private func seedSampleData() {
        let littlePrince = Book(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "어린 왕자",
            author: "앙투안 드 생텍쥐페리",
            category: .literature,
            readingStatus: .reading,
            coverColorIndex: 0
        )
        let quietReading = Book(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "아주 작은 습관",
            author: "제임스 클리어",
            category: .nonfiction,
            readingStatus: .finished,
            coverColorIndex: 1
        )
        let notes = Book(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "생각의 지도",
            author: "리처드 니스벳",
            category: .study,
            coverColorIndex: 2,
            isHiddenFromCalendar: true
        )

        [littlePrince, quietReading, notes].forEach(modelContext.insert)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()
        let august3LastYear = calendar.date(from: DateComponents(year: 2025, month: 8, day: 3)) ?? today
        let august12LastYear = calendar.date(from: DateComponents(year: 2025, month: 8, day: 12)) ?? today
        let august23LastYear = calendar.date(from: DateComponents(year: 2025, month: 8, day: 23)) ?? today

        [
            ReadingEntry(book: littlePrince, date: today, createdAt: now.addingTimeInterval(-180), pageFrom: 1, pageTo: 34, note: "어른이 된다는 건 중요한 것을 잊는 일일까. 작은 별의 풍경이 오래 남았다.", favoriteSentence: "가장 중요한 것은 눈에 보이지 않아.", readingRound: 1),
            ReadingEntry(book: quietReading, date: today, createdAt: now, pageFrom: 24, pageTo: 58, note: "작은 행동을 반복하는 일이 결국 나를 만든다는 문장이 좋았다.", favoriteSentence: "매일 1퍼센트씩 나아지면 충분하다.", readingRound: 1),
            ReadingEntry(book: littlePrince, date: calendar.date(byAdding: .day, value: -5, to: today) ?? today, createdAt: now.addingTimeInterval(-14_400), pageFrom: 35, pageTo: 72, note: "길들인다는 것과 관계를 맺는다는 것에 대해 생각했다.", readingRound: 1),
            ReadingEntry(book: littlePrince, date: calendar.date(byAdding: .day, value: -7, to: today) ?? today, createdAt: now.addingTimeInterval(-28_800), pageFrom: 1, pageTo: 20, note: "두 번째로 읽으니 처음과 다른 문장이 보인다.", readingRound: 2),
            ReadingEntry(book: littlePrince, date: august3LastYear, createdAt: august3LastYear.addingTimeInterval(36_000), pageFrom: 73, pageTo: 104, note: "여름의 끝에서 다시 읽으니 여우의 말이 더 선명하게 다가왔다.", readingRound: 0),
            ReadingEntry(book: quietReading, date: august12LastYear, createdAt: august12LastYear.addingTimeInterval(36_000), pageFrom: 59, pageTo: 81, note: "작은 습관을 눈에 보이게 만드는 방법을 실천해 보기로 했다.", readingRound: 0),
            ReadingEntry(book: littlePrince, date: august23LastYear, createdAt: august23LastYear.addingTimeInterval(36_000), pageFrom: 105, pageTo: 128, note: "별을 바라보는 마음을 오래 기억하고 싶다는 감상을 남겼다.", readingRound: 0)
        ]
        .forEach(modelContext.insert)

        saveChanges()
    }

    private func saveCalendarBookOrders() {
        guard let encoded = try? JSONEncoder().encode(calendarBookOrders) else { return }
        UserDefaults.standard.set(encoded, forKey: calendarBookOrdersKey)
    }

    private func loadCalendarBookOrders() {
        guard
            let data = UserDefaults.standard.data(forKey: calendarBookOrdersKey),
            let savedOrders = try? JSONDecoder().decode([String: [UUID]].self, from: data)
        else { return }
        calendarBookOrders = savedOrders
    }

    private func calendarDateKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

extension Date {
    var shortKoreanDate: String {
        formatted(
            .dateTime
                .year()
                .month()
                .day()
                .locale(Locale(identifier: "ko_KR"))
        )
    }

    var koreanDateTime: String {
        formatted(
            .dateTime
                .year()
                .month()
                .day()
                .hour()
                .minute()
                .locale(Locale(identifier: "ko_KR"))
        )
    }
}
