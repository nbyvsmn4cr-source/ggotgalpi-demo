import SwiftUI

struct BookshelfView: View {
    @EnvironmentObject private var store: DemoStore
    let searchResetID: Int
    let scrollToTopID: Int
    @State private var selectedReadingStatus: ReadingStatus = .all
    @State private var selectedCategory: BookCategory = .all
    @State private var isShowingFilters = false
    @State private var showingAddBook = false
    @State private var selectedBook: Book?
    @State private var isSearchExpanded = false
    @State private var searchQuery = ""
    @State private var selectedAuthorKey: String?
    @FocusState private var isSearchFieldFocused: Bool
    @AppStorage("ggotgalpi.settings.bookshelf-sort-order") private var bookshelfSortOrder = BookshelfSortOption.recentEntry.rawValue

    private var visibleBooks: [Book] {
        store.books
            .filter(matchesBookshelfFilters)
            .filter { selectedAuthorKey == nil || normalizedAuthor($0.author) == selectedAuthorKey }
            .sorted(by: sortBooks)
    }

    /// 메인 책장에는 최신 정렬 기준의 세 권만 미리 보여주고, 전체 목록은 '나의 책장'에서 확인합니다.
    private var bookshelfPreviewBooks: [Book] {
        Array(visibleBooks.prefix(3))
    }

    private var favoriteAuthors: [FavoriteAuthor] {
        Dictionary(grouping: store.books.filter { store.isFavoriteAuthor($0.author) }, by: { normalizedAuthor($0.author) })
            .compactMap { key, books in
                guard let author = books.first?.author else { return nil }
                return FavoriteAuthor(id: key, name: author, bookCount: books.count)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var selectedSortOption: BookshelfSortOption {
        BookshelfSortOption(rawValue: bookshelfSortOrder) ?? .recentEntry
    }

    private func sortBooks(_ first: Book, _ second: Book) -> Bool {
        switch selectedSortOption {
        case .recentEntry:
            let firstLatestEntry = store.entries(for: first.id).map(\.createdAt).max() ?? .distantPast
            let secondLatestEntry = store.entries(for: second.id).map(\.createdAt).max() ?? .distantPast
            if firstLatestEntry != secondLatestEntry {
                return firstLatestEntry > secondLatestEntry
            }
        case .title:
            break
        }

        return first.title.localizedStandardCompare(second.title) == .orderedAscending
    }

    private func matchesBookshelfFilters(_ book: Book) -> Bool {
        let matchesStatus = selectedReadingStatus == .all || book.readingStatus == selectedReadingStatus
        let matchesCategory = selectedCategory == .all || book.category == selectedCategory
        let matchesAuthor = selectedAuthorKey == nil || normalizedAuthor(book.author) == selectedAuthorKey
        return matchesStatus && matchesCategory && matchesAuthor
    }

    private func normalizedAuthor(_ author: String) -> String {
        author.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private var hasSearchTerm: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasActiveFilter: Bool {
        selectedReadingStatus != .all || selectedCategory != .all || selectedAuthorKey != nil
    }

    private var filterSummary: String {
        [
            selectedReadingStatus == .all ? nil : selectedReadingStatus.rawValue,
            selectedCategory == .all ? nil : selectedCategory.rawValue,
            favoriteAuthors.first(where: { $0.id == selectedAuthorKey })?.name
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.section) {
                        if isSearchExpanded {
                            InlineUnifiedSearchView(
                                query: $searchQuery,
                                bookMatchesFilter: matchesBookshelfFilters
                            )
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if !hasSearchTerm {
                            NavigationLink {
                                FavoriteSentencesView()
                            } label: {
                                FavoriteSentencesShortcut(
                                    sentenceCount: store.entries.filter { !$0.favoriteSentence.isEmpty }.count
                                )
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { closeSearch() })

                            NavigationLink {
                                AllBooksView()
                            } label: {
                                SectionPageLinkLabel(title: "나의 책장")
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { closeSearch() })

                            LazyVStack(spacing: 0) {
                                ForEach(bookshelfPreviewBooks) { book in
                                    Button {
                                        closeSearch()
                                        selectedBook = book
                                    } label: {
                                        BookCard(
                                            book: book,
                                            entryCount: store.entries(for: book.id).count,
                                            averageRating: store.averageRating(for: book.id)
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if book.id != bookshelfPreviewBooks.last?.id {
                                        DividerLine()
                                    }
                                }
                            }

                            NavigationLink {
                                FavoriteAuthorsView()
                            } label: {
                                SectionPageLinkLabel(title: "좋아하는 작가")
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { closeSearch() })

                            if favoriteAuthors.isEmpty {
                                Text("책 상세에서 작가 이름 옆 별을 눌러 좋아하는 작가를 모아보세요.")
                                    .font(.doveMayo(.subheadline))
                                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
                            } else {
                                ScrollView(.horizontal) {
                                    HStack(spacing: GgotgalpiTheme.Spacing.compact) {
                                        ForEach(favoriteAuthors) { author in
                                            Button {
                                                closeSearch()
                                                selectedAuthorKey = selectedAuthorKey == author.id ? nil : author.id
                                            } label: {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(author.name)
                                                        .font(.doveMayo(.subheadline, bold: true))
                                                    Text("책 \(author.bookCount)권")
                                                        .font(.doveMayo(.caption))
                                                }
                                                .foregroundStyle(GgotgalpiTheme.ink)
                                                .padding(.horizontal, GgotgalpiTheme.Spacing.content)
                                                .padding(.vertical, GgotgalpiTheme.Spacing.control)
                                                .background(selectedAuthorKey == author.id ? GgotgalpiTheme.favoriteAuthorSelected : GgotgalpiTheme.favoriteAuthorCard)
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .scrollIndicators(.hidden)
                            }
                        }
                    }
                    .id("bookshelf-scroll-top")
                    .padding(.horizontal, GgotgalpiTheme.Spacing.screen)
                    .padding(.vertical, GgotgalpiTheme.Spacing.content)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isSearchExpanded else { return }
                    closeSearch()
                }
                .onChange(of: scrollToTopID) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bookshelf-scroll-top", anchor: .top)
                    }
                }
                .scrollIndicators(.hidden)
                // 툴바 슬롯의 고정 폭을 쓰지 않고, 화면의 좌우 여백 안에서 검색창을 직접 배치합니다.
                .safeAreaPadding(.top, 40)
                .overlay(alignment: .top) {
                    bookshelfActions
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, GgotgalpiTheme.Spacing.screen)
                }
                .sheet(isPresented: $isShowingFilters) {
                    BookshelfFilterSheet(
                        selectedReadingStatus: $selectedReadingStatus,
                        selectedCategory: $selectedCategory
                    )
                    .presentationDetents([.medium])
                }
                .sheet(isPresented: $showingAddBook) {
                    AddBookView()
                }
                .sheet(item: $selectedBook) { book in
                    BookDetailView(book: book)
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        closeSearch()
                        showingAddBook = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.doveMayo(.title3, bold: true))
                            .foregroundStyle(GgotgalpiTheme.paper)
                            .frame(width: 52, height: 52)
                            .background(GgotgalpiTheme.accent)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                    }
                    .accessibilityLabel("새 책 등록")
                    // 하단 독의 오른쪽 빈 영역 바로 위에 떠 있도록 여백을 둡니다.
                    .padding(.trailing, GgotgalpiTheme.Spacing.screen)
                    .padding(.bottom, 76)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .paperBackground()
        .onChange(of: searchResetID) {
            closeSearch()
        }
    }

    private var bookshelfActions: some View {
        Group {
            if isSearchExpanded {
                HStack(spacing: 0) {
                    bookshelfSearchField
                        .layoutPriority(1)

                    bookshelfActionIcons
                }
                .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
            } else {
                HStack(spacing: GgotgalpiTheme.Spacing.compact) {
                    if hasActiveFilter {
                        Button {
                            isShowingFilters = true
                        } label: {
                            Text(filterSummary)
                                .font(.doveMayo(.caption, bold: true))
                                .lineLimit(1)
                                .padding(.leading, GgotgalpiTheme.Spacing.control)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("적용된 필터: \(filterSummary)")
                    }

                    bookshelfActionIcons
                }
                .frame(height: 40)
            }
        }
        .foregroundStyle(GgotgalpiTheme.ink)
        .liquidGlassCapsule()
        .animation(.easeInOut(duration: 0.24), value: isSearchExpanded)
    }

    private var bookshelfActionIcons: some View {
        HStack(spacing: GgotgalpiTheme.Spacing.compact) {
            if !store.trashedEntries.isEmpty {
                bookshelfTrashButton
            }
            bookshelfFilterButton
            bookshelfSearchButton
        }
    }

    private var bookshelfTrashButton: some View {
        NavigationLink {
            TrashView()
        } label: {
            Image(systemName: "trash")
                .font(.doveMayo(.body))
                .foregroundStyle(GgotgalpiTheme.ink)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { closeSearch() })
        .accessibilityLabel("휴지통")
        .accessibilityValue(store.trashedEntries.isEmpty ? "비어 있음" : "\(store.trashedEntries.count)개")
    }

    private var bookshelfFilterButton: some View {
        Button {
            closeSearch()
            isShowingFilters = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.doveMayo(.body))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("책장 필터")
    }

    private var bookshelfSearchButton: some View {
        Button {
            if isSearchExpanded {
                closeSearch()
            } else {
                openSearch()
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSearchExpanded ? "검색 닫기" : "통합 검색")
    }

    private var bookshelfSearchField: some View {
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
        isSearchFieldFocused = false
        withAnimation(.easeInOut(duration: 0.24)) {
            isSearchExpanded = false
        }
        searchQuery = ""
    }
}

private struct BookshelfFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedReadingStatus: ReadingStatus
    @Binding var selectedCategory: BookCategory

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.section) {
                Text("책장에 표시할 책을 골라 보세요.")
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

/// 달력 필터용 읽기 상태 탭입니다. 항목 사이의 세로선으로 선택지를 구분합니다.
struct ReadingStatusUnderlineTabs: View {
    @Binding var selection: ReadingStatus

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReadingStatus.allCases) { status in
                Button {
                    selection = status
                } label: {
                    Text(status.rawValue)
                        .font(.doveMayo(.subheadline, bold: selection == status))
                        .foregroundStyle(selection == status ? GgotgalpiTheme.ink : GgotgalpiTheme.secondaryInk)
                        .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("읽기 상태: \(status.rawValue)")
                .accessibilityAddTraits(selection == status ? .isSelected : [])

                if status != ReadingStatus.allCases.last {
                    Rectangle()
                        .fill(GgotgalpiTheme.line.opacity(0.7))
                        .frame(width: 0.7, height: 18)
                }
            }
        }
    }
}

/// 달력 필터용 장르 탭입니다. 읽기 상태 탭과 같은 세로 구분선 스타일을 사용합니다.
struct CalendarCategoryTabs: View {
    @Binding var selection: BookCategory

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BookCategory.allCases) { category in
                Button {
                    selection = category
                } label: {
                    Text(category.rawValue)
                        .font(.doveMayo(.subheadline, bold: selection == category))
                        .foregroundStyle(selection == category ? GgotgalpiTheme.ink : GgotgalpiTheme.secondaryInk)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("장르: \(category.rawValue)")
                .accessibilityAddTraits(selection == category ? .isSelected : [])

                if category != BookCategory.allCases.last {
                    Rectangle()
                        .fill(GgotgalpiTheme.line.opacity(0.7))
                        .frame(width: 0.7, height: 18)
                }
            }
        }
    }
}

struct CategoryPicker: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: BookCategory

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("분야: \(selection.rawValue)", selection: $selection) {
                ForEach(BookCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else {
            Picker("분야", selection: $selection) {
                ForEach(BookCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct FavoriteAuthor: Identifiable {
    let id: String
    let name: String
    let bookCount: Int
}

private struct SectionPageLinkLabel: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.doveMayo(.headline, bold: true))
                .foregroundStyle(GgotgalpiTheme.ink)
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

private struct AllBooksView: View {
    @EnvironmentObject private var store: DemoStore

    private var books: [Book] {
        store.books.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List(books) { book in
            NavigationLink {
                BookDetailView(book: book)
            } label: {
                BookCard(
                    book: book,
                    entryCount: store.entries(for: book.id).count,
                    averageRating: store.averageRating(for: book.id)
                )
            }
            .listRowBackground(GgotgalpiTheme.calendarCanvas)
        }
        .scrollContentBackground(.hidden)
        .background(GgotgalpiTheme.calendarCanvas)
        .navigationTitle("나의 책장")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FavoriteAuthorsView: View {
    @EnvironmentObject private var store: DemoStore

    private var authors: [FavoriteAuthor] {
        Dictionary(grouping: store.books.filter { store.isFavoriteAuthor($0.author) }, by: { normalizedAuthor($0.author) })
            .compactMap { key, books in
                guard let author = books.first?.author else { return nil }
                return FavoriteAuthor(id: key, name: author, bookCount: books.count)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            if authors.isEmpty {
                Text("책 상세에서 작가 이름 옆 별을 눌러 좋아하는 작가를 지정해 보세요.")
                    .font(.doveMayo(.subheadline))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
                    .listRowBackground(GgotgalpiTheme.calendarCanvas)
            } else {
                ForEach(authors) { author in
                    Section(author.name) {
                        ForEach(books(for: author)) { book in
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                BookCard(
                                    book: book,
                                    entryCount: store.entries(for: book.id).count,
                                    averageRating: store.averageRating(for: book.id)
                                )
                            }
                            .listRowBackground(GgotgalpiTheme.calendarCanvas)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(GgotgalpiTheme.calendarCanvas)
        .navigationTitle("좋아하는 작가")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func books(for author: FavoriteAuthor) -> [Book] {
        store.books
            .filter { normalizedAuthor($0.author) == author.id }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func normalizedAuthor(_ author: String) -> String {
        author.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct BookCard: View {
    let book: Book
    let entryCount: Int
    let averageRating: Double?

    var body: some View {
        HStack(spacing: GgotgalpiTheme.Spacing.control) {
            BookColorMark(title: book.title, color: book.coverColor, coverURL: book.coverURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.doveMayo(.headline, bold: true))
                    .foregroundStyle(GgotgalpiTheme.ink)

                Text(book.author)
                    .font(.doveMayo(.subheadline))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)

                HStack(spacing: 6) {
                    Text("감상 \(entryCount)개")

                    if let averageRating {
                        Label("평균 \(ReadingRating.label(for: averageRating))", systemImage: "star.fill")
                    }
                }
                .font(.doveMayo(.caption))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.doveMayo(.caption, bold: true))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
    }
}
