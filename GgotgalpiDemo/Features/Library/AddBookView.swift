import SwiftUI

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    var onBookAdded: ((Book) -> Void)? = nil
    private let onEntrySaved: (() -> Void)?
    @State private var title = ""
    @State private var author = ""
    @State private var publisher = ""
    @State private var category: BookCategory = .literature
    @State private var showsSearch = false
    @State private var selectedResult: CatalogBook?
    @State private var bookForNewEntry: Book?
    @State private var showingInitialSearch: Bool

    init(onEntrySaved: (() -> Void)? = nil, onBookAdded: ((Book) -> Void)? = nil, catalogBook: CatalogBook? = nil, startsWithSearch: Bool = false) {
        self.onEntrySaved = onEntrySaved
        self.onBookAdded = onBookAdded
        _title = State(initialValue: catalogBook?.title ?? "")
        _author = State(initialValue: catalogBook?.authors.joined(separator: ", ") ?? "")
        _publisher = State(initialValue: catalogBook?.publisher ?? "")
        _selectedResult = State(initialValue: catalogBook)
        _showingInitialSearch = State(initialValue: startsWithSearch && catalogBook == nil)
    }

    var body: some View {
        Group {
            if let bookForNewEntry {
                AddReadingEntryView(book: bookForNewEntry, editingEntry: nil, onSaved: onEntrySaved)
            } else if showingInitialSearch {
                CatalogSearchView(dismissOnSelect: false, focusesSearchOnAppear: true, onManualEntry: {
                    showingInitialSearch = false
                }) { result in
                    title = result.title
                    author = result.authors.joined(separator: ", ")
                    publisher = result.publisher
                    selectedResult = result
                    showingInitialSearch = false
                }
            } else {
                bookForm
            }
        }
        .presentationDetents(bookForNewEntry == nil && !showingInitialSearch ? [.medium, .large] : [.large])
        .paperBackground()
    }

    private var bookForm: some View {
        NavigationStack {
            Form {
                StorageErrorSection()
                Section {
                    Button {
                        showsSearch = true
                    } label: {
                        Label("책 제목 · ISBN으로 검색", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    if let selectedResult {
                        HStack {
                            CatalogCover(url: selectedResult.coverURL)
                            Text("검색한 책 정보가 입력됐어요. 아래에서 수정할 수 있어요.")
                                .font(.doveMayo(.caption))
                            Spacer()
                            Button("해제") { self.selectedResult = nil }
                        }
                    }
                } footer: {
                    Text("검색하지 않고 직접 입력해도 돼요.")
                }
                Section {
                    TextField("책 제목", text: $title)
                    TextField("작가", text: $author)
                    TextField("출판사", text: $publisher)
                    Picker("분야", selection: $category) {
                        ForEach(BookCategory.allCases.filter { $0 != .all }) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                } header: {
                    Text("새 책")
                } footer: {
                    Text("책마다 구분 색상을 자동으로 지정합니다.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(GgotgalpiTheme.paper)
            .navigationTitle("책 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let book = store.addBook(title: title.trimmingCharacters(in: .whitespacesAndNewlines), author: author, publisher: publisher, category: category,
                                                 isbn: selectedResult?.isbn ?? "", coverURL: selectedResult?.coverURL?.absoluteString ?? "")
                        guard store.storageError == nil else { return }
                        if let onBookAdded {
                            // Date-specific calendar flows own their selected reading date.
                            onBookAdded(book)
                            dismiss()
                        } else if selectedResult != nil {
                            // Replace this sheet's content instead of racing dismissal
                            // against presentation of a second sheet.
                            bookForNewEntry = book
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showsSearch) {
            CatalogSearchView { result in
                title = result.title
                author = result.authors.joined(separator: ", ")
                publisher = result.publisher
                selectedResult = result
            }
        }
    }
}

struct CatalogBook: Decodable, Identifiable {
    var id: String { isbn + "|" + url + "|" + title }
    let title: String
    let authors: [String]
    let publisher: String
    let isbn: String
    let thumbnail: String
    let url: String

    var coverURL: URL? { Self.secureURL(thumbnail) }
    var detailURL: URL? { Self.secureURL(url) }
    private static func secureURL(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}

struct CatalogPage: Decodable {
    let books: [CatalogBook]
    let isEnd: Bool
}

struct CatalogCover: View {
    let url: URL?
    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: "book.closed").foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 64)
        .accessibilityHidden(true)
    }
}

private struct CatalogSearchView: View {
    @Environment(\.dismiss) private var dismiss
    var dismissOnSelect = true
    var focusesSearchOnAppear = false
    var onManualEntry: (() -> Void)? = nil
    let onSelect: (CatalogBook) -> Void
    @FocusState private var searchFocused: Bool
    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var results: [CatalogBook] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var isEnd = true
    @State private var page = 0
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var requestID = UUID()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("책 제목 또는 ISBN", text: $query)
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .onSubmit { startSearch() }
                            .autocorrectionDisabled()
                        Button("검색") { startSearch() }
                            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } footer: {
                    Text("검색어는 Cloudflare와 카카오에 전달돼요. 감상문은 전송하지 않아요.")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.secondary) }
                }
                if hasSearched && results.isEmpty && !isLoading && errorMessage == nil {
                    Text("검색 결과가 없어요. 다른 제목이나 ISBN으로 검색하거나 직접 입력해 주세요.")
                }
                ForEach(results.indices, id: \.self) { index in
                    let book = results[index]
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            onSelect(book)
                            if dismissOnSelect { dismiss() }
                        } label: {
                            HStack(spacing: 12) {
                                CatalogCover(url: book.coverURL)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title).font(.doveMayo(.headline, bold: true))
                                    Text(book.authors.joined(separator: ", ")).font(.doveMayo(.subheadline))
                                    Text(book.publisher).font(.doveMayo(.caption)).foregroundStyle(.secondary)
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
                } else if !isEnd {
                    Button("더 보기") { load(query: submittedQuery, page: page + 1) }
                }
                Section { Text("도서 검색 제공: Kakao · Daum").font(.doveMayo(.caption)).foregroundStyle(.secondary) }
            }
            .scrollContentBackground(.hidden)
            .background(GgotgalpiTheme.paper)
            .navigationTitle("책 검색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                if let onManualEntry {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("직접 입력") { onManualEntry() }
                    }
                }
            }
        }
        .task {
            if focusesSearchOnAppear { searchFocused = true }
        }
        .onDisappear { searchTask?.cancel(); requestID = UUID() }
    }

    private func startSearch() {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        submittedQuery = value
        results = []
        page = 0
        isEnd = true
        load(query: value, page: 1)
    }

    private func load(query: String, page requestedPage: Int) {
        searchTask?.cancel()
        let token = UUID()
        requestID = token
        isLoading = true
        errorMessage = nil
        searchTask = Task { @MainActor in
            defer { if requestID == token { isLoading = false } }
            do {
                var components = URLComponents(string: "https://ggotgalpi-book-search.rinarocketpunch.workers.dev/books")!
                components.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "page", value: String(requestedPage))]
                var request = URLRequest(url: components.url!)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, response) = try await URLSession.shared.data(for: request)
                try Task.checkCancellation()
                guard requestID == token else { return }
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                guard http.statusCode == 200 else {
                    errorMessage = http.statusCode == 429
                        ? "검색 요청이 많아요. 잠시 후 다시 시도해 주세요. 직접 입력은 계속 이용할 수 있어요."
                        : "지금은 책 검색을 이용할 수 없어요. 잠시 후 다시 검색하거나 직접 입력해 주세요."
                    return
                }
                let result = try JSONDecoder().decode(CatalogPage.self, from: data)
                results.append(contentsOf: result.books)
                page = requestedPage
                isEnd = result.isEnd || requestedPage >= 50
                hasSearched = true
            } catch {
                guard !Task.isCancelled, requestID == token else { return }
                errorMessage = "책 정보를 가져오지 못했어요. 인터넷 연결을 확인한 뒤 다시 검색하거나 직접 입력해 주세요."
            }
        }
    }
}

struct EditBookView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    let book: Book
    @State private var title: String
    @State private var author: String
    @State private var publisher: String
    @State private var category: BookCategory
    @State private var readingStatus: ReadingStatus
    @State private var isHiddenFromCalendar: Bool
    @State private var showsSearch = false
    @State private var selectedResult: CatalogBook?

    init(book: Book) {
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _publisher = State(initialValue: book.publisher)
        _category = State(initialValue: book.category)
        _readingStatus = State(initialValue: book.readingStatus)
        _isHiddenFromCalendar = State(initialValue: book.isHiddenFromCalendar)
    }

    var body: some View {
        NavigationStack {
            Form {
                StorageErrorSection()
                Section("책 정보") {
                    Button {
                        showsSearch = true
                    } label: {
                        Label("온라인 검색으로 책 정보 바꾸기", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    if let selectedResult {
                        HStack(spacing: 12) {
                            CatalogCover(url: selectedResult.coverURL)
                            Text("저장하면 제목·작가·출판사·ISBN·표지가 변경돼요. 기존 감상 기록은 그대로 유지돼요.")
                                .font(.doveMayo(.caption))
                        }
                    }
                    TextField("책 제목", text: $title)
                    TextField("작가", text: $author)
                    TextField("출판사", text: $publisher)
                    Picker("분야", selection: $category) {
                        ForEach(BookCategory.allCases.filter { $0 != .all }) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                }

                Section("읽기 설정") {
                    Picker("읽기 상태", selection: $readingStatus) {
                        ForEach(ReadingStatus.allCases.filter { $0 != .all }) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    Toggle("달력에서 숨기기", isOn: $isHiddenFromCalendar)
                }
            }
            .scrollContentBackground(.hidden)
            .background(GgotgalpiTheme.paper)
            .navigationTitle("책 정보 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        store.updateBook(
                            id: book.id,
                            title: title,
                            author: author,
                            publisher: publisher,
                            category: category,
                            readingStatus: readingStatus,
                            isHiddenFromCalendar: isHiddenFromCalendar,
                            isbn: selectedResult?.isbn,
                            coverURL: selectedResult.map { $0.coverURL?.absoluteString ?? "" }
                        )
                        guard store.storageError == nil else { return }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showsSearch) {
            CatalogSearchView { result in
                title = result.title
                author = result.authors.joined(separator: ", ")
                publisher = result.publisher
                selectedResult = result
            }
        }
        .presentationDetents([.large])
        .paperBackground()
    }
}

private struct ReadingDateTimePopover: View {
    @Environment(\.dismiss) private var dismiss
    @State var date: Date
    @State var includesTime: Bool
    @State var start: Date
    @State var end: Date
    let onSave: (Date, Bool, Date, Date) -> Void

    private var isValid: Bool { !includesTime || end > start }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Text("읽은 날짜·시간").font(.headline)
                Spacer()
                Button("완료") {
                    onSave(date, includesTime, start, end)
                    dismiss()
                }
                .disabled(!isValid)
            }
            .padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    DatePicker("읽은 날짜", selection: $date, displayedComponents: .date)
                    Toggle("시작·종료 시간 입력", isOn: $includesTime)
                    if includesTime {
                        DatePicker("시작", selection: $start, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("종료", selection: $end, displayedComponents: [.date, .hourAndMinute])
                    }
                    Text(isValid ? "달력에는 읽은 날짜로 표시돼요." : "종료 날짜와 시간은 시작보다 뒤여야 해요.")
                        .font(.footnote)
                        .foregroundStyle(isValid ? Color.secondary : Color.red)
                }
                .datePickerStyle(.compact)
                .padding()
            }
        }
        .frame(width: 320, height: 320)
    }
}

struct AddReadingEntryView: View {
    private enum WritingField: Hashable {
        case note
        case favoriteSentence
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    let book: Book
    let editingEntry: ReadingEntry?
    private let onSaved: (() -> Void)?
    @AppStorage(DemoStore.readingTimeEnabledKey) private var readingTimeEnabled = false
    @State private var includesReadingTime = false
    @State private var readingStartedAt = Date()
    @State private var readingEndedAt = Date()
    @State private var date = Date()
    @State private var pageFrom = ""
    @State private var pageTo = ""
    @State private var note = ""
    @State private var favoriteSentence = ""
    @State private var readingRound = 0
    @State private var rating = 0.0
    @State private var hasFinishedReadingRound = false
    @State private var roundBeforeCompletion: Int?
    @State private var hasInitializedValues = false
    @State private var showingEntryDeletionConfirmation = false
    @State private var showingReadingDatePopover = false
    @FocusState private var focusedWritingField: WritingField?

    init(book: Book, editingEntry: ReadingEntry?, initialDate: Date = Date(), onSaved: (() -> Void)? = nil) {
        self.book = book
        self.editingEntry = editingEntry
        self.onSaved = onSaved
        _date = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    private var trimmedFavoriteSentence: String {
        favoriteSentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var readingTimeError: String? {
        guard readingTimeEnabled, includesReadingTime else { return nil }
        return readingEndedAt > readingStartedAt ? nil : "종료 날짜와 시간은 시작보다 뒤여야 해요."
    }

    private var savedReadingMinutes: Int? {
        guard includesReadingTime else { return editingEntry?.readingMinutes }
        return max(0, Int(readingEndedAt.timeIntervalSince(readingStartedAt) / 60))
    }

    private var mostRecentPage: Int? {
        store.entries(for: book.id)
            .max { $0.createdAt < $1.createdAt }?
            .pageTo
    }

    private var pageValidationError: String? {
        let from = pageFrom.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = pageTo.trimmingCharacters(in: .whitespacesAndNewlines)
        if (!from.isEmpty && (Int(from) == nil || (Int(from) ?? -1) < 0))
            || (!to.isEmpty && (Int(to) == nil || (Int(to) ?? -1) < 0)) {
            return "쪽수는 0 이상의 정수로 입력해 주세요."
        }
        if !from.isEmpty, !to.isEmpty, let start = Int(from), let end = Int(to), start > end {
            return "끝 쪽수는 시작 쪽수보다 작을 수 없어요."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    StorageErrorSection()
                    Section {
                        if readingTimeEnabled {
                            HStack {
                                Text("읽은 날짜")
                                Spacer()
                                Button {
                                    focusedWritingField = nil
                                    showingReadingDatePopover = true
                                } label: {
                                    Text(date.shortKoreanDate)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("읽은 날짜와 시간 설정")
                                .popover(isPresented: $showingReadingDatePopover) {
                                    ReadingDateTimePopover(
                                        date: date,
                                        includesTime: includesReadingTime,
                                        start: readingStartedAt,
                                        end: readingEndedAt
                                    ) { newDate, includesTime, start, end in
                                        date = newDate
                                        includesReadingTime = includesTime
                                        readingStartedAt = start
                                        readingEndedAt = end
                                    }
                                    .presentationCompactAdaptation(.popover)
                                }
                            }
                        } else {
                            DatePicker("읽은 날짜", selection: $date, displayedComponents: .date)
                        }
                        Stepper("\(readingRound)회독", value: $readingRound, in: 0...99)
                    }

                    Section {
                        StarRatingPicker(rating: $rating)
                    } header: {
                        Text("별점")
                    } footer: {
                        Text("별의 왼쪽은 반점, 오른쪽은 정수 점수입니다. 선택한 점수를 다시 누르면 해제됩니다.")
                    }

                    Section {
                        HStack {
                            TextField("시작", text: $pageFrom)
                                .keyboardType(.numberPad)
                            Text("쪽부터")
                                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                            TextField("끝", text: $pageTo)
                                .keyboardType(.numberPad)
                            Text("쪽까지")
                                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                        }
                    } header: {
                        Text("읽은 구간")
                    } footer: {
                        if let pageValidationError { Text(pageValidationError).foregroundStyle(.red) }
                    }

                    Section("감상") {
                        TextEditor(text: $note)
                            .font(.doveMayo(size: 17))
                            .focused($focusedWritingField, equals: .note)
                            .frame(minHeight: 130)
                            .id(WritingField.note)
                    }

                    Section {
                        TextEditor(text: $favoriteSentence)
                            .font(.doveMayo(size: 17, bold: true))
                            .focused($focusedWritingField, equals: .favoriteSentence)
                            .frame(minHeight: 100)
                            .id(WritingField.favoriteSentence)
                    } header: {
                        Text("마음에 드는 문장")
                    } footer: {
                        Text("오늘 읽은 내용 중 기억하고 싶은 문장을 남겨보세요.")
                    }

                    Section {
                        Button {
                            let isFinishingCurrentRound = !hasFinishedReadingRound
                            hasFinishedReadingRound = isFinishingCurrentRound
                            if isFinishingCurrentRound {
                                roundBeforeCompletion = readingRound
                                readingRound = min(99, readingRound + 1)
                            } else if let previous = roundBeforeCompletion {
                                readingRound = previous
                                roundBeforeCompletion = nil
                            }
                        } label: {
                            HStack(spacing: GgotgalpiTheme.Spacing.control) {
                                Image(systemName: hasFinishedReadingRound ? "checkmark.square.fill" : "square")
                                    .font(.doveMayo(.title3))
                                Text("이번 회독을 마치셨나요?")
                                Spacer()
                            }
                            .foregroundStyle(GgotgalpiTheme.ink)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("이번 회독을 마치셨나요?")
                        .accessibilityValue(hasFinishedReadingRound ? "선택됨" : "선택되지 않음")
                    }
                }

                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .background(GgotgalpiTheme.paper)
                .onChange(of: focusedWritingField) { _, field in
                    guard let field else { return }
                    scrollWritingFieldIntoView(field, with: proxy, animated: true)
                }
                // TextEditor는 긴 글에서 내부적으로만 스크롤됩니다. 입력할 때마다
                // Form도 함께 조정해 편집기 자체가 키보드 아래로 내려가지 않게 합니다.
                .onChange(of: note) { _, _ in
                    guard focusedWritingField == .note else { return }
                    scrollWritingFieldIntoView(.note, with: proxy)
                }
                .onChange(of: favoriteSentence) { _, _ in
                    guard focusedWritingField == .favoriteSentence else { return }
                    scrollWritingFieldIntoView(.favoriteSentence, with: proxy)
                }
                .navigationTitle(editingEntry == nil ? "감상 기록" : "감상 기록 수정")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(editingEntry == nil ? "기록" : "저장") {
                            if let editingEntry {
                                store.updateEntry(
                                    id: editingEntry.id,
                                    date: date,
                                    pageFrom: Int(pageFrom.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
                                    pageTo: Int(pageTo.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
                                    note: note.isEmpty ? "새로운 감상을 기록했어요." : note,
                                    favoriteSentence: trimmedFavoriteSentence,
                                    readingRound: readingRound,
                                    rating: rating,
                                    readingMinutes: savedReadingMinutes,
                                    readingStartedAt: readingStartedAt,
                                    readingEndedAt: readingEndedAt,
                                    updatesReadingTime: readingTimeEnabled && includesReadingTime
                                )
                            } else {
                                store.addEntry(
                                    bookID: book.id,
                                    date: date,
                                    pageFrom: Int(pageFrom.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
                                    pageTo: Int(pageTo.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
                                    note: note.isEmpty ? "새로운 감상을 기록했어요." : note,
                                    favoriteSentence: trimmedFavoriteSentence,
                                    readingRound: readingRound,
                                    rating: rating,
                                    readingMinutes: readingTimeEnabled && includesReadingTime ? savedReadingMinutes : nil,
                                    readingStartedAt: readingTimeEnabled && includesReadingTime ? readingStartedAt : nil,
                                    readingEndedAt: readingTimeEnabled && includesReadingTime ? readingEndedAt : nil
                                )
                            }

                            guard store.storageError == nil else { return }
                            if hasFinishedReadingRound {
                                store.markBookAsFinished(id: book.id)
                            }
                            guard store.storageError == nil else { return }
                            onSaved?()
                            dismiss()
                        }
                        .disabled(pageValidationError != nil || readingTimeError != nil)
                    }

                    if editingEntry != nil {
                        ToolbarItem(placement: .bottomBar) {
                            Button("휴지통으로 이동", role: .destructive) {
                                showingEntryDeletionConfirmation = true
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .paperBackground()
        .alert("감상 기록을 휴지통으로 이동할까요?", isPresented: $showingEntryDeletionConfirmation) {
            Button("휴지통으로 이동", role: .destructive) {
                if let editingEntry {
                    store.moveEntryToTrash(id: editingEntry.id)
                }
                guard store.storageError == nil else { return }
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(DemoStore.trashRetentionDays)일 동안 휴지통에 보관되며, 이후 앱 이용 시 자동으로 영구 삭제됩니다.")
        }
        .onAppear {
            guard
                !hasInitializedValues
            else { return }

            hasInitializedValues = true
            if let editingEntry {
                date = editingEntry.date
                pageFrom = String(editingEntry.pageFrom)
                pageTo = String(editingEntry.pageTo)
                note = editingEntry.note
                favoriteSentence = editingEntry.favoriteSentence
                readingRound = editingEntry.readingRound
                rating = editingEntry.ratingValue
                // 책의 현재 상태를 과거 감상문의 완료 여부로 해석하지 않습니다.
                hasFinishedReadingRound = false
            } else if book.readingStatus == .reading, let mostRecentPage {
                pageFrom = String(mostRecentPage)
            }
            let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
            let suggestedEnd = Calendar.current.date(bySettingHour: now.hour ?? 12, minute: now.minute ?? 0, second: 0, of: date) ?? date
            readingEndedAt = editingEntry?.readingEndedAt ?? suggestedEnd
            readingStartedAt = editingEntry?.readingStartedAt ?? readingEndedAt.addingTimeInterval(-1800)
            includesReadingTime = editingEntry == nil || editingEntry?.readingStartedAt != nil
        }
    }

    private func scrollWritingFieldIntoView(
        _ field: WritingField,
        with proxy: ScrollViewProxy,
        animated: Bool = false
    ) {
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(field, anchor: .center)
            }
        } else {
            // 타이핑마다 애니메이션을 넣으면 입력이 밀려 보일 수 있어 즉시 보정합니다.
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                proxy.scrollTo(field, anchor: .center)
            }
        }
    }
}

private struct StorageErrorSection: View {
    @EnvironmentObject private var store: DemoStore

    var body: some View {
        if let error = store.storageError {
            Section {
                Text(error).foregroundStyle(.red)
            } header: {
                Text("저장 상태를 확인해 주세요")
            }
        }
    }
}

private struct StarRatingPicker: View {
    @Binding var rating: Double

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: ReadingRating.symbol(for: rating, at: value))
                        .font(.doveMayo(.title3))
                        .foregroundStyle(rating > Double(value - 1) ? GgotgalpiTheme.accent : GgotgalpiTheme.line)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let selectedValue = Double(value) - (location.x < 18 ? 0.5 : 0)
                            rating = rating == selectedValue ? 0 : selectedValue
                        }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("별점")
            .accessibilityValue(ReadingRating.label(for: rating))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: rating = min(5, rating + 0.5)
                case .decrement: rating = max(0, rating - 0.5)
                @unknown default: break
                }
            }

            Spacer(minLength: 0)

            Text(ReadingRating.label(for: rating))
                .font(.doveMayo(.subheadline))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }
}
