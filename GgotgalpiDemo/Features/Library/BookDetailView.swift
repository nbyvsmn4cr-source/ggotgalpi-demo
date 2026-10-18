import SwiftUI

struct BookDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    let book: Book
    @State private var showingAddEntry = false
    @State private var showingEditBook = false
    @State private var editingEntry: ReadingEntry?
    @State private var selectedRelatedBook: Book?
    @State private var showingBookDeletionConfirmation = false
    @AppStorage("ggotgalpi.settings.show-publisher") private var showsPublisher = true

    private var currentBook: Book {
        store.book(for: book.id) ?? book
    }

    private var bookEntries: [ReadingEntry] {
        store.entries(for: currentBook.id)
    }

    private var averageRating: Double? {
        store.averageRating(for: currentBook.id)
    }

    private var sameAuthorBooks: [Book] {
        store.books
            .filter { $0.id != currentBook.id && store.hasSameAuthor(as: currentBook, candidate: $0) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack(alignment: .center, spacing: 16) {
                        BookColorMark(title: currentBook.title, color: currentBook.coverColor, size: 72)

                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 6) {
                                Text(currentBook.title)
                                    .font(.doveMayo(.title2, bold: true))
                                    .foregroundStyle(GgotgalpiTheme.ink)

                                Button {
                                    showingEditBook = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.doveMayo(.caption, bold: true))
                                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("책 정보 수정")
                            }
                            HStack(spacing: 5) {
                                Text(currentBook.author)
                                    .font(.doveMayo(.subheadline))
                                    .foregroundStyle(GgotgalpiTheme.secondaryInk)

                                Button {
                                    store.toggleFavoriteAuthor(currentBook.author)
                                } label: {
                                    Image(systemName: store.isFavoriteAuthor(currentBook.author) ? "star.fill" : "star")
                                        .font(.doveMayo(.caption, bold: true))
                                        .foregroundStyle(store.isFavoriteAuthor(currentBook.author) ? GgotgalpiTheme.accent : GgotgalpiTheme.secondaryInk)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(store.isFavoriteAuthor(currentBook.author) ? "좋아하는 작가 지정 해제" : "좋아하는 작가로 지정")
                            }
                            if showsPublisher && !currentBook.publisher.isEmpty {
                                Text(currentBook.publisher)
                                    .font(.doveMayo(.caption))
                                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
                            }
                            Text(currentBook.category.rawValue)
                                .font(.doveMayo(.caption))
                                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(GgotgalpiTheme.paperDeep)
                                .clipShape(Capsule())

                            if let averageRating {
                                BookAverageRating(rating: averageRating)
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 0) {
                        DetailStat(value: "\(bookEntries.count)", title: "감상 기록")
                        DetailStat(value: "\(Set(bookEntries.map(\.readingRound)).count)", title: "읽은 횟수")
                        DetailStat(value: bookEntries.isEmpty ? "-" : "\(bookEntries.map(\.pageTo).max() ?? 0)", title: "마지막 쪽")
                    }

                    if !sameAuthorBooks.isEmpty {
                        SectionLabel(title: "같은 작가의 책")

                        VStack(spacing: 0) {
                            ForEach(sameAuthorBooks) { relatedBook in
                                Button {
                                    selectedRelatedBook = relatedBook
                                } label: {
                                    HStack(spacing: GgotgalpiTheme.Spacing.control) {
                                        BookColorMark(title: relatedBook.title, color: relatedBook.coverColor, size: 36)
                                        Text(relatedBook.title)
                                            .font(.doveMayo(.subheadline, bold: true))
                                            .foregroundStyle(GgotgalpiTheme.ink)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.doveMayo(.caption, bold: true))
                                            .foregroundStyle(GgotgalpiTheme.secondaryInk)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)

                                if relatedBook.id != sameAuthorBooks.last?.id {
                                    DividerLine()
                                }
                            }
                        }
                    }

                    Button {
                        showingAddEntry = true
                    } label: {
                        Label("감상 기록 남기기", systemImage: "pencil.line")
                            .font(.doveMayo(.headline, bold: true))
                            .foregroundStyle(GgotgalpiTheme.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(GgotgalpiTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    SectionLabel(title: "감상 기록")

                    if bookEntries.isEmpty {
                        Text("아직 남긴 기록이 없어요.")
                            .font(.doveMayo(.subheadline))
                            .foregroundStyle(GgotgalpiTheme.secondaryInk)
                    } else {
                        ForEach(bookEntries) { entry in
                            HStack(alignment: .top, spacing: GgotgalpiTheme.Spacing.compact) {
                                Button {
                                    editingEntry = entry
                                } label: {
                                    ReadingEntryRow(entry: entry)
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
                            if entry.id != bookEntries.last?.id { DividerLine() }
                        }
                    }
                }
                .padding(22)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("책 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingBookDeletionConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("책 삭제")
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddReadingEntryView(book: currentBook, editingEntry: nil)
            }
            .sheet(item: $editingEntry) { entry in
                AddReadingEntryView(book: currentBook, editingEntry: entry)
            }
            .sheet(isPresented: $showingEditBook) {
                EditBookView(book: currentBook)
            }
            .sheet(item: $selectedRelatedBook) { relatedBook in
                BookDetailView(book: relatedBook)
            }
            .alert("책을 삭제할까요?", isPresented: $showingBookDeletionConfirmation) {
                Button("삭제", role: .destructive) {
                    store.deleteBook(id: currentBook.id)
                    guard store.storageError == nil else { return }
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("책과 연결된 모든 감상 기록(휴지통 포함)이 영구 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
        }
        .paperBackground()
    }
}

struct BookAverageRating: View {
    let rating: Double

    private var starRating: Double {
        ReadingRating.normalized(rating)
    }

    var body: some View {
        HStack(spacing: 3) {
            HStack(spacing: 1) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: ReadingRating.symbol(for: starRating, at: value))
                        .font(.doveMayo(.caption2))
                        .foregroundStyle(starRating > Double(value - 1) ? GgotgalpiTheme.accent : GgotgalpiTheme.line)
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            Text("평균 \(ReadingRating.label(for: rating))")
                .font(.doveMayo(.caption, bold: true))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("평균 별점 \(ReadingRating.label(for: rating))")
    }
}

struct DetailStat: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.doveMayo(.title2, bold: true))
                .foregroundStyle(GgotgalpiTheme.ink)
            Text(title)
                .font(.doveMayo(.caption2))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ReadingEntryRow: View {
    let entry: ReadingEntry
    @AppStorage("ggotgalpi.settings.show-favorite-sentences") private var showsFavoriteSentences = true

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.date.shortKoreanDate)
                        .font(.doveMayo(.subheadline, bold: true))
                        .foregroundStyle(GgotgalpiTheme.ink)

                    if entry.isFavoriteReview {
                        Label("가장 마음에 드는 감상문", systemImage: "heart.fill")
                            .font(.doveMayo(.caption2, bold: true))
                            .foregroundStyle(GgotgalpiTheme.accent)
                    }
                }
                Spacer()
                Text("\(entry.readingRound)회독 · p.\(entry.pageFrom)-p.\(entry.pageTo)")
                    .font(.doveMayo(.caption))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
            }
            Text(entry.note)
                .font(.doveMayo(size: 16))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                .lineSpacing(3)

            if entry.ratingValue > 0 {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { value in
                        Image(systemName: ReadingRating.symbol(for: entry.ratingValue, at: value))
                            .font(.doveMayo(.caption))
                            .foregroundStyle(entry.ratingValue > Double(value - 1) ? GgotgalpiTheme.accent : GgotgalpiTheme.line)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("별점 \(ReadingRating.label(for: entry.ratingValue))")
            }

            if showsFavoriteSentences && !entry.favoriteSentence.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.doveMayo(.caption, bold: true))
                        .foregroundStyle(GgotgalpiTheme.accent)

                    Text(entry.favoriteSentence)
                        .font(.doveMayo(size: 16, bold: true))
                        .foregroundStyle(GgotgalpiTheme.ink)
                        .italic()
                        .lineSpacing(3)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
