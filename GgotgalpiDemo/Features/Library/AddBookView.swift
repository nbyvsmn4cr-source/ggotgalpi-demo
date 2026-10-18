import SwiftUI

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    var onBookAdded: ((Book) -> Void)? = nil
    @State private var title = ""
    @State private var author = ""
    @State private var publisher = ""
    @State private var category: BookCategory = .literature

    var body: some View {
        NavigationStack {
            Form {
                StorageErrorSection()
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
                        let book = store.addBook(title: title, author: author, publisher: publisher, category: category)
                        guard store.storageError == nil else { return }
                        dismiss()
                        onBookAdded?(book)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .paperBackground()
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
                            isHiddenFromCalendar: isHiddenFromCalendar
                        )
                        guard store.storageError == nil else { return }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .paperBackground()
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
    @FocusState private var focusedWritingField: WritingField?

    init(book: Book, editingEntry: ReadingEntry?, initialDate: Date = Date()) {
        self.book = book
        self.editingEntry = editingEntry
        _date = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    private var trimmedFavoriteSentence: String {
        favoriteSentence.trimmingCharacters(in: .whitespacesAndNewlines)
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
                        DatePicker("읽은 날짜", selection: $date, displayedComponents: .date)
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
                                    rating: rating
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
                                    rating: rating
                                )
                            }

                            guard store.storageError == nil else { return }
                            if hasFinishedReadingRound {
                                store.markBookAsFinished(id: book.id)
                            }
                            guard store.storageError == nil else { return }
                            dismiss()
                        }
                        .disabled(pageValidationError != nil)
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
