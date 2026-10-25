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
    @AppStorage("ggotgalpi.onboarding.completed.v1") private var hasSeenGuide = false
    @State private var showingFirstLaunchGuide = false
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
                let showsBothPages = pageWidth >= 700
                // A folded display reserves a side strip for system controls as well.
                let usesPaneNavigation = showsBothPages || proxy.safeAreaInsets.trailing > 40 || proxy.safeAreaInsets.leading > 40
                let paneWidth = showsBothPages ? pageWidth / 2 : pageWidth

                ZStack(alignment: .leading) {
                    CalendarView(
                        searchResetID: calendarSearchResetID,
                        pastHighlightRefreshID: calendarPastHighlightRefreshID,
                        scrollToTopID: calendarScrollToTopID,
                        showsSearchAndFilterControls: !showsBothPages
                    )
                        .padding(.top, showsBothPages ? 20 : 0)
                        .frame(width: paneWidth, height: proxy.size.height)
                        .clipped()
                        .offset(x: showsBothPages ? 0 : calendarOffset(pageWidth: pageWidth))

                    BookshelfView(
                        searchResetID: bookshelfSearchResetID,
                        scrollToTopID: bookshelfScrollToTopID
                    )
                        .environment(\.usesSplitPaneNavigation, usesPaneNavigation)
                        .padding(.top, showsBothPages ? 20 : 0)
                        .frame(width: paneWidth, height: proxy.size.height)
                        .clipped()
                        .allowsHitTesting(!showsBothPages || !isShowingSettings)
                        .accessibilityHidden(showsBothPages && isShowingSettings)
                        .offset(x: showsBothPages ? paneWidth : bookshelfOffset(pageWidth: pageWidth))

                    if showsBothPages {
                        Rectangle()
                            .fill(.gray.opacity(0.2))
                            .frame(width: 1)
                            .offset(x: paneWidth)
                            .allowsHitTesting(false)
                    }

                    SettingsView(
                        isShowingDetail: $isShowingSettingsDetail,
                        panelWidth: showsBothPages || isShowingSettingsDetail ? paneWidth : paneWidth * 4 / 5
                    )
                    .environment(\.usesSplitPaneNavigation, usesPaneNavigation)
                    .padding(.top, showsBothPages ? 20 : 0)
                    .background(showsBothPages ? GgotgalpiTheme.surface : Color.clear)
                    .frame(width: paneWidth, height: proxy.size.height)
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
                            .offset(x: showsBothPages ? 0 : paneWidth / 5)
                            .opacity(!showsBothPages && isShowingSettingsDetail ? 0 : 1)
                    }
                    .clipped()
                    .offset(x: showsBothPages
                            ? (isShowingSettings ? paneWidth : pageWidth)
                            : settingsPanelOffset(pageWidth: pageWidth))
                    .allowsHitTesting(isShowingSettings)
                    .accessibilityHidden(!isShowingSettings)
                    .animation(.easeInOut(duration: 0.28), value: isShowingSettingsDetail)
                    .animation(.easeInOut(duration: 0.32), value: isShowingSettings)
                }
                .frame(width: pageWidth, height: proxy.size.height, alignment: .leading)
                .clipped()
                .overlay(alignment: .leading) {
                    if !showsBothPages && isShowingSettings && !isShowingSettingsDetail {
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
                    if !showsBothPages && !isShowingSettings {
                        edgeSwipeArea(pageWidth: pageWidth)
                            // Reserve the top controls for taps, not page-swiping gestures.
                            .padding(.top, proxy.safeAreaInsets.top + 96)
                    }
                }
                .onChange(of: showsBothPages) { _, _ in
                    interactiveOffset = 0
                    isInteractiveSwipe = false
                    resetSearches()
                }
            }
        }
        // 화면 배경은 기기 가장자리까지 확장하되, 키보드가 나타날 때는 안전 영역을 존중합니다.
        // Folded displays can reserve a horizontal system area. Never place controls there.
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .font(.doveMayo(.body))
        .overlay(alignment: .bottom) {
            if !isShowingSettingsDetail {
                GeometryReader { proxy in
                    if proxy.size.width >= 700 {
                        floatingSettingsButton
                            .padding(.trailing, 20)
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            // Only this control extends into the lower end of the side strip.
                            .offset(x: proxy.safeAreaInsets.trailing)
                    } else {
                        tabDock
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                // Keep the bottom controls fixed when the keyboard appears.
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .tint(GgotgalpiTheme.accent)
        .task {
            if !hasSeenGuide { showingFirstLaunchGuide = true }
        }
        .fullScreenCover(isPresented: $showingFirstLaunchGuide) {
            GettingStartedGuide {
                hasSeenGuide = true
                showingFirstLaunchGuide = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            store.refresh()
            store.purgeExpiredEntries()
        }
        .alert("기록 처리 오류", isPresented: Binding(
            get: { store.storageError != nil },
            set: { if !$0 { store.storageError = nil } }
        )) {
            Button("확인") { store.storageError = nil }
        } message: {
            Text(store.storageError ?? "")
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
        Button(action: toggleSettings) {
            tabPickerLabel(title: "설정", symbol: "gearshape", isSelected: isShowingSettings)
                .frame(width: 76, height: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isShowingSettings ? "설정 닫기" : "설정")
    }

    private var floatingSettingsButton: some View {
        Button(action: toggleSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(GgotgalpiTheme.ink)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background {
            if #available(iOS 26.0, *) {
                Circle().fill(.clear).glassEffect(.regular, in: Circle())
            } else {
                Circle().fill(.regularMaterial)
            }
        }
        .accessibilityLabel(isShowingSettings ? "설정 닫기" : "설정")
    }

    private func toggleSettings() {
        resetSearches()
        withAnimation(.easeInOut(duration: 0.32)) {
            if isShowingSettings { isShowingSettingsDetail = false }
            isShowingSettings.toggle()
            interactiveOffset = 0
        }
    }

    private func tabPickerLabel(title: String, symbol: String, isSelected: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.doveMayo(.body, bold: true))
            Text(title)
                .font(.doveMayo(.caption2, bold: true))
        }
        .foregroundStyle(isSelected ? GgotgalpiTheme.ink : GgotgalpiTheme.secondaryInk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 투명 글라스 선택 캡슐을 다른 탭으로 부드럽게 이동시킵니다.
    private func activateTab(_ tab: Tab) {
        // 다른 탭이나 설정으로 이동한 뒤 돌아왔을 때, 이전 화면의 검색창이 남아 있지 않게 합니다.
        resetSearches()

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
                calendarScrollToTopID += 1
            case .bookshelf:
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

    private func resetSearches() {
        calendarSearchResetID += 1
        bookshelfSearchResetID += 1
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
    @AppStorage(DemoStore.readingTimeEnabledKey) private var readingTimeEnabled = false
    @AppStorage(DemoStore.trashRetentionDaysKey) private var trashRetentionDays = DemoStore.defaultTrashRetentionDays
    @State private var isShowingTrash = false
    @State private var showingTrashRetentionOptions = false
    @State private var showingGuide = false

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
                        .tint(GgotgalpiTheme.toggleTint)
                    Toggle("읽은 시간 기록", isOn: $readingTimeEnabled)
                        .tint(GgotgalpiTheme.toggleTint)
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
                                .font(.doveMayo(.caption, bold: true))
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingTrashRetentionOptions = true
                    } label: {
                        LabeledContent("휴지통 보관 기간", value: "\(trashRetentionDays)일")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("기록 관리")
                        .foregroundStyle(.gray)
                }

                Section {
                    Button {
                        showingGuide = true
                    } label: {
                        HStack {
                            Label("사용 가이드 다시 보기", systemImage: "book.pages")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.doveMayo(.caption, bold: true))
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    LabeledContent("버전", value: "0.1")
                } header: {
                    Text("앱 정보")
                        .foregroundStyle(.gray)
                }
            }
            .foregroundStyle(GgotgalpiTheme.ink)
            .tint(.gray)
            .listRowBackground(GgotgalpiTheme.surface)
            .listRowSeparatorTint(.gray.opacity(0.35))
            .scrollContentBackground(.hidden)
            .background(GgotgalpiTheme.surface)
            .safeAreaPadding(.bottom, 64)
            .navigationDestination(isPresented: $isShowingTrash) {
                TrashView()
            }
            .confirmationDialog("휴지통 보관 기간", isPresented: $showingTrashRetentionOptions, titleVisibility: .visible) {
                ForEach([7, 14, 30], id: \.self) { days in
                    Button("\(days)일") {
                        trashRetentionDays = days
                    }
                }
                Button("취소", role: .destructive) {}
            } message: {
                Text("삭제한 감상 기록은 선택한 기간이 지나면 자동으로 영구 삭제됩니다.")
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
        .frame(width: panelWidth)
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .background(Color.clear)
        .fullScreenCover(isPresented: $showingGuide) {
            GettingStartedGuide { showingGuide = false }
        }
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

private struct GettingStartedGuide: View {
    let onFinish: () -> Void
    @State private var stepIndex = 0

    private struct Step {
        let screenshot: String
        let title: String
        let message: String
        // Coordinates are normalized against the original 1206 × 2622 screenshots.
        let target: CGRect
    }

    private let steps: [Step] = [
        Step(screenshot: "GuideCalendar", title: "기록할 날짜를 눌러요",
             message: "읽은 날을 선택하고 +를 누르면 그 날짜의 화면에서 책을 검색하고 감상문을 쓸 수 있어요. 이미 기록한 날에도 추가할 수 있어요.",
             target: CGRect(x: 0.06, y: 0.24, width: 0.88, height: 0.38)),
        Step(screenshot: "GuideCalendar", title: "아래에서 화면을 바꿔요",
             message: "달력은 날짜별 기록, 책장은 책별 기록을 보여줘요. 설정도 여기서 열어요.",
             target: CGRect(x: 0.23, y: 0.92, width: 0.53, height: 0.055)),
        Step(screenshot: "GuideSearch", title: "책과 감상문을 함께 검색해요",
             message: "상단 검색창에 제목·작가·감상문 내용을 입력하세요. 새 책은 키보드의 ‘검색’을 눌러 온라인에서 찾아요.",
             target: CGRect(x: 0.04, y: 0.07, width: 0.92, height: 0.05)),
        Step(screenshot: "GuideSearch", title: "검색 없이 직접 등록할 수도 있어요",
             message: "‘새 책 직접 등록’에서 책 정보를 적으세요. 온라인 검색어만 Cloudflare·카카오에 전달되며 감상문은 보내지 않아요.",
             target: CGRect(x: 0.05, y: 0.27, width: 0.65, height: 0.04)),
        Step(screenshot: "GuideEntry", title: "날짜와 읽은 시간을 정해요",
             message: "날짜를 누르면 기록할 날을 바꿀 수 있어요. 설정에서 시간 기록을 켜면 시작·종료 시간도 입력해요.",
             target: CGRect(x: 0.05, y: 0.20, width: 0.9, height: 0.08)),
        Step(screenshot: "GuideEntry", title: "별점은 반점씩 남겨요",
             message: "별의 왼쪽은 0.5점, 오른쪽은 1점 단위예요. 같은 점수를 다시 누르면 해제돼요.",
             target: CGRect(x: 0.05, y: 0.40, width: 0.9, height: 0.09)),
        Step(screenshot: "GuideEntry", title: "오늘의 감상을 적어요",
             message: "사진은 ‘섬진강 아이들’의 감상문이에요. 짧은 생각도 좋아요. 아래에는 마음에 드는 문장도 남길 수 있고, 다 썼다면 오른쪽 위의 기록·저장을 눌러요.",
             target: CGRect(x: 0.05, y: 0.71, width: 0.9, height: 0.19)),
        Step(screenshot: "GuideSettings", title: "읽은 시간 기록을 켜고 꺼요",
             message: "필요할 때만 켜세요. 감상문 작성 화면의 날짜를 눌러 시간 팝업을 열 수 있어요.",
             target: CGRect(x: 0.26, y: 0.24, width: 0.68, height: 0.05)),
        Step(screenshot: "GuideSettings", title: "삭제한 감상문은 휴지통에 있어요",
             message: "보관 중에는 복원할 수 있어요. 7·14·30일 중 고른 기간이 지나면 앱 이용 시 영구 삭제돼요.",
             target: CGRect(x: 0.26, y: 0.37, width: 0.68, height: 0.1)),
        Step(screenshot: "GuideSettings", title: "언제든 다시 볼 수 있어요",
             message: "사용법이 생각나지 않으면 설정의 ‘사용 가이드 다시 보기’를 눌러주세요.",
             target: CGRect(x: 0.26, y: 0.55, width: 0.68, height: 0.055))
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("꽃갈피 사용 가이드")
                    .font(.doveMayo(.headline, bold: true))
                Spacer()
                Button("건너뛰기", action: onFinish)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)

            GeometryReader { proxy in
                let aspect = CGFloat(1206) / 2622
                let width = min(proxy.size.width, proxy.size.height * aspect)
                let height = width / aspect
                let step = steps[stepIndex]
                let target = CGRect(x: step.target.minX * width, y: step.target.minY * height,
                                    width: step.target.width * width, height: step.target.height * height)
                ZStack {
                    Image(step.screenshot)
                        .resizable()
                        .scaledToFit()
                        .accessibilityHidden(true)

                    Path { path in
                        path.addRect(CGRect(x: 0, y: 0, width: width, height: height))
                        path.addRoundedRect(in: target, cornerSize: CGSize(width: 10, height: 10))
                    }
                    .fill(.black.opacity(0.60), style: FillStyle(eoFill: true))
                    .accessibilityHidden(true)

                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: target.width, height: target.height)
                        .position(x: target.midX, y: target.midY)
                        .accessibilityHidden(true)

                    // Keep the explanation over the photo, on the opposite side of the highlighted control.
                    VStack {
                        if step.target.midY < 0.5 { Spacer(minLength: 0) }
                        VStack(alignment: .leading, spacing: 8) {
                            Label(step.title, systemImage: step.target.midY < 0.5 ? "arrow.up" : "arrow.down")
                                .font(.doveMayo(.headline, bold: true))
                                .accessibilityAddTraits(.isHeader)
                            ScrollView {
                                Text(step.message)
                                    .font(.doveMayo(.body))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxHeight: height * 0.23)
                        }
                        .padding(14)
                        .foregroundStyle(GgotgalpiTheme.ink)
                        .background(GgotgalpiTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                        .accessibilityElement(children: .combine)
                        .id(stepIndex)
                        if step.target.midY >= 0.5 { Spacer(minLength: 0) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, height * 0.10)
                    .padding(.bottom, height * 0.10)
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 16) {
                Button("이전") { stepIndex -= 1 }
                    .disabled(stepIndex == 0)
                    .frame(minWidth: 48, minHeight: 48)
                Text("\(stepIndex + 1) / \(steps.count)")
                    .font(.doveMayo(.caption))
                    .accessibilityLabel("총 \(steps.count)단계 중 \(stepIndex + 1)단계")
                Button(stepIndex == steps.count - 1 ? "시작하기" : "다음") {
                    if stepIndex == steps.count - 1 { onFinish() }
                    else { stepIndex += 1 }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(GgotgalpiTheme.paper)
                .background(GgotgalpiTheme.ink, in: RoundedRectangle(cornerRadius: 14))
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .font(.doveMayo(.body))
        .foregroundStyle(GgotgalpiTheme.ink)
        .tint(GgotgalpiTheme.ink)
        .background(GgotgalpiTheme.paper.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}
