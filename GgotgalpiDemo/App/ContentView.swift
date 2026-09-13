import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.scenePhase) private var scenePhase
    private enum Tab: Hashable {
        case calendar, bookshelf

        var index: Int {
            switch self {
            case .calendar: 0
            case .bookshelf: 1
            }
        }

        init?(index: Int) {
            switch index {
            case 0: self = .calendar
            case 1: self = .bookshelf
            default: return nil
            }
        }
    }

    @State private var selectedTab: Tab = .calendar
    @State private var isShowingSettings = false
    @State private var isShowingSettingsDetail = false
    @State private var interactiveOffset: CGFloat = 0
    @State private var isInteractiveSwipe = false
    @State private var calendarSearchResetID = 0
    @State private var bookshelfSearchResetID = 0
    @State private var calendarScrollToTopID = 0
    @State private var bookshelfScrollToTopID = 0
    @State private var calendarPastHighlightRefreshID = 0
    @Namespace private var dockGlassNamespace

    private let edgeActivationWidth: CGFloat = 28
    private let completionRatio: CGFloat = 0.30

    var body: some View {
        ZStack {
            screenBackground
                .ignoresSafeArea()

            GeometryReader { proxy in
                let pageWidth = proxy.size.width

                ZStack {
                    CalendarView(
                        searchResetID: calendarSearchResetID,
                        pastHighlightRefreshID: calendarPastHighlightRefreshID,
                        scrollToTopID: calendarScrollToTopID
                    )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .offset(x: calendarOffset(pageWidth: pageWidth))

                    BookshelfView(
                        searchResetID: bookshelfSearchResetID,
                        scrollToTopID: bookshelfScrollToTopID
                    )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .offset(x: bookshelfOffset(pageWidth: pageWidth))

                    SettingsView(
                        isShowingDetail: $isShowingSettingsDetail,
                        panelWidth: isShowingSettingsDetail ? proxy.size.width : proxy.size.width * 4 / 5
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .gray.opacity(0), location: 0),
                                        .init(color: .gray.opacity(0.5), location: 0.16),
                                        .init(color: .gray.opacity(0.5), location: 0.84),
                                        .init(color: .gray.opacity(0), location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 1)
                            .shadow(color: .black.opacity(0.14), radius: 10, x: -4)
                            .offset(x: proxy.size.width / 5)
                            .opacity(isShowingSettingsDetail ? 0 : 1)
                    }
                    .offset(x: settingsPanelOffset(pageWidth: pageWidth))
                    .animation(.easeInOut(duration: 0.28), value: isShowingSettingsDetail)
                    .animation(.easeInOut(duration: 0.32), value: isShowingSettings)
                }
                .clipped()
                .overlay(alignment: .leading) {
                    if isShowingSettings && !isShowingSettingsDetail {
                        Color.clear
                            .frame(width: pageWidth / 5)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissSettings()
                            }
                    }
                }
                .overlay(alignment: selectedTab == .calendar ? .trailing : .leading) {
                    if !isShowingSettings {
                        edgeSwipeArea(pageWidth: pageWidth)
                    }
                }
            }
        }
        // 화면 배경은 기기 가장자리까지 확장하되, 키보드가 나타날 때는 안전 영역을 존중합니다.
        .ignoresSafeArea(.container)
        .overlay(alignment: .bottom) {
            if !isShowingSettingsDetail {
                tabDock
            }
        }
        .tint(GgotgalpiTheme.accent)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            store.purgeExpiredEntries()
        }
    }

    private var screenBackground: Color {
        GgotgalpiTheme.paper
    }

    /// 화면 가장자리의 전용 영역에서 시작한 명확한 가로 드래그에만 반응해, 세로 스크롤과 충돌하지 않게 합니다.
    private func updateInteractiveSwipe(_ value: DragGesture.Value, pageWidth: CGFloat) {
        guard !isShowingSettings else { return }

        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height

        guard abs(horizontalDistance) > abs(verticalDistance) else { return }

        if !isInteractiveSwipe {
            let isAllowedDirection = (horizontalDistance < 0 && selectedTab == .calendar)
                || (horizontalDistance > 0 && selectedTab == .bookshelf)

            guard isAllowedDirection else {
                return
            }
            isInteractiveSwipe = true
        }

        interactiveOffset = clampedInteractiveOffset(horizontalDistance, pageWidth: pageWidth)
    }

    private func finishInteractiveSwipe(_ value: DragGesture.Value, pageWidth: CGFloat) {
        defer { isInteractiveSwipe = false }

        guard isInteractiveSwipe else { return }

        if abs(interactiveOffset) >= pageWidth * completionRatio {
            activateTab(interactiveOffset < 0 ? .bookshelf : .calendar)
        } else {
            withAnimation(.easeOut(duration: 0.24)) {
                interactiveOffset = 0
            }
        }
    }

    private func clampedInteractiveOffset(_ value: CGFloat, pageWidth: CGFloat) -> CGFloat {
        switch selectedTab {
        case .calendar:
            return min(0, max(-pageWidth, value))
        case .bookshelf:
            return max(0, min(pageWidth, value))
        }
    }

    private func calendarOffset(pageWidth: CGFloat) -> CGFloat {
        pageOffset(for: .calendar, pageWidth: pageWidth)
    }

    private func bookshelfOffset(pageWidth: CGFloat) -> CGFloat {
        pageOffset(for: .bookshelf, pageWidth: pageWidth)
    }

    private func pageOffset(for tab: Tab, pageWidth: CGFloat) -> CGFloat {
        CGFloat(tab.index - selectedTab.index) * pageWidth
            + interactiveOffset
            + (isShowingSettings && tab == selectedTab ? -(pageWidth * 4 / 5) : 0)
    }

    private func settingsPanelOffset(pageWidth: CGFloat) -> CGFloat {
        isShowingSettings ? 0 : pageWidth * 1.3
    }

    private func edgeSwipeArea(pageWidth: CGFloat) -> some View {
        Color.clear
            .frame(width: edgeActivationWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        updateInteractiveSwipe(value, pageWidth: pageWidth)
                    }
                    .onEnded { value in
                        finishInteractiveSwipe(value, pageWidth: pageWidth)
                    }
            )
    }

    private var tabDock: some View {
        tabDockSurface
            // 전체 화면 위에 떠 있으면서 홈 인디케이터 바로 위에 붙도록 안전 영역 안에서만 내립니다.
            .padding(.bottom, -8)
    }

    @ViewBuilder
    private var tabDockSurface: some View {
        if #available(iOS 26.0, *) {
            ZStack(alignment: .leading) {
                // 독 표면은 선택 인디케이터와 별도의 글라스 합성 그룹으로 유지합니다.
                GlassEffectContainer(spacing: 0) {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.clear, in: Capsule())
                        .frame(width: 228, height: 44)
                        .allowsHitTesting(false)
                }

                // 선택 슬롯끼리만 같은 글라스 형태로 morph합니다.
                GlassEffectContainer(spacing: 4) {
                    dockSelectionGlass
                }

                // 글라스 합성과 분리해 아이콘·글자가 굴절되거나 흐려지지 않게 합니다.
                tabDockContents
            }
            .frame(width: 228, height: 44)
        } else {
            tabDockContents
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var tabDockContents: some View {
        HStack(spacing: 0) {
            dockTabButton(title: "달력", symbol: "calendar", tab: .calendar)
            dockTabButton(title: "책장", symbol: "books.vertical", tab: .bookshelf)
            settingsDockButton
        }
        .frame(width: 228, height: 44)
    }

    @ViewBuilder
    private var dockSelectionGlass: some View {
        if #available(iOS 26.0, *) {
            HStack(spacing: 0) {
                dockSelectionSlot(for: .calendar)
                dockSelectionSlot(for: .bookshelf)
                dockSelectionSlot(isSelected: isShowingSettings)
            }
            .frame(width: 228, height: 44)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    @available(iOS 26.0, *)
    private func dockSelectionSlot(for tab: Tab) -> some View {
        dockSelectionSlot(isSelected: selectedTab == tab && !isShowingSettings)
    }

    @ViewBuilder
    @available(iOS 26.0, *)
    private func dockSelectionSlot(isSelected: Bool) -> some View {
        if isSelected {
            Capsule()
                .fill(.clear)
                .glassEffect(.clear, in: Capsule())
                .frame(width: 73, height: 38)
                .glassEffectID("dock-selection", in: dockGlassNamespace)
                .glassEffectTransition(.matchedGeometry)
                .frame(width: 76, height: 44)
        } else {
            Color.clear
                .frame(width: 76, height: 44)
        }
    }

    private func dockTabButton(title: String, symbol: String, tab: Tab) -> some View {
        Button {
            activateTab(tab)
        } label: {
            tabPickerLabel(title: title, symbol: symbol, isSelected: selectedTab == tab && !isShowingSettings)
                .frame(width: 76, height: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var settingsDockButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.32)) {
                if isShowingSettings {
                    isShowingSettingsDetail = false
                }
                isShowingSettings.toggle()
                interactiveOffset = 0
            }
        } label: {
            tabPickerLabel(title: "설정", symbol: "gearshape", isSelected: isShowingSettings)
                .frame(width: 76, height: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isShowingSettings ? "설정 닫기" : "설정")
    }

    private func tabPickerLabel(title: String, symbol: String, isSelected: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(isSelected ? GgotgalpiTheme.ink : GgotgalpiTheme.secondaryInk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 투명 글라스 선택 캡슐을 다른 탭으로 부드럽게 이동시킵니다.
    private func activateTab(_ tab: Tab) {
        if isShowingSettings {
            if tab == .calendar, selectedTab != .calendar {
                calendarPastHighlightRefreshID += 1
            }

            withAnimation(.easeInOut(duration: 0.32)) {
                isShowingSettings = false
                isShowingSettingsDetail = false
                selectedTab = tab
                interactiveOffset = 0
            }
            return
        }

        guard selectedTab != tab else {
            switch tab {
            case .calendar:
                calendarSearchResetID += 1
                calendarScrollToTopID += 1
            case .bookshelf:
                bookshelfSearchResetID += 1
                bookshelfScrollToTopID += 1
            }
            return
        }

        if tab == .calendar {
            calendarPastHighlightRefreshID += 1
        }

        withAnimation(.easeInOut(duration: 0.32)) {
            selectedTab = tab
            interactiveOffset = 0
        }
    }

    private func dismissSettings() {
        withAnimation(.easeInOut(duration: 0.32)) {
            isShowingSettings = false
            isShowingSettingsDetail = false
        }
    }
}

enum BookshelfSortOption: String, CaseIterable, Identifiable {
    case recentEntry
    case title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentEntry: "최근 기록순"
        case .title: "제목순"
        }
    }
}

struct SettingsView: View {
    @Binding var isShowingDetail: Bool
    let panelWidth: CGFloat
    @AppStorage("ggotgalpi.settings.bookshelf-sort-order") private var bookshelfSortOrder = BookshelfSortOption.recentEntry.rawValue
    @AppStorage("ggotgalpi.settings.show-publisher") private var showsPublisher = true
    @AppStorage("ggotgalpi.settings.show-favorite-sentences") private var showsFavoriteSentences = true
    @State private var isShowingTrash = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("정렬", selection: $bookshelfSortOrder) {
                        ForEach(BookshelfSortOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }

                    Toggle("출판사 표시", isOn: $showsPublisher)
                        .tint(Color(white: 0.28))
                    Toggle("마음에 드는 문장 바로가기", isOn: $showsFavoriteSentences)
                        .tint(Color(white: 0.28))
                } header: {
                    Text("꽃갈피")
                        .foregroundStyle(.gray)
                }

                Section {
                    Button(action: openTrash) {
                        HStack {
                            Label("휴지통", systemImage: "trash")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    LabeledContent("휴지통 보관 기간", value: "30일")
                } header: {
                    Text("기록 관리")
                        .foregroundStyle(.gray)
                }

                Section {
                    LabeledContent("버전", value: "0.1")
                } header: {
                    Text("앱 정보")
                        .foregroundStyle(.gray)
                }
            }
            .foregroundStyle(.black)
            .tint(.gray)
            .listRowBackground(Color.white)
            .listRowSeparatorTint(.gray.opacity(0.35))
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .safeAreaPadding(.bottom, 64)
            .frame(width: panelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .navigationDestination(isPresented: $isShowingTrash) {
                TrashView()
            }
            .onChange(of: isShowingTrash) { _, isTrashPresented in
                guard !isTrashPresented else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    guard !self.isShowingTrash else { return }
                    withAnimation(.easeInOut(duration: 0.28)) {
                        isShowingDetail = false
                    }
                }
            }
        }
        .background(Color.clear)
    }

    private func openTrash() {
        withAnimation(.easeInOut(duration: 0.28)) {
            isShowingDetail = true
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isShowingTrash = true
        }
    }
}
