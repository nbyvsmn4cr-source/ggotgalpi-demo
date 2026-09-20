import SwiftUI

struct BookDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    let book: Book
    @State private var showingAddEntry = false
    @State private var showingEditBook = false
    @State private var editingEntry: ReadingEntry?
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack(alignment: .center, spacing: 16) {
                        BookColorMark(title: currentBook.title, color: currentBook.coverColor, size: 72)

                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 6) {
                                Text(currentBook.title)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(GgotgalpiTheme.ink)

                                Button {
                                    showingEditBook = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(GgotgalpiTheme.secondaryInk)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("책 정보 수정")
                            }
                            Text(currentBook.author)
                                .font(.subheadline)
                                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                            if showsPublisher && !currentBook.publisher.isEmpty {
                                Text(currentBook.publisher)
                                    .font(.caption)
                                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
                            }
                            Text(currentBook.category.rawValue)
                                .font(.caption)
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

                    Button {
                        showingAddEntry = true
                    } label: {
                        Label("감상 기록 남기기", systemImage: "pencil.line")
                            .font(.headline)
                            .foregroundStyle(GgotgalpiTheme.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(GgotgalpiTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    SectionLabel(title: "감상 기록")

                    if bookEntries.isEmpty {
                        Text("아직 남긴 기록이 없어요.")
                            .font(.subheadline)
                            .foregroundStyle(GgotgalpiTheme.secondaryInk)
                    } else {
                        ForEach(bookEntries) { entry in
                            Button {
                                editingEntry = entry
                            } label: {
                                ReadingEntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("감상 기록 수정")
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
            .alert("책을 삭제할까요?", isPresented: $showingBookDeletionConfirmation) {
                Button("삭제", role: .destructive) {
                    store.deleteBook(id: currentBook.id)
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("책과 연결된 모든 감상 기록도 함께 삭제됩니다.")
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
                        .font(.caption2)
                        .foregroundStyle(starRating > Double(value - 1) ? GgotgalpiTheme.accent : GgotgalpiTheme.line)
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            Text("평균 \(ReadingRating.label(for: rating))")
                .font(.caption.weight(.medium))
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
                .font(.title2.weight(.semibold))
                .foregroundStyle(GgotgalpiTheme.ink)
            Text(title)
                .font(.caption2)
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
                Text(entry.date.shortKoreanDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GgotgalpiTheme.ink)
                Spacer()
                Text("\(entry.readingRound)회독 · p.\(entry.pageFrom)-p.\(entry.pageTo)")
                    .font(.caption)
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
            }
            Text(entry.note)
                .font(.subheadline)
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                .lineSpacing(3)

            if entry.ratingValue > 0 {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { value in
                        Image(systemName: ReadingRating.symbol(for: entry.ratingValue, at: value))
                            .font(.caption)
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GgotgalpiTheme.accent)

                    Text(entry.favoriteSentence)
                        .font(.subheadline)
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
