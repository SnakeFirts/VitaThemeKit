import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case backgrounds = "Backgrounds"
    case lockscreen = "Lock screen"
    case consoleBar = "Bar and notices"
    case icons = "Icons"

    var id: String { rawValue }

    /// Nombre mostrado en la interfaz.
    var title: String {
        switch self {
        case .overview: return "Home"
        default: return rawValue
        }
    }

    /// Color propio de cada sección (los de los símbolos de PlayStation).
    var accent: Color {
        switch self {
        case .overview:    return Color.blueDeep
        case .backgrounds: return Color.psGreen
        case .lockscreen:  return Color.psRed
        case .consoleBar:  return Color.psBlue
        case .icons:       return Color.psPink
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .backgrounds: return "photo.on.rectangle.angled"
        case .lockscreen: return "lock.display"
        case .consoleBar: return "menubar.rectangle"
        case .icons: return "square.grid.3x3.fill"
        }
    }
}

// MARK: - Root

struct RootView: View {
    @StateObject private var project = ThemeProject()
    @StateObject private var icons = IconsModel()
    @State private var section: AppSection = .overview

    var body: some View {
        Group {
            if project.setupDone {
                workspace
            } else {
                SetupView(project: project)
            }
        }
        .preferredColorScheme(.light)
    }

    private var workspace: some View {
        ZStack {
            WaveBackground(colors: [section.accent, section.accent, section.accent]).ignoresSafeArea()
            HStack(spacing: 0) {
                Sidebar(project: project, section: $section)
                    .padding(16)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(section)
                    .transition(.opacity)
            }
            .animation(.easeOut(duration: 0.2), value: section)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .overview: OverviewView(project: project, icons: icons, section: $section)
        case .backgrounds: BackgroundsView(project: project)
        case .consoleBar: ConsoleBarView(project: project)
        case .icons: IconsView(model: icons)
        case .lockscreen: LockScreenView(project: project)
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @ObservedObject var project: ThemeProject
    @Binding var section: AppSection

    private static let validatorURL = URL(string: "https://psvt.ovh/validator/index.php")
    private static let githubURL = URL(string: "https://github.com/SnakeFirts")

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }
    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color.blueDeep, Color.blueMid, Color.blueSky],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            themeCard
            navigation
            Spacer(minLength: 0)
            footer
        }
        .padding(16)
        .frame(width: 236)
        .frame(maxHeight: .infinity)
        .glassCard(radius: 28)
    }

    // Tarjeta del tema: usa tu página 1 si existe

    private var themeCard: some View {
        Color.clear
            .aspectRatio(960.0 / 544.0, contentMode: .fit)
            .background { cardBackground }
            .overlay(alignment: .bottomLeading) { cardLabel }
            .clipShape(cardShape)
            .overlay(cardShape.strokeBorder(Color.white.opacity(0.6), lineWidth: 1.2))
            .shadow(color: Color.blueMid.opacity(0.3), radius: 16, y: 8)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if let page = project.pages.first {
            ZStack {
                GeometryReader { geo in
                    PageImageView(page: page, size: geo.size)
                }
                LinearGradient(colors: [.clear, Color.ink.opacity(0.6)],
                               startPoint: .center, endPoint: .bottom)
            }
        } else {
            ZStack {
                cardShape.fill(cardGradient)
                WaveBackground(tint: .white, intensity: 0.35)
            }
        }
    }

    private var cardLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text("v\(project.version)")
                .font(.system(size: 10, weight: .medium))
                .opacity(0.85)
        }
        .foregroundStyle(Color.white)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .padding(12)
    }

    // Navegación

    private var navigation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SECTIONS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(Color.ink.opacity(0.35))
                .padding(.leading, 10)
                .padding(.bottom, 4)
            ForEach(Array(AppSection.allCases.enumerated()), id: \.element.id) { i, s in
                SidebarItem(section: s,
                            selected: section == s,
                            shortcut: Character("\(i + 1)"),
                            trailing: trailingText(for: s)) {
                    section = s
                }
            }
        }
    }

    private func trailingText(for s: AppSection) -> String? {
        guard s == .backgrounds, !project.pages.isEmpty else { return nil }
        return "\(project.pages.count)"
    }

    // Pie

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().overlay(Color.ink.opacity(0.06))
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            if let url = Self.validatorURL {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                        Text("Theme validator")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.ink.opacity(0.55))
                    .modifier(HoverHighlight())
                }
            }
            creatorRow
            PSSymbols()
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var creatorRow: some View {
        let row = HStack(spacing: 10) {
            BrandMark(icon: .github)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("SnakeFirst12")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text("github.com/SnakeFirts")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.ink.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .modifier(HoverHighlight())

        if let url = Self.githubURL {
            Link(destination: url) { row }
        } else {
            row
        }
    }
}

// MARK: - Resaltado al pasar el cursor (pie)

private struct HoverHighlight: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(shape.fill(Color.white.opacity(hovering ? 0.55 : 0)))
            .contentShape(shape)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - Fila del menú

private struct SidebarItem: View {
    let section: AppSection
    let selected: Bool
    let shortcut: Character
    var trailing: String? = nil
    let action: () -> Void

    @State private var hovering = false

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }
    private var badgeShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
    }
    private var rowFill: Color {
        if selected { return Color.white.opacity(0.95) }
        return Color.white.opacity(hovering ? 0.55 : 0)
    }
    private var textColor: Color {
        if selected { return Color.ink }
        return Color.ink.opacity(0.7)
    }
    private var iconColor: Color {
        selected ? Color.white : section.accent
    }

    var body: some View {
        Button(action: action) { row }
            .buttonStyle(.plain)
            .keyboardShortcut(KeyEquivalent(shortcut), modifiers: .command)
            .help("\(section.title) (⌘\(String(shortcut)))")
            .onHover { hovering = $0 }
    }

    private var row: some View {
        HStack(spacing: 11) {
            badge
            Text(section.title)
                .font(.system(size: 13.5, weight: selected ? .semibold : .medium))
                .foregroundStyle(textColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(selected ? section.accent : Color.ink.opacity(0.45))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(section.accent.opacity(selected ? 0.14 : 0.08)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(rowShape.fill(rowFill))
        .shadow(color: section.accent.opacity(selected ? 0.20 : 0), radius: 10, y: 4)
        .contentShape(rowShape)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.easeOut(duration: 0.2), value: selected)
    }

    private var badge: some View {
        ZStack {
            badgeShape.fill(selected ? section.accent : section.accent.opacity(0.14))
            Image(systemName: section.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
        }
        .frame(width: 30, height: 30)
        .shadow(color: section.accent.opacity(selected ? 0.35 : 0), radius: 6, y: 3)
    }
}
