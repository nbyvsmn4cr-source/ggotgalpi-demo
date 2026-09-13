import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DemoStore
    @Environment(\.scenePhase) private var scenePhase
    private enum Tab: Hashable {
        case calendar, bookshelf
    }

    @State private var selectedTab: Tab = .calendar
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
                }
                .clipped()
                .overlay(alignment: selectedTab == .calendar ? .trailing : .leading) {
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
            }
        }
        // 화면 배경은 기기 가장자리까지 확장하되, 키보드가 나타날 때는 안전 영역을 존중합니다.
        .ignoresSafeArea(.container)
        .overlay(alignment: .bottom) {
            tabDock
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
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height

        guard abs(horizontalDistance) > abs(verticalDistance) else { return }

        if !isInteractiveSwipe {
            let isAllowedDirection = switch selectedTab {
            case .calendar: horizontalDistance < 0
            case .bookshelf: horizontalDistance > 0
            }

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
        selectedTab == .calendar ? interactiveOffset : -pageWidth + interactiveOffset
    }

    private func bookshelfOffset(pageWidth: CGFloat) -> CGFloat {
        selectedTab == .bookshelf ? interactiveOffset : pageWidth + interactiveOffset
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
                        .frame(width: 152, height: 44)
                        .allowsHitTesting(false)
                }

                // 선택 슬롯끼리만 같은 글라스 형태로 morph합니다.
                GlassEffectContainer(spacing: 4) {
                    dockSelectionGlass
                }

                // 글라스 합성과 분리해 아이콘·글자가 굴절되거나 흐려지지 않게 합니다.
                tabDockContents
            }
            .frame(width: 152, height: 44)
        } else {
            tabDockContents
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var tabDockContents: some View {
        HStack(spacing: 0) {
            dockTabButton(title: "달력", symbol: "calendar", tab: .calendar)
            dockTabButton(title: "책장", symbol: "books.vertical", tab: .bookshelf)
        }
        .frame(width: 152, height: 44)
    }

    @ViewBuilder
    private var dockSelectionGlass: some View {
        if #available(iOS 26.0, *) {
            HStack(spacing: 0) {
                dockSelectionSlot(for: .calendar)
                dockSelectionSlot(for: .bookshelf)
            }
            .frame(width: 152, height: 44)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    @available(iOS 26.0, *)
    private func dockSelectionSlot(for tab: Tab) -> some View {
        if selectedTab == tab {
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
            tabPickerLabel(title: title, symbol: symbol, isSelected: selectedTab == tab)
                .frame(width: 76, height: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
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
}
