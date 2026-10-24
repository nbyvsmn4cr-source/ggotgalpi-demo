import SwiftUI

/// 달력 날짜 셀 안에서 감상한 책을 표지 카드처럼 보여 주는 재사용 가능한 뷰입니다.
struct CalendarBookCoverStack: View {
    let books: [Book]
    let date: Date
    let isSelected: Bool

    private let maximumVisibleCovers = 3

    private var visibleBooks: [Book] {
        Array(books.prefix(maximumVisibleCovers))
    }

    private var isStacked: Bool {
        visibleBooks.count > 1
    }

    var body: some View {
        Group {
            if let book = visibleBooks.only {
                CalendarSingleBookCover(book: book, date: date, isSelected: isSelected)
            } else {
                stackedCovers
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isButton)
    }

    private var stackedCovers: some View {
        GeometryReader { proxy in
            let layout = layout(in: proxy.size)

            ZStack(alignment: .topLeading) {
                ZStack {
                    // 첫 작품이 마지막에 그려져 항상 최전면에 남습니다.
                    ForEach(Array(visibleBooks.enumerated()).reversed(), id: \.element.id) { index, book in
                        CalendarBookCover(book: book, size: layout.coverSize)
                            .overlay {
                                if index == 0 {
                                    CalendarCoverDayNumber(date: date, isSelected: isSelected)
                                }
                            }
                            .offset(
                                x: CGFloat(index) * layout.horizontalOffset,
                                y: CGFloat(index) * layout.verticalOffset
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            }
        }
    }

    private func layout(in container: CGSize) -> CoverLayout {
        let stackCount = max(visibleBooks.count - 1, 0)
        let horizontalOffset: CGFloat = isStacked ? 3 : 0
        // 뒤 표지는 오른쪽·위쪽으로만 살짝 노출해 앞 표지의 크기를 지킵니다.
        let verticalOffset: CGFloat = isStacked ? -2 : 0
        let availableHeight = max(0, container.height - 3)
        let maximumWidthRatio: CGFloat = isStacked ? 0.82 : 0.90
        let widthByCell = container.width * maximumWidthRatio
        let widthByStack = max(0, container.width - CGFloat(stackCount) * horizontalOffset)
        let coverWidth = min(widthByCell, widthByStack, availableHeight * (2 / 3))

        return CoverLayout(
            coverSize: CGSize(width: coverWidth, height: coverWidth * 1.5),
            horizontalOffset: horizontalOffset,
            verticalOffset: verticalOffset
        )
    }

    private var accessibilityDescription: String {
        let titles = books.map(\.title).joined(separator: ", ")
        return "\(date.shortKoreanDate), 감상 \(books.count)권: \(titles)"
    }
}

/// 감상 작품이 한 권인 날짜 전용 표지입니다. 표지 비율을 유지한 채 날짜 칸의 대부분을 채웁니다.
private struct CalendarSingleBookCover: View {
    let book: Book
    let date: Date
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let availableHeight = max(0, proxy.size.height - 3)
            let coverWidth = min(proxy.size.width * 0.90, availableHeight * (2 / 3))
            let coverSize = CGSize(width: coverWidth, height: coverWidth * 1.5)

            ZStack(alignment: .topLeading) {
                CalendarBookCover(book: book, size: coverSize)
                    .overlay {
                        CalendarCoverDayNumber(date: date, isSelected: isSelected)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

/// 표지를 가로 2등분·세로 3등분했을 때 좌상단 칸의 중심에 날짜를 둡니다.
private struct CalendarCoverDayNumber: View {
    let date: Date
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            CalendarDayNumberBadge(date: date, isSelected: isSelected)
                .position(x: proxy.size.width * 0.25, y: proxy.size.height / 6)
        }
    }
}

/// 표지 위 날짜가 묻히지 않도록, 외곽이 자연스럽게 사라지는 흰 원 배지로 표시합니다.
private struct CalendarDayNumberBadge: View {
    let date: Date
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.98), .white.opacity(0.34), .white.opacity(0)],
                        center: .center,
                        startRadius: 0.5,
                        endRadius: 9.5
                    )
                )
                .frame(width: 19, height: 19)

            Text(date.formatted(.dateTime.day()))
                .font(.doveMayo(size: 8, bold: isSelected))
                .foregroundStyle(.black.opacity(0.82))
        }
        .frame(width: 19, height: 19)
    }
}

private struct CoverLayout {
    let coverSize: CGSize
    let horizontalOffset: CGFloat
    let verticalOffset: CGFloat
}

private extension Array {
    var only: Element? {
        count == 1 ? first : nil
    }
}

struct CalendarBookCover: View {
    let book: Book
    var compact = false
    var size: CGSize?

    private var resolvedSize: CGSize {
        size ?? (compact ? CGSize(width: 34, height: 51) : CGSize(width: 42, height: 63))
    }

    var body: some View {
        coverArtwork
            .frame(width: resolvedSize.width, height: resolvedSize.height)
            .overlay {
                if let url = URL(string: book.coverURL), url.scheme == "https" {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        }
                    }
                    .frame(width: resolvedSize.width, height: resolvedSize.height)
                }
            }
            .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
    }

    private var coverArtwork: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(book.coverColor)
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                Text(book.title)
                    .font(.doveMayo(size: 7, bold: true))
                    .foregroundStyle(.white.opacity(0.96))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(.white.opacity(0.34), lineWidth: 0.5)
            }
    }

}

struct CalendarBookOrderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var books: [Book]
    @State private var editMode: EditMode = .active

    let date: Date
    let saveOrder: ([UUID]) -> Void

    init(date: Date, books: [Book], saveOrder: @escaping ([UUID]) -> Void) {
        self.date = date
        _books = State(initialValue: books)
        self.saveOrder = saveOrder
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(books) { book in
                        HStack(spacing: GgotgalpiTheme.Spacing.control) {
                            CalendarBookCover(book: book, compact: true)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(book.title)
                                    .font(.doveMayo(.headline, bold: true))
                                    .foregroundStyle(GgotgalpiTheme.ink)
                                Text(book.author)
                                    .font(.doveMayo(.subheadline))
                                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
                            }
                        }
                    }
                    .onMove { source, destination in
                        books.move(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text("맨 위의 작품이 달력에서 가장 앞에 보입니다.")
                }
            }
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
            .background(GgotgalpiTheme.paper)
            .navigationTitle(date.shortKoreanDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        saveOrder(books.map(\.id))
                        dismiss()
                    }
                }
            }
        }
        .paperBackground()
    }
}
