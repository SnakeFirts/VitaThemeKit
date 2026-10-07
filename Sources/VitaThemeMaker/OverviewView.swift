import SwiftUI
import AppKit
import VitaThemeKit

/// Pantalla de inicio: las cuatro secciones en una cuadrícula de 2 x 2 y,
/// debajo, lo que falta para exportar el tema, solo con iconos.
struct OverviewView: View {
    @ObservedObject var project: ThemeProject
    @ObservedObject var icons: IconsModel
    @Binding var section: AppSection

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible())]

    private var sections: [AppSection] {
        AppSection.allCases.filter { $0 != .overview }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                grid
                exportArea
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Encabezado

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR THEME")
                .font(.system(size: 12, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Color.blueDeep)
            Text("What do you want\nto customize?")
                .font(AppStyle.title(40))
                .foregroundStyle(Color.ink)
        }
    }

    // MARK: Cuadrícula

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(sections) { s in
                OverviewTile(section: s, status: status(s)) {
                    section = s
                }
            }
        }
    }

    private func status(_ s: AppSection) -> String {
        switch s {
        case .backgrounds: return "\(project.pages.count) of \(Theme.maxPages) pages"
        case .icons: return "\(icons.sources.count) of \(IconsModel.all.count) icons"
        case .lockscreen: return project.showClock ? "Clock visible" : "Clock hidden"
        case .consoleBar: return "Bar, text and notice"
        case .overview: return ""
        }
    }

    // MARK: Exportar el tema

    private struct Requirement: Identifiable {
        let id: String
        let symbol: String
        let section: AppSection
        let done: Bool
        let doneText: String
        let missingText: String
    }

    /// Lo que necesita el tema. Cada uno es un icono; el texto sale al pasar el cursor.
    private var requirements: [Requirement] {
        let missingIcons = IconsModel.all.count - icons.sources.count
        return [
            Requirement(id: "pages", symbol: "photo.on.rectangle.angled", section: .backgrounds,
                        done: !project.pages.isEmpty,
                        doneText: "\(project.pages.count) background pages",
                        missingText: "Add at least one background page"),
            Requirement(id: "lock", symbol: "lock.display", section: .lockscreen,
                        done: project.lockpaper.hasImage,
                        doneText: "Lockscreen ready",
                        missingText: "The lock screen image is missing"),
            Requirement(id: "noNotice", symbol: "bell", section: .consoleBar,
                        done: project.notices.source(hasNew: false) != nil,
                        doneText: "Bubble without notice ready",
                        missingText: "The image for the bubble without notice is missing (notice.png)"),
            Requirement(id: "newNotice", symbol: "bell.badge", section: .consoleBar,
                        done: project.notices.source(hasNew: true) != nil,
                        doneText: "Bubble with notice ready",
                        missingText: "The image for the bubble with notice is missing (notices.png)"),
            Requirement(id: "icons", symbol: "square.grid.3x3.fill", section: .icons,
                        done: missingIcons == 0,
                        doneText: "ALL \(IconsModel.all.count) icons ready",
                        missingText: "\(missingIcons) icons missing")
        ]
    }

    /// Problemas del tema que no tienen icono propio (nombre muy largo, versión, etc.).
    private var otherIssues: [String] {
        ThemeRules.issues(for: project.theme).filter { !$0.hasPrefix("Add at least") }
    }

    private var exportArea: some View {
        let ready = project.exportMissing(icons: icons).isEmpty
        return VStack(alignment: .leading, spacing: 16) {
            Divider().overlay(Color.ink.opacity(0.08))

            Text("EXPORT THEME")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color.ink.opacity(0.45))

            HStack(spacing: 10) {
                ForEach(requirements) { r in
                    RequirementChip(
                        requirement: RequirementChip.Info(
                            symbol: r.symbol,
                            accent: r.section.accent,
                            done: r.done,
                            tooltip: r.done ? r.doneText : r.missingText)
                    ) {
                        section = r.section
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    if let dir = Pickers.folder() { project.exportTheme(icons: icons, to: dir) }
                } label: {
                    HStack(spacing: 8) {
                        if project.isExportingTheme {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Export theme")
                    }
                }
                .buttonStyle(FlatButtonStyle())
                .disabled(!ready || project.isExportingTheme)

                if let zip = project.lastExportedZip {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([zip])
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(FlatButtonStyle(prominent: false))
                }
            }

            if let status = project.themeExportStatus {
                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ink.opacity(0.6))
            }
            ForEach(otherIssues + project.themeExportProblems, id: \.self) { problem in
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.orange)
            }
        }
    }
}

// MARK: - Chip de requisito (solo icono)

private struct RequirementChip: View {
    struct Info {
        let symbol: String
        let accent: Color
        let done: Bool
        let tooltip: String
    }

    let requirement: Info
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) { chip }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help(requirement.tooltip)
    }

    private var chip: some View {
        let done = requirement.done
        let fill: Color = done ? requirement.accent.opacity(0.14) : Color.ink.opacity(0.05)
        let iconColor: Color = done ? requirement.accent : Color.ink.opacity(0.35)
        return ZStack {
            AppStyle.shape.fill(fill)
            Image(systemName: requirement.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(iconColor)
        }
        .frame(width: 46, height: 46)
        .overlay(
            AppStyle.shape.strokeBorder(
                hovering ? requirement.accent.opacity(0.7) : Color.ink.opacity(done ? 0 : 0.18),
                style: StrokeStyle(lineWidth: 1, dash: done ? [] : [3, 3])
            )
        )
        .overlay(alignment: .bottomTrailing) {
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .frame(width: 15, height: 15)
                    .background(Circle().fill(Color.psGreen))
                    .offset(x: 5, y: 5)
            }
        }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - Tarjeta compacta

private struct OverviewTile: View {
    let section: AppSection
    let status: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) { card }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
    }

    private var card: some View {
        HStack(spacing: 14) {
            badge
            VStack(alignment: .leading, spacing: 2) {
                Text(section.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.ink.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.shape.fill(Color.white.opacity(0.78)))
        .overlay(
            AppStyle.shape.strokeBorder(
                hovering ? section.accent.opacity(0.7) : Color.ink.opacity(0.08),
                lineWidth: 1
            )
        )
        .animation(.easeOut(duration: 0.15), value: hovering)
        .contentShape(AppStyle.shape)
    }

    private var badge: some View {
        ZStack {
            AppStyle.shape.fill(section.accent.opacity(0.14))
            Image(systemName: section.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(section.accent)
        }
        .frame(width: 40, height: 40)
    }
}
