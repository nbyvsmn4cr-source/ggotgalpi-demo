import SwiftUI

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    @State private var title = ""
    @State private var author = ""
    @State private var publisher = ""
    @State private var category: BookCategory = .literature

    var body: some View {
        NavigationStack {
            Form {
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
                    Text("데모에서는 책마다 구분 색상을 자동으로 지정합니다.")
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
                        store.addBook(title: title, author: author, publisher: publisher, category: category)
                        dismiss()
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
    @State private var hasInitializedValues = false
    @State private var showingEntryDeletionConfirmation = false
    @FocusState private var focusedWritingField: WritingField?

    private var trimmedFavoriteSentence: String {
        favoriteSentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var mostRecentPage: Int? {
        store.entries(for: book.id)
            .max { $0.createdAt < $1.createdAt }?
            .pageTo
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
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

                    Section("읽은 구간") {
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
                    }

                    Section("감상") {
                        TextEditor(text: $note)
                            .focused($focusedWritingField, equals: .note)
                            .frame(minHeight: 130)
                            .id(WritingField.note)
                    }

                    Section {
                        TextEditor(text: $favoriteSentence)
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
                            hasFinishedReadingRound.toggle()
                        } label: {
                            HStack(spacing: GgotgalpiTheme.Spacing.control) {
                                Image(systemName: hasFinishedReadingRound ? "checkmark.square.fill" : "square")
                                    .font(.title3)
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
                .onChange(of: focusedWritingField) { field in
                    guard let field else { return }
                    scrollWritingFieldIntoView(field, with: proxy, animated: true)
                }
                // TextEditor는 긴 글에서 내부적으로만 스크롤됩니다. 입력할 때마다
                // Form도 함께 조정해 편집기 자체가 키보드 아래로 내려가지 않게 합니다.
                .onChange(of: note) { _ in
                    guard focusedWritingField == .note else { return }
                    scrollWritingFieldIntoView(.note, with: proxy)
                }
                .onChange(of: favoriteSentence) { _ in
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
                                    pageFrom: Int(pageFrom) ?? 0,
                                    pageTo: Int(pageTo) ?? 0,
                                    note: note.isEmpty ? "새로운 감상을 기록했어요." : note,
                                    favoriteSentence: trimmedFavoriteSentence,
                                    readingRound: readingRound,
                                    rating: rating
                                )
                            } else {
                                store.addEntry(
                                    bookID: book.id,
                                    date: date,
                                    pageFrom: Int(pageFrom) ?? 0,
                                    pageTo: Int(pageTo) ?? 0,
                                    note: note.isEmpty ? "새로운 감상을 기록했어요." : note,
                                    favoriteSentence: trimmedFavoriteSentence,
                                    readingRound: readingRound,
                                    rating: rating
                                )
                            }

                            if hasFinishedReadingRound {
                                store.markBookAsFinished(id: book.id)
                            }
                            dismiss()
                        }
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
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("30일 동안 휴지통에 보관되며, 이후 자동으로 영구 삭제됩니다.")
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
                hasFinishedReadingRound = book.readingStatus == .finished
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

private struct StarRatingPicker: View {
    @Binding var rating: Double

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: ReadingRating.symbol(for: rating, at: value))
                        .font(.title3)
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
                .font(.subheadline)
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }
}
