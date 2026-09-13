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
    @FocusState private var isSearchFieldFocused: Bool
    @AppStorage("ggotgalpi.settings.bookshelf-sort-order") private var bookshelfSortOrder = BookshelfSortOption.recentEntry.rawValue
    @AppStorage("ggotgalpi.settings.show-favorite-sentences") private var showsFavoriteSentences = true

    private var visibleBooks: [Book] {
        store.books
            .filter(matchesBookshelfFilters)
            .sorted(by: sortBooks)
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
        return matchesStatus && matchesCategory
    }

    private var hasSearchTerm: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasActiveFilter: Bool {
        selectedReadingStatus != .all || selectedCategory != .all
    }

    private var filterSummary: String {
        [
            selectedReadingStatus == .all ? nil : selectedReadingStatus.rawValue,
            selectedCategory == .all ? nil : selectedCategory.rawValue
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
                            if showsFavoriteSentences {
                                NavigationLink {
                                    FavoriteSentencesView()
                                } label: {
                                    FavoriteSentencesShortcut(
                                        sentenceCount: store.entries.filter { !$0.favoriteSentence.isEmpty }.count
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            SectionLabel(title: "나의 책장")

                            LazyVStack(spacing: 0) {
                                ForEach(visibleBooks) { book in
                                    Button {
                                        selectedBook = book
                                    } label: {
                                        BookCard(book: book, entryCount: store.entries(for: book.id).count)
                                    }
                                    .buttonStyle(.plain)

                                    if book.id != visibleBooks.last?.id {
                                        DividerLine()
                                    }
                                }
                            }
                        }
                    }
                    .id("bookshelf-scroll-top")
                    .padding(.horizontal, GgotgalpiTheme.Spacing.screen)
                    .padding(.vertical, GgotgalpiTheme.Spacing.content)
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
                        showingAddBook = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
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
                                .font(.caption.weight(.medium))
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
                .font(.body)
                .foregroundStyle(GgotgalpiTheme.ink)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("휴지통")
        .accessibilityValue(store.trashedEntries.isEmpty ? "비어 있음" : "\(store.trashedEntries.count)개")
    }

    private var bookshelfFilterButton: some View {
        Button {
            isShowingFilters = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.body)
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
                        .font(.caption)
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }

            TextField("책, 감상문, 연도 또는 월", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.subheadline)
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
                    .font(.subheadline)
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)

                VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.compact) {
                    Text("읽은 상태")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)

                    ReadingStatusUnderlineTabs(selection: $selectedReadingStatus)
                }

                VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.compact) {
                    Text("장르")
                        .font(.caption.weight(.semibold))
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
                        .font(.subheadline.weight(selection == status ? .semibold : .regular))
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
                        .font(.subheadline.weight(selection == category ? .semibold : .regular))
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

struct BookCard: View {
    let book: Book
    let entryCount: Int

    var body: some View {
        HStack(spacing: GgotgalpiTheme.Spacing.control) {
            BookColorMark(title: book.title, color: book.coverColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .foregroundStyle(GgotgalpiTheme.ink)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)

                Text("감상 \(entryCount)개")
                    .font(.caption)
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
    }
}
