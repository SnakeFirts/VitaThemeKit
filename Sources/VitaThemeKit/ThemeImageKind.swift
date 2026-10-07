import Foundation
import CoreGraphics

/// Tamaños finales de las imágenes de un tema (los mismos que usa ThemeBUILDER).
public enum ThemeImageKind: Sendable {
    case background          // bgN.png y lockpaper.png
    case thumbnail           // bgtN.png
    case icon
    case previewThumbnail
    case previewPage
    case previewLockscreen
    case notice

    public var pixelSize: CGSize {
        switch self {
        case .background:                       return CGSize(width: 960, height: 512)
        case .thumbnail:                        return CGSize(width: 360, height: 192)
        case .icon:                             return CGSize(width: 128, height: 128)
        case .previewThumbnail:                 return CGSize(width: 226, height: 128)
        case .previewPage, .previewLockscreen:  return CGSize(width: 480, height: 272)
        case .notice:                           return CGSize(width: 120, height: 110)
        }
    }
}
