import SwiftUI

/// 책장과 달력에서 함께 쓰는 통합 검색 화면입니다.
/// 제목·작가·감상문뿐 아니라 연도와 월 표현도 감상 기록 날짜로 해석합니다.
struct UnifiedSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var selectedBook: Book?
    @State private var showingAddBook = false
    @State private var catalogQuery = ""

    private var searchSnapshot: UnifiedSearchSnapshot {
        UnifiedSearchSnapshot(query: debouncedQuery, store: store)
    }

    private var hasSearchTerm: Bool { searchSnapshot.hasSearchTerm }
    private var dateFilter: SearchDateFilter? { searchSnapshot.dateFilter }
    private var matchingEntries: [ReadingEntry] { searchSnapshot.matchingEntries }
    private var matchingBooks: [Book] { searchSnapshot.matchingBooks }
    private var entryMonthGroups: [SearchEntryMonthGroup] { searchSnapshot.entryMonthGroups }

    var body: some View {
        NavigationStack {
            List {
                if !hasSearchTerm {
                    Section {
                        SearchGuideRow(icon: "text.magnifyingglass", title: "책과 기록을 함께 찾아보세요", message: "책 제목, 작가 이름, 감상문 내용을 입력할 수 있어요.")
                        SearchGuideRow(icon: "calendar", title: "날짜로도 찾을 수 있어요", message: "예: 2026년 · 2026년 8월 · 8월")
                    }

                    Section {
                        Button {
                            showingAddBook = true
                        } label: {
                            Label("새 책 직접 등록", systemImage: "plus.circle")
                                .foregroundStyle(GgotgalpiTheme.ink)
                        }
                    }
                } else if matchingBooks.isEmpty && matchingEntries.isEmpty {
                    Section {
                        ReadingEmptyState(
                            title: "등록된 책과 기록에는 결과가 없어요",
                            message: "다른 제목, 감상문 문장, 또는 날짜로 찾아보세요."
                        )
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        Button {
                            showingAddBook = true
                        } label: {
                            Label("새 책 직접 등록", systemImage: "plus.circle")
                                .foregroundStyle(GgotgalpiTheme.ink)
                        }
                    }
                } else {
                    if !matchingBooks.isEmpty {
                        Section(dateFilter == nil ? "등록된 책" : "해당 기간에 읽은 책") {
                            ForEach(matchingBooks) { book in
                                Button {
                                    selectedBook = book
                                } label: {
                                    SearchBookRow(book: book, entryCount: store.entries(for: book.id).count)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !matchingEntries.isEmpty {
                        if case .month = dateFilter {
                            ForEach(entryMonthGroups) { group in
                                Section(group.title) {
                                    searchEntryRows(group.entries)
                                }
                            }
                        } else {
                            Section("감상 기록") {
                                searchEntryRows(matchingEntries)
                            }
                        }
                    }
                }
                if !catalogQuery.isEmpty {
                    Section { UnifiedCatalogResults(query: catalogQuery, onEntrySaved: { dismiss() }).id(catalogQuery) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("‘검색’을 누르면 검색어가 Cloudflare·카카오로 전달되어 온라인 도서도 찾아요.")
                    .font(.doveMayo(.caption)).padding(8).background(GgotgalpiTheme.paper)
            }
            .scrollContentBackground(.hidden)
            .background(GgotgalpiTheme.paper)
            .navigationTitle("통합 검색")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "책, 감상문, 연도 또는 월 검색")
            .onSubmit(of: .search) { catalogQuery = query.trimmingCharacters(in: .whitespacesAndNewlines) }
            .onChange(of: query) { _, _ in catalogQuery = "" }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                }
            }
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
        }
        .paperBackground()
        .task(id: query) {
            await updateDebouncedQuery(for: query)
        }
    }

    private func updateDebouncedQuery(for query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            debouncedQuery = ""
            return
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }
        debouncedQuery = query
    }

    @ViewBuilder
    private func searchEntryRows(_ entries: [ReadingEntry]) -> some View {
        ForEach(entries) { entry in
            if let book = store.book(for: entry.bookID) {
                Button {
                    selectedBook = book
                } label: {
                    SearchEntryRow(book: book, entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 검색어를 화면과 무관하게 해석해 책·감상 기록 결과를 공유합니다.
@MainActor
private struct UnifiedSearchSnapshot {
    let hasSearchTerm: Bool
    let dateFilter: SearchDateFilter?
    let matchingEntries: [ReadingEntry]
    let matchingBooks: [Book]
    let entryMonthGroups: [SearchEntryMonthGroup]

    init(
        query: String,
        store: DemoStore,
        bookMatchesFilter: (Book) -> Bool = { _ in true }
    ) {
        let calendar = Calendar.current
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dateFilter = Self.makeDateFilter(from: normalizedQuery)
        let textQuery = Self.makeTextQuery(from: normalizedQuery, dateFilter: dateFilter)
        let compactTextQuery = textQuery.removingWhitespaceAndNewlines

        func matchesSearchText(_ searchableText: String) -> Bool {
            searchableText.localizedCaseInsensitiveContains(textQuery)
                || searchableText.removingWhitespaceAndNewlines.localizedCaseInsensitiveContains(compactTextQuery)
        }

        func matches(book: Book) -> Bool {
            guard !textQuery.isEmpty else { return dateFilter != nil }
            let searchableText = [book.title, book.author, book.publisher, book.isbn, book.category.rawValue, book.readingStatus.rawValue]
                .joined(separator: " ")
            return matchesSearchText(searchableText)
        }

        func matches(entry: ReadingEntry) -> Bool {
            guard let book = store.book(for: entry.bookID) else { return false }
            guard bookMatchesFilter(book) else { return false }
            guard !textQuery.isEmpty else { return true }
            let searchableText = [book.title, book.author, entry.note, entry.favoriteSentence]
                .joined(separator: " ")
            return matchesSearchText(searchableText)
        }

        let matchingEntries = store.entries
            .filter { entry in
                let matchesDate = dateFilter.map { $0.matches(entry.date, calendar: calendar) } ?? true
                return matchesDate && matches(entry: entry)
            }
            .sorted { $0.date > $1.date }

        let matchingBooks: [Book]
        if dateFilter != nil {
            let bookIDs = Set(matchingEntries.map(\.bookID))
            matchingBooks = store.books.filter { bookIDs.contains($0.id) && bookMatchesFilter($0) }
        } else {
            matchingBooks = store.books.filter { bookMatchesFilter($0) && matches(book: $0) }
        }

        let groupedEntries = Dictionary(grouping: matchingEntries) { entry in
            calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date)) ?? entry.date
        }

        self.hasSearchTerm = !normalizedQuery.isEmpty
        self.dateFilter = dateFilter
        self.matchingEntries = matchingEntries
        self.matchingBooks = matchingBooks
        self.entryMonthGroups = groupedEntries
            .map { SearchEntryMonthGroup(month: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.month > $1.month }
    }

    private static func makeDateFilter(from normalizedQuery: String) -> SearchDateFilter? {
        let numbers = normalizedQuery
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }

        let year = numbers.first(where: { (1000...9999).contains($0) })
        let month = numbers.last(where: { (1...12).contains($0) })

        if normalizedQuery.contains("년") {
            guard let year else { return nil }
            if normalizedQuery.contains("월"), let month {
                return .yearMonth(year: year, month: month)
            }
            return .year(year)
        }

        if normalizedQuery.contains("월"), let month {
            return year.map { .yearMonth(year: $0, month: month) } ?? .month(month)
        }

        if normalizedQuery.count == 4, let year, numbers.count == 1 {
            return .year(year)
        }

        return nil
    }

    private static func makeTextQuery(from normalizedQuery: String, dateFilter: SearchDateFilter?) -> String {
        guard dateFilter != nil else { return normalizedQuery }

        let numbers = normalizedQuery
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }

        return numbers.reduce(
            normalizedQuery.replacingOccurrences(of: "년", with: " ")
                .replacingOccurrences(of: "월", with: " ")
        ) { partial, number in
            partial.replacingOccurrences(of: String(number), with: " ")
        }
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 달력 화면 안에 표시하는 통합 검색 결과입니다.
struct InlineUnifiedSearchView: View {
    @EnvironmentObject private var store: DemoStore
    @Binding var query: String
    var catalogQuery: String
    private let onEntrySaved: () -> Void
    private let bookMatchesFilter: (Book) -> Bool
    @State private var selectedBook: Book?
    @State private var showingAddBook = false
    @State private var debouncedQuery = ""

    init(
        query: Binding<String>,
        catalogQuery: String = "",
        onEntrySaved: @escaping () -> Void = {},
        bookMatchesFilter: @escaping (Book) -> Bool = { _ in true }
    ) {
        _query = query
        self.catalogQuery = catalogQuery
        self.onEntrySaved = onEntrySaved
        self.bookMatchesFilter = bookMatchesFilter
    }

    private var snapshot: UnifiedSearchSnapshot {
        UnifiedSearchSnapshot(
            query: debouncedQuery,
            store: store,
            bookMatchesFilter: bookMatchesFilter
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.section) {
            if !snapshot.hasSearchTerm {
                VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.control) {
                    SearchGuideRow(
                        icon: "text.magnifyingglass",
                        title: "책과 기록을 함께 찾아보세요",
                        message: "책 제목, 작가 이름, 감상문 내용을 입력할 수 있어요."
                    )
                    SearchGuideRow(
                        icon: "calendar",
                        title: "날짜로도 찾을 수 있어요",
                        message: "예: 2026년 · 2026년 8월 · 8월"
                    )
                }

                addBookButton
            } else if snapshot.matchingBooks.isEmpty && snapshot.matchingEntries.isEmpty {
                ReadingEmptyState(
                    title: "등록된 책과 기록에는 결과가 없어요",
                    message: "다른 제목, 감상문 문장, 또는 날짜로 찾아보세요."
                )
                addBookButton
            } else {
                if !snapshot.matchingBooks.isEmpty {
                    VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.control) {
                        Text(snapshot.dateFilter == nil ? "등록된 책" : "해당 기간에 읽은 책")
                            .font(.doveMayo(.headline, bold: true))
                            .foregroundStyle(GgotgalpiTheme.ink)

                        ForEach(snapshot.matchingBooks) { book in
                            Button {
                                selectedBook = book
                            } label: {
                                SearchBookRow(book: book, entryCount: store.entries(for: book.id).count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !snapshot.matchingEntries.isEmpty {
                    if case .month = snapshot.dateFilter {
                        ForEach(snapshot.entryMonthGroups) { group in
                            VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.control) {
                                Text(group.title)
                                    .font(.doveMayo(.headline, bold: true))
                                    .foregroundStyle(GgotgalpiTheme.ink)
                                searchEntryRows(group.entries)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.control) {
                            Text("감상 기록")
                                .font(.doveMayo(.headline, bold: true))
                                .foregroundStyle(GgotgalpiTheme.ink)
                            searchEntryRows(snapshot.matchingEntries)
                        }
                    }
                }
            }
            if !catalogQuery.isEmpty {
                UnifiedCatalogResults(query: catalogQuery, onEntrySaved: onEntrySaved).id(catalogQuery)
            } else {
                Text("키보드의 ‘검색’을 누르면 온라인 도서도 찾아요. 검색어는 Cloudflare·카카오로 전달돼요.")
                    .font(.doveMayo(.caption))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $selectedBook) { book in
            BookDetailView(book: book)
        }
        .sheet(isPresented: $showingAddBook) {
            AddBookView()
        }
        .task(id: query) {
            await updateDebouncedQuery(for: query)
        }
    }

    private var addBookButton: some View {
        Button {
            showingAddBook = true
        } label: {
            Label("새 책 직접 등록", systemImage: "plus.circle")
                .foregroundStyle(GgotgalpiTheme.ink)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func searchEntryRows(_ entries: [ReadingEntry]) -> some View {
        ForEach(entries) { entry in
            if let book = store.book(for: entry.bookID) {
                Button {
                    selectedBook = book
                } label: {
                    SearchEntryRow(book: book, entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func updateDebouncedQuery(for query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            debouncedQuery = ""
            return
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }
        debouncedQuery = query
    }
}

/// Explicitly submitted online searches stay separate from private journal filtering.
private struct UnifiedCatalogResults: View {
    @EnvironmentObject private var store: DemoStore
    let query: String
    let onEntrySaved: () -> Void
    @State private var didSaveEntry = false
    @State private var books: [CatalogBook] = []
    @State private var page = 1
    @State private var isEnd = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selection: CatalogBook?
    @State private var existingBook: Book?
    @State private var attempt = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("온라인 도서").font(.doveMayo(.headline, bold: true))
            ForEach(books) { book in
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        if let registered = registeredBook(for: book) {
                            existingBook = registered
                        } else {
                            selection = book
                        }
                    } label: {
                        HStack(spacing: 12) {
                            CatalogCover(url: book.coverURL)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title).font(.doveMayo(.headline, bold: true))
                                Text(book.authors.joined(separator: ", ")).font(.doveMayo(.subheadline))
                                Text(book.publisher).font(.doveMayo(.caption))
                                Text(registeredBook(for: book) == nil ? "내 책장에 추가" : "등록된 책 보기")
                                    .font(.doveMayo(.caption)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if let url = book.detailURL {
                        Link("Daum 책 정보 보기", destination: url).font(.doveMayo(.caption))
                    }
                }
            }
            if isLoading {
                ProgressView("책을 찾고 있어요")
            } else if let errorMessage {
                Text(errorMessage).font(.doveMayo(.subheadline)).foregroundStyle(.secondary)
                Button("다시 시도") { attempt += 1 }
            } else if books.isEmpty {
                Text("온라인에서 찾은 책이 없어요. 다른 제목이나 ISBN으로 검색해 주세요.")
                    .font(.doveMayo(.subheadline)).foregroundStyle(.secondary)
            } else if !isEnd {
                Button("더 보기") { page += 1 }
            }
            Text("도서 검색 제공: Kakao · Daum").font(.doveMayo(.caption)).foregroundStyle(.secondary)
        }
        .sheet(item: $selection, onDismiss: {
            guard didSaveEntry else { return }
            didSaveEntry = false
            onEntrySaved()
        }) { book in
            AddBookView(onEntrySaved: { didSaveEntry = true }, catalogBook: book)
        }
        .sheet(item: $existingBook) { book in BookDetailView(book: book) }
        .task(id: "\(page)-\(attempt)") { await load() }
    }

    private func registeredBook(for book: CatalogBook) -> Book? {
        let identifiers = Set(book.isbn.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        guard !identifiers.isEmpty else { return nil }
        return store.books.first {
            !identifiers.isDisjoint(with: $0.isbn.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            var components = URLComponents(string: "https://ggotgalpi-book-search.rinarocketpunch.workers.dev/books")!
            components.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "page", value: String(page))]
            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard http.statusCode == 200 else {
                errorMessage = http.statusCode == 429
                    ? "검색 요청이 많아요. 잠시 후 다시 시도해 주세요."
                    : "지금은 온라인 검색을 이용할 수 없어요. 기존 책과 기록 검색은 계속 이용할 수 있어요."
                return
            }
            let result = try JSONDecoder().decode(CatalogPage.self, from: data)
            var seen = Set(books.map(\.id))
            books.append(contentsOf: result.books.filter { seen.insert($0.id).inserted })
            isEnd = result.isEnd || page >= 50
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "온라인 도서를 가져오지 못했어요. 인터넷 연결을 확인해 주세요. 기존 기록은 계속 검색할 수 있어요."
        }
    }
}

private extension String {
    var removingWhitespaceAndNewlines: String {
        unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .map(String.init)
            .joined()
    }
}

private enum SearchDateFilter: Equatable {
    case year(Int)
    case yearMonth(year: Int, month: Int)
    case month(Int)

    func matches(_ date: Date, calendar: Calendar) -> Bool {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        switch self {
        case .year(let targetYear):
            return year == targetYear
        case .yearMonth(let targetYear, let targetMonth):
            return year == targetYear && month == targetMonth
        case .month(let targetMonth):
            return month == targetMonth
        }
    }
}

private struct SearchEntryMonthGroup: Identifiable {
    let month: Date
    let entries: [ReadingEntry]

    var id: Date { month }

    var title: String {
        month.formatted(.dateTime.year().month().locale(Locale(identifier: "ko_KR")))
    }
}

private struct SearchGuideRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(GgotgalpiTheme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.doveMayo(.subheadline, bold: true))
                    .foregroundStyle(GgotgalpiTheme.ink)
                Text(message)
                    .font(.doveMayo(.caption))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct SearchBookRow: View {
    let book: Book
    let entryCount: Int

    var body: some View {
        HStack(spacing: 12) {
            BookColorMark(title: book.title, color: book.coverColor, size: 44, coverURL: book.coverURL)
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.doveMayo(.headline, bold: true))
                    .foregroundStyle(GgotgalpiTheme.ink)
                Text(book.author)
                    .font(.doveMayo(.subheadline))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
                Text("감상 \(entryCount)개 · \(book.category.rawValue)")
                    .font(.doveMayo(.caption))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.doveMayo(.caption, bold: true))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
        }
        .contentShape(Rectangle())
    }
}

private struct SearchEntryRow: View {
    let book: Book
    let entry: ReadingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                BookColorMark(title: book.title, color: book.coverColor, size: 40, coverURL: book.coverURL)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(book.title)
                            .font(.doveMayo(.subheadline, bold: true))
                            .foregroundStyle(GgotgalpiTheme.ink)
                        Spacer()
                        Text(entry.date.shortKoreanDate)
                            .font(.doveMayo(.caption))
                            .foregroundStyle(GgotgalpiTheme.secondaryInk)
                    }
                    Text("p.\(entry.pageFrom)-\(entry.pageTo) · \(entry.readingRound)회독")
                        .font(.doveMayo(.caption))
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                    Text(entry.note)
                        .font(.doveMayo(size: 16))
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                        .lineLimit(2)

                    if !entry.favoriteSentence.isEmpty {
                        Text("“\(entry.favoriteSentence)”")
                            .font(.doveMayo(size: 14, bold: true))
                            .foregroundStyle(GgotgalpiTheme.ink)
                            .italic()
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
