import SwiftUI
import VitaThemeKit

// MARK: - Datos de contacto (edita aquí)

/// Todo lo que aparece en el panel de la derecha. Deja un valor en `nil`
/// y esa fila no se muestra.
private enum AuthorInfo {
    static let name = "SnakeFirst"
    static let tagline = "Made for a Vita enthusiast, by a Vita enthusiast."

    static let kofi: URL?   = nil   // URL(string: "https://ko-fi.com/TU_USUARIO")
    static let github: URL? = URL(string: "https://github.com/SnakeFirts")
    static let email: String? = "snakefirts12@gmail.com"

    static let credits = "Inspired by and built upon what I learned from Sony-ThemeTool (LiEnby) and ThemeBUILDER (AntHJ)."
}

// MARK: - Vista

struct SetupView: View {
    @ObservedObject var project: ThemeProject

    private var nameOK: Bool {
        !project.name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var versionOK: Bool {
        ThemeRules.isValidVersion(project.version)
    }
    private var creatorOK: Bool {
        !project.creator.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var canContinue: Bool {
        nameOK && versionOK && creatorOK
    }
    private var versionError: String? {
        if project.version.isEmpty || versionOK { return nil }
        return "Format 01.00"
    }

    // MARK: Body

    var body: some View {
        ZStack {
            WaveBackground().ignoresSafeArea()
            content
        }
        .preferredColorScheme(.light)
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 72) {
            form
            AboutPanel()
        }
        .padding(56)
    }

    // MARK: Formulario

    private var form: some View {
        VStack(alignment: .leading, spacing: 32) {
            header
            fields
            continueButton
        }
        .frame(width: 440, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            PSSymbols()
                .padding(.bottom, 4)
            Text("NEW THEME")
                .font(.system(size: 12, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Color.blueDeep)
            Text("Make your theme\nyour own.")
                .font(AppStyle.title(42))
                .foregroundStyle(Color.ink)
            Text("This information will appear on the console.")
                .font(AppStyle.body())
                .foregroundStyle(Color.ink.opacity(0.5))
        }
    }

    // Sin tarjeta de cristal: los campos van directo sobre el fondo.
    private var fields: some View {
        VStack(spacing: 22) {
            ThemeField(label: "Name", icon: "textformat",
                       text: $project.name, prompt: "My theme", valid: nameOK)
            HStack(spacing: 16) {
                ThemeField(label: "Version", icon: "number",
                           text: $project.version, prompt: "01.00",
                           valid: versionOK, error: versionError, monospaced: true)
                    .frame(width: 140)
                ThemeField(label: "Creator", icon: "person",
                           text: $project.creator, prompt: "Your name or alias",
                           valid: creatorOK)
            }
        }
    }

    private var continueButton: some View {
        Button {
            project.setupDone = true
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(FlatButtonStyle())
        .disabled(!canContinue)
        .keyboardShortcut(.defaultAction)
    }
}

// MARK: - Panel de contacto

private struct AboutPanel: View {

    private var hasLinks: Bool {
        AuthorInfo.kofi != nil || AuthorInfo.github != nil || AuthorInfo.email != nil
    }

    private var mailURL: URL? {
        AuthorInfo.email.flatMap { URL(string: "mailto:\($0)") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Made by")
                .font(AppStyle.label())
                .tracking(2)
                .foregroundStyle(Color.ink.opacity(0.4))

            VStack(alignment: .leading, spacing: 8) {
                Text(AuthorInfo.name)
                    .font(AppStyle.title(30))
                    .foregroundStyle(Color.ink)
                Text(AuthorInfo.tagline)
                    .font(AppStyle.body())
                    .foregroundStyle(Color.ink.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasLinks {
                VStack(spacing: 0) {
                    if let url = AuthorInfo.kofi {
                        row("Buy Me a Coffee", detail: "Ko-fi", icon: .kofi, url: url)
                    }
                    if let url = AuthorInfo.github {
                        row("Code & Updates", detail: "GitHub", icon: .github, url: url)
                    }
                    if let url = mailURL, let mail = AuthorInfo.email {
                        row("Contact Me", detail: mail, icon: .gmail, url: url)
                    }
                }
                .overlay(alignment: .top) { Divider().overlay(Color.ink.opacity(0.08)) }
            }

            Text(AuthorInfo.credits)
                .font(.system(size: 11))
                .foregroundStyle(Color.ink.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 300, alignment: .leading)
    }

    private func row(_ title: String, detail: String, icon: BrandIcon, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                BrandMark(icon: icon)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AppStyle.body(13, weight: .medium))
                        .foregroundStyle(Color.ink)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ink.opacity(0.45))
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.ink.opacity(0.3))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Divider().overlay(Color.ink.opacity(0.08)) }
    }
}

// MARK: - Campo

private struct ThemeField: View {
    let label: String
    let icon: String
    @Binding var text: String
    let prompt: String
    let valid: Bool
    var error: String? = nil
    var monospaced: Bool = false

    @FocusState private var isFocused: Bool

    private var hasError: Bool { error != nil }

    private var borderColor: Color {
        if hasError { return Color.red.opacity(0.6) }
        if isFocused { return Color.blueDeep }
        return Color.ink.opacity(0.14)
    }
    private var iconColor: Color {
        isFocused ? Color.blueDeep : Color.ink.opacity(0.3)
    }
    private var textFont: Font {
        monospaced
            ? .system(size: 15, weight: .medium, design: .monospaced)
            : .system(size: 15, weight: .medium)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            inputRow
        }
    }

    private var header: some View {
        HStack {
            Text(label.uppercased())
                .font(AppStyle.label())
                .tracking(1.6)
                .foregroundStyle(Color.ink.opacity(0.45))
            Spacer()
            if let error {
                Text(error)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.8))
            }
        }
    }

    // Fondo sólido, borde fino, sin sombras ni halo.
    private var inputRow: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 16)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(textFont)
                .foregroundStyle(Color.ink)
                .focused($isFocused)
            checkmark
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(AppStyle.shape.fill(Color.white))
        .overlay(AppStyle.shape.strokeBorder(borderColor, lineWidth: isFocused ? 1.5 : 1))
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .animation(.easeOut(duration: 0.15), value: hasError)
    }

    @ViewBuilder
    private var checkmark: some View {
        if valid {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.blueDeep)
                .transition(.opacity)
        }
    }
}
