import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: DemoStore
    let searchResetID: Int
    let pastHighlightRefreshID: Int
    let scrollToTopID: Int
    var showsSearchAndFilterControls = true
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var selectedReadingStatus: ReadingStatus = .all
    @State private var selectedCategory: BookCategory = .all
    @State private var isShowingFilters = false
    @State private var reorderRequest: CalendarBookReorderRequest?
    @State private var dayEntriesRequest: CalendarDayEntriesRequest?
    @State private var recentEntryRequest: CalendarDayEntryEditRequest?
    @State private var isSearchExpanded = false
    @State private var searchQuery = ""
    @State private var catalogQuery = ""
    @FocusState private var isSearchFieldFocused: Bool

    private func matchesCalendarFilters(_ entry: ReadingEntry) -> Bool {
        guard let book = store.book(for: entry.bookID), !book.isHiddenFromCalendar else {
            return false
        }
        return matchesCalendarFilters(book)
    }

    private func matchesCalendarFilters(_ book: Book) -> Bool {
        guard !book.isHiddenFromCalendar else { return false }
        let matchesStatus = selectedReadingStatus == .all || book.readingStatus == selectedReadingStatus
        let matchesCategory = selectedCategory == .all || book.category == selectedCategory
        return matchesStatus && matchesCategory
    }

    private func entries(on date: Date) -> [ReadingEntry] {
        store.entries(on: date).filter(matchesCalendarFilters)
    }

    private func books(on date: Date) -> [Book] {
        let latestEntries = Dictionary(grouping: entries(on: date), by: \.bookID).compactMapValues { entries in
            entries.max { $0.createdAt < $1.createdAt }
        }
        let defaultOrder = latestEntries.values
            .sorted { $0.createdAt > $1.createdAt }
            .map(\.bookID)
        let orderedIDs = store.orderedBookIDs(for: date, defaultOrder: defaultOrder)
        return orderedIDs.compactMap(store.book(for:))
    }

    private var hasActiveFilter: Bool {
        selectedReadingStatus != .all || selectedCategory != .all
    }

    private var hasSearchTerm: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filterSummary: String {
        [
            selectedReadingStatus == .all ? nil : selectedReadingStatus.rawValue,
            selectedCategory == .all ? nil : selectedCategory.rawValue
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var monthlyEntries: [ReadingEntry] {
        store.entries.filter {
            Calendar.current.isDate($0.date, equalTo: displayedMonth, toGranularity: .month)
                && matchesCalendarFilters($0)
        }
    }

    private var mostRecentMonthlyEntry: ReadingEntry? {
        monthlyEntries.max { $0.createdAt < $1.createdAt }
    }

    private var lastYearMonth: Date {
        Calendar.current.date(byAdding: .year, value: -1, to: displayedMonth) ?? displayedMonth
    }

    private var lastYearMonthlyEntries: [ReadingEntry] {
        store.entries.filter {
            Calendar.current.isDate($0.date, equalTo: lastYearMonth, toGranularity: .month)
                && matchesCalendarFilters($0)
        }
    }

    private var lastYearMonthlyBooks: [Book] {
        let bookIDs = Set(lastYearMonthlyEntries.map(\.bookID))
        return store.books.filter { bookIDs.contains($0.id) }
    }

    private var isDisplayingCurrentMonth: Bool {
        Calendar.current.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.section) {
                        if isSearchExpanded {
                            InlineUnifiedSearchView(
                                query: $searchQuery,
                                catalogQuery: catalogQuery,
                                onEntrySaved: closeSearch,
                                bookMatchesFilter: matchesCalendarFilters
                            )
                                .transition(.opacity)
                        }

                        if !hasSearchTerm {
                            MonthlyCalendarGrid(
                                displayedMonth: $displayedMonth,
                                selectedDate: $selectedDate,
                                books: { books(on: $0) },
                                selectDate: { date in
                                    closeSearch()
                                    let selectedDay = Calendar.current.startOfDay(for: date)
                                    selectedDate = selectedDay
                                    dayEntriesRequest = CalendarDayEntriesRequest(date: selectedDay)
                                },
                                requestReorder: { date in
                                    closeSearch()
                                    let books = books(on: date)
                                    guard books.count > 1 else { return }
                                    reorderRequest = CalendarBookReorderRequest(date: date, books: books)
                                },
                                onInteraction: closeSearch
                            )

                            CalendarMonthlySummary(
                                entries: monthlyEntries,
                                latestEntry: mostRecentMonthlyEntry,
                                latestBook: mostRecentMonthlyEntry.flatMap { store.book(for: $0.bookID) },
                                lastYearMonth: lastYearMonth,
                                lastYearBooks: lastYearMonthlyBooks,
                                lastYearEntries: lastYearMonthlyEntries,
                                pastHighlightRefreshID: pastHighlightRefreshID,
                                openRecentEntry: { book, entry in
                                    closeSearch()
                                    recentEntryRequest = CalendarDayEntryEditRequest(book: book, entry: entry)
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GgotgalpiTheme.Spacing.screen)
                // 기존 내비게이션 바가 차지하던 높이를 유지해 상단 액션과 달력이 겹치지 않게 합니다.
                .padding(.top, GgotgalpiTheme.Spacing.control + GgotgalpiTheme.Spacing.largeSection + GgotgalpiTheme.Spacing.content + GgotgalpiTheme.Spacing.compact)
                // 하단 플로팅 독에 마지막 요약 항목이 가려지지 않도록 스크롤 여유를 둡니다.
                    .padding(.bottom, GgotgalpiTheme.Spacing.largeSection * 3)
                    // Include the search-bar clearance in the scroll target, otherwise
                    // scrollTo aligns the first guide row underneath the fixed search bar.
                    .id("calendar-scroll-top")
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isSearchExpanded else { return }
                    closeSearch()
                }
                .onChange(of: scrollToTopID) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("calendar-scroll-top", anchor: .top)
                    }
                }
                .onChange(of: isSearchExpanded) { _, expanded in
                    if expanded { proxy.scrollTo("calendar-scroll-top", anchor: .top) }
                }
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .top) {
                if showsSearchAndFilterControls {
                    calendarActions
                        // 확장된 캡슐은 이 여백 안의 전체 폭을 사용합니다.
                        // 따라서 leading / trailing 여백은 항상 동일합니다.
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, GgotgalpiTheme.Spacing.screen)
                }
            }
            .overlay(alignment: .topLeading) {
                if !isDisplayingCurrentMonth && !isSearchExpanded {
                    Button("오늘") {
                        let today = Calendar.current.startOfDay(for: Date())
                        selectedDate = today
                        displayedMonth = Calendar.current.startOfMonth(for: today)
                    }
                    .font(.doveMayo(.subheadline, bold: true))
                    .foregroundStyle(GgotgalpiTheme.ink)
                    .frame(height: 40)
                    .padding(.horizontal, GgotgalpiTheme.Spacing.control)
                    .background(GgotgalpiTheme.surface.opacity(0.82), in: Capsule())
                    .padding(.leading, GgotgalpiTheme.Spacing.screen)
                }
            }
        }
        // 책장과 같은 공통 배경을 사용해 안전 영역을 포함한 화면 전체의 색감을 맞춥니다.
        .paperBackground()
        .onChange(of: searchResetID) {
            closeSearch()
        }
        .onChange(of: showsSearchAndFilterControls) { _, showsControls in
            if !showsControls {
                closeSearch()
                isShowingFilters = false
            }
        }
        .sheet(item: $recentEntryRequest) { request in
            AddReadingEntryView(book: request.book, editingEntry: request.entry)
        }
        .sheet(item: $reorderRequest) { request in
            CalendarBookOrderEditor(date: request.date, books: request.books) { bookIDs in
                store.saveCalendarBookOrder(bookIDs, for: request.date)
            }
        }
        .sheet(isPresented: $isShowingFilters) {
            CalendarFilterSheet(
                selectedReadingStatus: $selectedReadingStatus,
                selectedCategory: $selectedCategory
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $dayEntriesRequest) { request in
            CalendarDayEntriesSheet(
                date: request.date,
                entriesForDate: { entries(on: request.date) },
                orderedBooks: books(on: request.date),
                saveOrder: { bookIDs in
                    store.saveCalendarBookOrder(bookIDs, for: request.date)
                }
            )
        }
    }

    private var calendarActions: some View {
        Group {
            if isSearchExpanded {
                HStack(spacing: 0) {
                    inlineSearchField
                        // 아이콘 영역만 고정하고, 입력 필드는 남은 폭 전체를 차지합니다.
                        .layoutPriority(1)

                    calendarActionIcons
                }
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            } else {
                HStack(spacing: GgotgalpiTheme.Spacing.compact) {
                    if hasActiveFilter {
                        Button {
                            isShowingFilters = true
                        } label: {
                            Text(filterSummary)
                                .font(.doveMayo(.caption, bold: true))
                                .lineLimit(1)
                                // 아이콘 버튼의 내부 여백과 맞춰, 선택된 필터도 캡슐 안에서 균형 있게 보이게 합니다.
                                .padding(.leading, GgotgalpiTheme.Spacing.control)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("적용된 필터: \(filterSummary)")
                    }

                    calendarActionIcons
                }
                .frame(height: 44)
            }
        }
        .foregroundStyle(GgotgalpiTheme.ink)
        .liquidGlassCapsule()
        .animation(.easeInOut(duration: 0.24), value: isSearchExpanded)
    }

    private var calendarActionIcons: some View {
        HStack(spacing: GgotgalpiTheme.Spacing.compact) {
            filterButton
            searchButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var filterButton: some View {
        Button {
            closeSearch()
            isShowingFilters = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.doveMayo(.body))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("달력 필터")
    }

    private var searchButton: some View {
        Button {
            if isSearchExpanded {
                closeSearch()
            } else {
                openSearch()
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.doveMayo(.body))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSearchExpanded ? "검색 닫기" : "통합 검색")
    }

    private var inlineSearchField: some View {
        HStack(spacing: 6) {
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.doveMayo(.caption))
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }

            TextField("책, 감상문, 연도 또는 월", text: $searchQuery)
                .onSubmit {
                    catalogQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    isSearchFieldFocused = false
                }
                // Keep the last submitted results while editing; typing never requests the API.
                .textFieldStyle(.plain)
                .font(.doveMayo(.subheadline))
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .frame(maxWidth: .infinity)

        }
        .padding(.horizontal, GgotgalpiTheme.Spacing.control)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .transition(.scale(scale: 0.1, anchor: .trailing).combined(with: .opacity))
    }

    private func openSearch() {
        withAnimation(.easeInOut(duration: 0.24)) {
            isSearchExpanded = true
        }
        isSearchFieldFocused = true
    }

    private func closeSearch() {
        catalogQuery = ""
        isSearchFieldFocused = false
        withAnimation(.easeInOut(duration: 0.24)) {
            isSearchExpanded = false
        }
        searchQuery = ""
    }
}

private struct CalendarMonthlySummary: View {
    let entries: [ReadingEntry]
    let latestEntry: ReadingEntry?
    let latestBook: Book?
    let lastYearMonth: Date
    let lastYearBooks: [Book]
    let lastYearEntries: [ReadingEntry]
    let pastHighlightRefreshID: Int
    let openRecentEntry: (Book, ReadingEntry) -> Void
    @State private var featuredLastYearBookID: UUID?
    @State private var selectedPastBook: Book?

    private var featuredLastYearFavoriteReview: ReadingEntry? {
        guard let featuredLastYearBook else { return nil }
        return featuredLastYearBook.entries?.first {
            $0.isFavoriteReview && $0.deletedAt == nil
        }
    }

    private var readBookCount: Int {
        Set(entries.map(\.bookID)).count
    }

    private var readPageCount: Int {
        entries.reduce(0) { $0 + max(0, $1.pageTo - $1.pageFrom + 1) }
    }

    private var featuredLastYearBook: Book? {
        if let featuredLastYearBookID,
           let book = lastYearBooks.first(where: { $0.id == featuredLastYearBookID }) {
            return book
        }
        return lastYearBooks.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.control) {
            Text("이번 달 요약")
                .font(.doveMayo(.headline, bold: true))
                .foregroundStyle(GgotgalpiTheme.ink)

            HStack(spacing: 0) {
                CalendarSummaryMetric(value: "\(readBookCount)권", title: "읽은 책")
                CalendarSummaryMetric(value: "\(entries.count)개", title: "감상 기록")
                CalendarSummaryMetric(value: "\(readPageCount)쪽", title: "읽은 페이지")
            }

            if let latestEntry, let latestBook {
                Divider()

                Button {
                    openRecentEntry(latestBook, latestEntry)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("최근 감상 · \(latestEntry.date.shortKoreanDate)")
                            .font(.doveMayo(.caption, bold: true))
                            .foregroundStyle(GgotgalpiTheme.secondaryInk)

                        Text(latestBook.title)
                            .font(.doveMayo(.subheadline, bold: true))
                            .foregroundStyle(GgotgalpiTheme.ink)

                        Text(latestEntry.note)
                            .font(.doveMayo(.caption))
                            .foregroundStyle(GgotgalpiTheme.secondaryInk)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("이 감상 기록을 확인하고 수정합니다")
            } else {
                Text("이번 달에 남긴 감상이 아직 없어요.")
                    .font(.doveMayo(.subheadline))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("지난 이맘때")
                    .font(.doveMayo(.headline, bold: true))
                    .foregroundStyle(GgotgalpiTheme.ink)

                if let featuredLastYearBook {
                    Button {
                        selectedPastBook = featuredLastYearBook
                    } label: {
                        HStack(spacing: 10) {
                            BookColorMark(
                                title: featuredLastYearBook.title,
                                color: featuredLastYearBook.coverColor,
                                size: 38,
                                coverURL: featuredLastYearBook.coverURL
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(featuredLastYearBook.title)
                                    .font(.doveMayo(.subheadline, bold: true))
                                    .foregroundStyle(GgotgalpiTheme.ink)

                                if featuredLastYearFavoriteReview == nil {
                                    Text(featuredLastYearBook.author)
                                        .font(.doveMayo(.caption))
                                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                                }

                                if let favoriteReview = featuredLastYearFavoriteReview {
                                    Label("가장 마음에 드는 감상문", systemImage: "heart.fill")
                                        .font(.doveMayo(.caption2, bold: true))
                                        .foregroundStyle(GgotgalpiTheme.accent)
                                        .padding(.top, 4)

                                    Text(favoriteReview.note)
                                        .font(.doveMayo(size: 13))
                                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("이 달에 읽은 책이 없어요.")
                        .font(.doveMayo(.subheadline))
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                }
            }
            .padding(.top, GgotgalpiTheme.Spacing.largeSection * 2)
        }
        .onAppear {
            selectFeaturedLastYearBook()
        }
        .onChange(of: lastYearBooks.map(\.id)) {
            selectFeaturedLastYearBook()
        }
        .onChange(of: pastHighlightRefreshID) {
            selectFeaturedLastYearBook(preferDifferentBook: true)
        }
        .sheet(item: $selectedPastBook) { book in
            CalendarPastReadingEntriesSheet(
                book: book,
                month: lastYearMonth,
                entries: lastYearEntries.filter { $0.bookID == book.id }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func selectFeaturedLastYearBook(preferDifferentBook: Bool = false) {
        let candidates = preferDifferentBook
            ? lastYearBooks.filter { $0.id != featuredLastYearBookID }
            : lastYearBooks
        featuredLastYearBookID = (candidates.isEmpty ? lastYearBooks : candidates).randomElement()?.id
    }
}

private struct CalendarPastReadingEntriesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let book: Book
    let month: Date
    let entries: [ReadingEntry]

    private var sortedEntries: [ReadingEntry] {
        entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.section) {
                    HStack(spacing: GgotgalpiTheme.Spacing.control) {
                        BookColorMark(title: book.title, color: book.coverColor, size: 52, coverURL: book.coverURL)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(book.title)
                                .font(.doveMayo(.headline, bold: true))
                                .foregroundStyle(GgotgalpiTheme.ink)
                            Text(book.author)
                                .font(.doveMayo(.subheadline))
                                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                        }
                    }

                    Text("\(month.formatted(.dateTime.year().month().locale(Locale(identifier: "ko_KR"))))에 남긴 감상")
                        .font(.doveMayo(.subheadline, bold: true))
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)

                    ForEach(sortedEntries) { entry in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(entry.date.formatted(.dateTime.month().day().weekday(.short).locale(Locale(identifier: "ko_KR"))))
                                .font(.doveMayo(.caption, bold: true))
                                .foregroundStyle(GgotgalpiTheme.secondaryInk)

                            Text(entry.note)
                                .font(.doveMayo(size: 17))
                                .foregroundStyle(GgotgalpiTheme.ink)

                            Text("p. \(entry.pageFrom)–\(entry.pageTo) · \(entry.readingRound)회독")
                                .font(.doveMayo(.caption))
                                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if entry.id != sortedEntries.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(GgotgalpiTheme.Spacing.screen)
            }
            .background(GgotgalpiTheme.paper)
            .navigationTitle("지난 이맘때의 감상")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

private struct CalendarSummaryMetric: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.doveMayo(.title3, bold: true))
                .foregroundStyle(GgotgalpiTheme.ink)
            Text(title)
                .font(.doveMayo(.caption2))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CalendarFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedReadingStatus: ReadingStatus
    @Binding var selectedCategory: BookCategory

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.section) {
                Text("달력에 표시할 감상을 골라 보세요.")
                    .font(.doveMayo(.subheadline))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)

                VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.compact) {
                    Text("읽은 상태")
                        .font(.doveMayo(.caption, bold: true))
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)

                    ReadingStatusUnderlineTabs(selection: $selectedReadingStatus)
                }

                VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.compact) {
                    Text("장르")
                        .font(.doveMayo(.caption, bold: true))
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)

                    CalendarCategoryTabs(selection: $selectedCategory)
                }

                Spacer()
            }
            .padding(.horizontal, GgotgalpiTheme.Spacing.screen)
            .padding(.top, GgotgalpiTheme.Spacing.content)
            .navigationTitle("필터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("초기화") {
                        selectedReadingStatus = .all
                        selectedCategory = .all
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .paperBackground()
    }
}

private struct CalendarBookReorderRequest: Identifiable {
    let date: Date
    let books: [Book]

    var id: Date { date }
}

private struct CalendarDayEntriesRequest: Identifiable {
    let date: Date

    var id: Date { date }
}

private struct CalendarDayEntriesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    @State private var books: [Book]
    @State private var editMode: EditMode = .inactive
    @State private var editingEntry: CalendarDayEntryEditRequest?
    @State private var editingBook: Book?
    @State private var showingBookSearch = false

    let date: Date
    let entriesForDate: () -> [ReadingEntry]
    let saveOrder: ([UUID]) -> Void

    init(
        date: Date,
        entriesForDate: @escaping () -> [ReadingEntry],
        orderedBooks: [Book],
        saveOrder: @escaping ([UUID]) -> Void
    ) {
        self.date = date
        self.entriesForDate = entriesForDate
        self.saveOrder = saveOrder
        _books = State(initialValue: orderedBooks)
    }

    private var entries: [ReadingEntry] {
        entriesForDate()
    }

    private var canReorder: Bool {
        books.count > 1
    }

    private func entries(for book: Book) -> [ReadingEntry] {
        entries
            .filter { $0.bookID == book.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ReadingEmptyState(
                        title: "아직 남긴 감상이 없어요",
                        message: "책장에서 작품을 고르고 이 날의 마음을 기록해 보세요."
                    )
                    .listRowBackground(GgotgalpiTheme.paper)
                } else {
                    if canReorder {
                        Section {
                            Text(editMode == .active
                                 ? "오른쪽 손잡이를 드래그해 순서를 정하세요. 맨 위 작품이 달력의 최전면 표지가 됩니다."
                                 : "감상문을 길게 눌러 작품 순서를 바꿀 수 있어요.")
                                .font(.doveMayo(.caption))
                                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                                .listRowBackground(GgotgalpiTheme.paperDeep.opacity(0.58))
                        }
                    }

                        Section {
                        ForEach(books) { book in
                            CalendarDayBookEntryRow(
                                book: book,
                                entries: entries(for: book),
                                editEntry: { entry in
                                    guard editMode != .active else { return }
                                    editingEntry = CalendarDayEntryEditRequest(book: book, entry: entry)
                                },
                                editBook: { book in
                                    guard editMode != .active else { return }
                                    editingBook = book
                                }
                            )
                                .contentShape(Rectangle())
                                .onLongPressGesture(minimumDuration: 0.45) {
                                    guard canReorder else { return }
                                    editMode = .active
                                }
                        }
                        .onMove { source, destination in
                            books.move(fromOffsets: source, toOffset: destination)
                            saveOrder(books.map(\.id))
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
            .background(GgotgalpiTheme.paper)
            .navigationTitle(date.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ko_KR"))))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if editMode == .active {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("정렬 완료") { editMode = .inactive }
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("닫기") { dismiss() }
                    }
                }
            }
            .sheet(item: $editingEntry) { request in
                AddReadingEntryView(book: request.book, editingEntry: request.entry)
            }
            .sheet(item: $editingBook) { book in
                EditBookView(book: book)
            }
            .sheet(isPresented: $showingBookSearch) {
                ContextualBookSearchView(title: "감상 기록할 책 찾기", initialEntryDate: date)
            }
            .onChange(of: entries.map(\.id)) {
                appendNewBooksForRecordedEntries()
            }
            .overlay(alignment: .bottomTrailing) {
                    Button {
                        editMode = .inactive
                        showingBookSearch = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.doveMayo(.title3, bold: true))
                            .foregroundStyle(GgotgalpiTheme.paper)
                            .frame(width: 52, height: 52)
                            .background(GgotgalpiTheme.accent)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                    }
                    .accessibilityLabel("이 날짜에 감상 기록 추가")
                    .padding(.trailing, GgotgalpiTheme.Spacing.screen)
                    .padding(.bottom, GgotgalpiTheme.Spacing.content)
            }
        }
        .paperBackground()
    }

    private func appendNewBooksForRecordedEntries() {
        let visibleBookIDs = Set(books.map(\.id))
        let newBooks = entries
            .compactMap { store.book(for: $0.bookID) }
            .filter { !visibleBookIDs.contains($0.id) }

        guard !newBooks.isEmpty else { return }
        books.append(contentsOf: newBooks)
    }
}

private struct CalendarDayEntryEditRequest: Identifiable {
    let book: Book
    let entry: ReadingEntry

    var id: UUID { entry.id }
}

private struct CalendarDayBookEntryRow: View {
    @EnvironmentObject private var store: DemoStore
    let book: Book
    let entries: [ReadingEntry]
    let editEntry: (ReadingEntry) -> Void
    let editBook: (Book) -> Void

    private var currentBook: Book {
        store.book(for: book.id) ?? book
    }

    var body: some View {
        HStack(alignment: .top, spacing: GgotgalpiTheme.Spacing.control) {
            Button {
                editBook(currentBook)
            } label: {
                BookColorMark(title: currentBook.title, color: currentBook.coverColor, size: 44, coverURL: currentBook.coverURL)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(currentBook.title) 책 정보 수정")

            VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.compact) {
                Button {
                    if let entry = entries.first {
                        editEntry(entry)
                    }
                } label: {
                    Text(currentBook.title)
                        .font(.doveMayo(.headline, bold: true))
                        .foregroundStyle(GgotgalpiTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(currentBook.title) 감상 기록 수정")

                ForEach(entries) { entry in
                    HStack(alignment: .top, spacing: GgotgalpiTheme.Spacing.compact) {
                        Button {
                            editEntry(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("p.\(entry.pageFrom)-\(entry.pageTo)")
                                        .font(.doveMayo(.caption))
                                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                                    Spacer()
                                    Text("\(entry.readingRound)회독")
                                        .font(.doveMayo(.caption))
                                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                                }

                                Text(entry.note)
                                    .font(.doveMayo(size: 17))
                                    .foregroundStyle(GgotgalpiTheme.ink)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("감상 기록 수정")

                        Button {
                            store.toggleFavoriteReview(id: entry.id)
                        } label: {
                            Image(systemName: entry.isFavoriteReview ? "heart.fill" : "heart")
                                .font(.doveMayo(.body))
                                .foregroundStyle(entry.isFavoriteReview ? GgotgalpiTheme.accent : GgotgalpiTheme.secondaryInk)
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(entry.isFavoriteReview ? "가장 마음에 드는 감상문 지정 해제" : "가장 마음에 드는 감상문으로 지정")
                    }

                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 표지·하트 등 자체 동작이 있는 요소는 유지하고, 카드의 빈 영역은 최신 감상 기록 편집으로 연결합니다.
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard let entry = entries.first else { return }
                    editEntry(entry)
                }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct MonthlyCalendarGrid: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let books: (Date) -> [Book]
    let selectDate: (Date) -> Void
    let requestReorder: (Date) -> Void
    let onInteraction: () -> Void
    @State private var isShowingMonthPicker = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    private var days: [Date?] {
        let firstDay = calendar.startOfMonth(for: displayedMonth)
        let leadingDays = calendar.component(.weekday, from: firstDay) - 1
        let numberOfDays = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 0
        let monthDays = (0..<numberOfDays).compactMap { calendar.date(byAdding: .day, value: $0, to: firstDay) }
        let cells = Array(repeating: nil as Date?, count: leadingDays) + monthDays
        let trailingDays = (7 - cells.count % 7) % 7
        return cells + Array(repeating: nil as Date?, count: trailingDays)
    }

    private var weekCount: Int {
        max(days.count / 7, 1)
    }

    private var calendarHeight: CGFloat {
        let weekdayHeight: CGFloat = 18
        let headerHeight: CGFloat = 44
        let cardInsets: CGFloat = 16
        return cardInsets + headerHeight + GgotgalpiTheme.Spacing.control + weekdayHeight + CGFloat(weekCount) * 66
    }

    var body: some View {
        GeometryReader { proxy in
            // 화면이 큰 경우에도 달력만 과도하게 길어지지 않도록 행 높이에 상한을 둡니다.
            let weekdayHeight: CGFloat = 18
            let headerHeight: CGFloat = 44
            let calendarCardInsets: CGFloat = 16
            let contentHeight = max(0, proxy.size.height - calendarCardInsets - headerHeight - GgotgalpiTheme.Spacing.control - weekdayHeight)
            let dayCellHeight = min(66, max(58, contentHeight / CGFloat(weekCount)))

            VStack(spacing: GgotgalpiTheme.Spacing.control) {
                HStack {
                    Button {
                        onInteraction()
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("이전 달")

                    Spacer()

                    Button {
                        onInteraction()
                        isShowingMonthPicker = true
                    } label: {
                        Text(monthTitle)
                            .font(.doveMayo(.headline, bold: true))
                            .foregroundStyle(GgotgalpiTheme.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(monthTitle), 연도와 월 선택")

                    Spacer()

                    Button {
                        onInteraction()
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("다음 달")
                }
                .foregroundStyle(GgotgalpiTheme.ink)
                .frame(height: headerHeight)

                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(weekdaySymbols.indices, id: \.self) { index in
                        Text(weekdaySymbols[index])
                            .font(.doveMayo(.caption, bold: true))
                            .foregroundStyle(GgotgalpiTheme.secondaryInk)
                            .frame(maxWidth: .infinity, minHeight: weekdayHeight)
                    }

                    ForEach(7..<(7 + days.count), id: \.self) { gridIndex in
                        let index = gridIndex - 7
                        let date = days[index]
                        CalendarDayCell(
                            date: date,
                            books: date.map(books) ?? [],
                            isSelected: date.map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false,
                            showsLeadingLine: index % 7 != 0,
                            showsTopLine: index >= 7,
                            select: selectDate,
                            requestReorder: requestReorder
                        )
                        .frame(height: dayCellHeight)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            // 달력 면에는 별도 색을 칠하지 않아 페이지의 흰 배경이 그대로 드러납니다.
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(height: calendarHeight)
        .sheet(isPresented: $isShowingMonthPicker) {
            CalendarMonthPicker(displayedMonth: $displayedMonth)
                .presentationDetents([.height(330)])
        }
    }

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        let year = (components.year ?? 0) % 100
        let month = components.month ?? 0
        return "\(year)년 \(month)월"
    }
}

private struct CalendarMonthPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var displayedMonth: Date
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var yearText: String
    @State private var monthText: String
    @State private var yearAnimationID = UUID()
    @State private var monthAnimationID = UUID()
    @State private var isAnimatingYear = false
    @State private var isAnimatingMonth = false

    private let calendar = Calendar.current

    init(displayedMonth: Binding<Date>) {
        self._displayedMonth = displayedMonth
        let components = Calendar.current.dateComponents([.year, .month], from: displayedMonth.wrappedValue)
        let year = components.year ?? Calendar.current.component(.year, from: Date())
        let month = components.month ?? 1
        self._selectedYear = State(initialValue: year)
        self._selectedMonth = State(initialValue: month)
        self._yearText = State(initialValue: String(year))
        self._monthText = State(initialValue: String(month))
    }

    private var availableYears: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        return Array((currentYear - 100)...(currentYear + 20))
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("연도", selection: $selectedYear) {
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year) + "년").tag(year)
                    }
                }
                .pickerStyle(.wheel)

                Picker("월", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(String(month) + "월").tag(month)
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(.horizontal, GgotgalpiTheme.Spacing.screen)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedYear) {
                if !isAnimatingYear {
                    yearText = String(selectedYear)
                }
            }
            .onChange(of: selectedMonth) {
                if !isAnimatingMonth {
                    monthText = String(selectedMonth)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 2) {
                        TextField("연도", text: $yearText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 46)
                            .onChange(of: yearText) {
                                if let year = Int(yearText), availableYears.contains(year) {
                                    scrollYear(to: year)
                                }
                            }

                        Text("년")

                        TextField("월", text: $monthText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 22)
                            .onChange(of: monthText) {
                                if let month = Int(monthText), (1...12).contains(month) {
                                    scrollMonth(to: month)
                                }
                            }

                        Text("월")
                    }
                    .font(.doveMayo(.headline, bold: true))
                    .foregroundStyle(GgotgalpiTheme.ink)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("이동") {
                        let components = DateComponents(year: selectedYear, month: selectedMonth, day: 1)
                        displayedMonth = calendar.date(from: components) ?? displayedMonth
                        dismiss()
                    }
                }
            }
        }
    }

    private func scrollYear(to target: Int) {
        guard selectedYear != target else { return }
        let animationID = UUID()
        yearAnimationID = animationID
        isAnimatingYear = true
        let stepDelay = UInt64(max(1, 200_000_000 / max(abs(target - selectedYear), 1)))

        Task { @MainActor in
            while selectedYear != target, yearAnimationID == animationID {
                try? await Task.sleep(nanoseconds: stepDelay)
                guard yearAnimationID == animationID else { return }
                selectedYear += selectedYear < target ? 1 : -1
            }

            guard yearAnimationID == animationID else { return }
            isAnimatingYear = false
            yearText = String(target)
        }
    }

    private func scrollMonth(to target: Int) {
        guard selectedMonth != target else { return }
        let animationID = UUID()
        monthAnimationID = animationID
        isAnimatingMonth = true
        let stepDelay = UInt64(max(1, 100_000_000 / max(abs(target - selectedMonth), 1)))

        Task { @MainActor in
            while selectedMonth != target, monthAnimationID == animationID {
                try? await Task.sleep(nanoseconds: stepDelay)
                guard monthAnimationID == animationID else { return }
                selectedMonth += selectedMonth < target ? 1 : -1
            }

            guard monthAnimationID == animationID else { return }
            isAnimatingMonth = false
            monthText = String(target)
        }
    }
}

private struct CalendarDayCell: View {
    let date: Date?
    let books: [Book]
    let isSelected: Bool
    let showsLeadingLine: Bool
    let showsTopLine: Bool
    let select: (Date) -> Void
    let requestReorder: (Date) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let date {
                if books.isEmpty {
                    GeometryReader { proxy in
                        Button {
                            select(date)
                        } label: {
                            Text(date.formatted(.dateTime.day()))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .contentShape(Rectangle())
                                // 보이는 날짜 숫자는 아래에 별도로 배치하고, 이 레이블은 넓은 탭 영역만 담당합니다.
                                .opacity(0.001)
                        }
                        .buttonStyle(.plain)
                        // 빈 날짜는 셀 중앙 기준 가로·세로 80%를 탭 영역으로 사용합니다.
                        .frame(width: proxy.size.width * 0.8, height: proxy.size.height * 0.8)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .accessibilityLabel(date.shortKoreanDate)

                        Text(date.formatted(.dateTime.day()))
                            .font(.doveMayo(.subheadline, bold: isSelected))
                            .foregroundStyle(GgotgalpiTheme.ink)
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                } else {
                    CalendarBookCoverStack(books: books, date: date, isSelected: isSelected)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            select(date)
                        }
                        .onLongPressGesture(minimumDuration: 0.55) {
                            if books.count > 1 {
                                requestReorder(date)
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .leading) {
            if showsLeadingLine {
                Rectangle()
                    .fill(GgotgalpiTheme.calendarGridLine)
                    .frame(width: 0.5)
            }
        }
        .overlay(alignment: .top) {
            if showsTopLine {
                Rectangle()
                    .fill(GgotgalpiTheme.calendarGridLine)
                    .frame(height: 0.5)
            }
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
