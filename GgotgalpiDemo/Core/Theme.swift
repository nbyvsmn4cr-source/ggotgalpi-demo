import SwiftUI

private struct SplitPaneNavigationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var usesSplitPaneNavigation: Bool {
        get { self[SplitPaneNavigationKey.self] }
        set { self[SplitPaneNavigationKey.self] = newValue }
    }
}

private struct PaneBackButton: ViewModifier {
    let title: String?
    @Environment(\.usesSplitPaneNavigation) private var usesSplitPaneNavigation
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(usesSplitPaneNavigation)
            .toolbar(usesSplitPaneNavigation && title != nil ? .hidden : .automatic, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                if usesSplitPaneNavigation {
                    ZStack {
                        if let title {
                            Text(title)
                                .font(.system(size: 17, weight: .semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 60)
                                .frame(maxWidth: .infinity)
                        }
                        HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .modifier(PaneBackButtonStyle())
                        .accessibilityLabel("뒤로가기")
                        Spacer()
                        }
                    }
                    .foregroundStyle(GgotgalpiTheme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(GgotgalpiTheme.calendarCanvas)
                }
            }
    }
}

private struct PaneBackButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.plain).glassEffect(.regular.interactive(), in: Circle())
        } else {
            content.buttonStyle(.plain).background(.regularMaterial, in: Circle())
        }
    }
}

extension View {
    /// Keep the back action inside the pane rather than the window-level navigation bar.
    func paneBackButton(title: String? = nil) -> some View {
        modifier(PaneBackButton(title: title))
    }
}
import UIKit

extension Font {
    /// 감상 기록과 인용문에만 사용하는 둘기마요 글꼴입니다.
    static func doveMayo(size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Dovemayo-Bold" : "Dovemayo-Medium", size: size)
    }

    /// 기존 SwiftUI 글자 크기 체계를 유지하면서 둘기마요 굵기를 적용합니다.
    static func doveMayo(_ style: TextStyle, bold: Bool = false) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 34
        case .title: size = 28
        case .title2: size = 22
        case .title3: size = 20
        case .headline, .body: size = 17
        case .callout: size = 16
        case .subheadline: size = 15
        case .footnote: size = 13
        case .caption: size = 12
        case .caption2: size = 11
        @unknown default: size = 17
        }

        return .custom(bold ? "Dovemayo-Bold" : "Dovemayo-Medium", size: size, relativeTo: style)
    }
}

enum GgotgalpiTheme {
    // 시스템 외관이 바뀌면 이미 표시 중인 화면과 시트도 함께 갱신됩니다.
    private static func adaptive(_ light: UIColor, dark: CGFloat) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: dark, alpha: 1) : light
        })
    }
    // 앱 전반의 페이지 배경은 메인 화면과 같은 거의 흰색으로 통일합니다.
    static let paper = adaptive(UIColor(red: 0.992, green: 0.988, blue: 0.976, alpha: 1), dark: 0.07)
    static let paperDeep = adaptive(UIColor(red: 0.949, green: 0.922, blue: 0.867, alpha: 1), dark: 0.16)
    // 달력 카드 바깥에만 쓰는 거의 흰색의 웜 화이트입니다.
    static let calendarCanvas = paper
    static let ink = adaptive(UIColor(red: 0.18, green: 0.18, blue: 0.17, alpha: 1), dark: 0.93)
    static let secondaryInk = adaptive(UIColor(red: 0.43, green: 0.41, blue: 0.37, alpha: 1), dark: 0.70)
    static let line = adaptive(UIColor(red: 0.84, green: 0.82, blue: 0.77, alpha: 1), dark: 0.30)
    // 월간 달력의 가로·세로 격자에만 쓰는 은은한 웜 그레이입니다.
    static let calendarGridLine = adaptive(UIColor(red: 0.875, green: 0.847, blue: 0.796, alpha: 1), dark: 0.27)
    static let accent = adaptive(UIColor(red: 0.46, green: 0.43, blue: 0.36, alpha: 1), dark: 0.78)
    // 좋아하는 작가 카드 전용: 기존 베이지·갈색 대신 중립적인 회색 계열을 사용합니다.
    static let surface = adaptive(.white, dark: 0.12)
    static let favoriteAuthorCard = surface
    static let favoriteAuthorSelected = adaptive(UIColor(white: 0.90, alpha: 1), dark: 0.25)
    // Dark-mode ON uses a bright neutral track, distinct from the system's dark OFF track.
    // Keep the existing charcoal tint in light mode.
    static let toggleTint = adaptive(UIColor(white: 0.28, alpha: 1), dark: 0.78)

    enum Spacing {
        static let compact: CGFloat = 8
        static let control: CGFloat = 12
        static let content: CGFloat = 16
        static let screen: CGFloat = 20
        static let section: CGFloat = 24
        static let largeSection: CGFloat = 32
    }
}

struct PaperBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(GgotgalpiTheme.paper.ignoresSafeArea())
            .tint(GgotgalpiTheme.accent)
    }
}

struct LiquidGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

extension View {
    func paperBackground() -> some View {
        modifier(PaperBackground())
    }

    func liquidGlassCapsule() -> some View {
        modifier(LiquidGlassCapsule())
    }
}

struct SectionLabel: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.doveMayo(.headline, bold: true))
                .foregroundStyle(GgotgalpiTheme.ink)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.doveMayo(.caption))
                    .foregroundStyle(GgotgalpiTheme.secondaryInk)
            }
        }
    }
}

struct BookColorMark: View {
    let title: String
    let color: Color
    var size: CGFloat = 48
    var coverURL: String = ""

    var body: some View {
        Group {
            if let url = URL(string: coverURL), url.scheme == "https" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                Text(String(title.prefix(1)))
                    .font(.doveMayo(.headline, bold: true))
                    .foregroundStyle(.white.opacity(0.92))
            }
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(GgotgalpiTheme.line)
            .frame(height: 0.7)
    }
}

struct ReadingEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: GgotgalpiTheme.Spacing.compact) {
            Image(systemName: "text.book.closed")
                .font(.doveMayo(.title2))
                .foregroundStyle(GgotgalpiTheme.accent)

            Text(title)
                .font(.doveMayo(.headline, bold: true))
                .foregroundStyle(GgotgalpiTheme.ink)

            Text(message)
                .font(.doveMayo(.subheadline))
                .foregroundStyle(GgotgalpiTheme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GgotgalpiTheme.Spacing.largeSection)
        .padding(.horizontal, GgotgalpiTheme.Spacing.content)
    }
}

struct DesignSystemShowcase_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GgotgalpiTheme.Spacing.section) {
                SectionLabel(title: "공통 요소", actionTitle: "텍스트 액션") {}

                DatePicker(
                    "감상 날짜 선택",
                    selection: .constant(Date()),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ko_KR"))

                HStack(spacing: GgotgalpiTheme.Spacing.content) {
                    BookColorMark(
                        title: "어린 왕자",
                        color: Color(red: 0.55, green: 0.65, blue: 0.61),
                        size: 48
                    )

                    ReadingEmptyState(
                        title: "감상 없음",
                        message: "선택한 날의 빈 상태입니다."
                    )
                }
            }
            .padding(GgotgalpiTheme.Spacing.screen)
        }
        .paperBackground()
        .previewDisplayName("디자인 시스템")
    }
}
