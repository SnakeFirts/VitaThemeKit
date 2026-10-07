import SwiftUI

/// Encabezado común de las pantallas: símbolo y etiqueta en monoespaciada, título y subtítulo.
struct SectionHeader: View {
    let symbol: String
    let label: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(3)
            }
            .foregroundStyle(accent)
            Text(title)
                .font(AppStyle.title(30))
                .foregroundStyle(Color.ink)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Color.ink.opacity(0.5))
        }
    }
}
