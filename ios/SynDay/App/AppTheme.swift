import SwiftUI

// MARK: - Design Tokens
extension Color {
    static let forest = Color("Forest")
    static let ink = Color("Ink")
    static let secondaryText = Color("SecondaryText")
    static let tertiaryText = Color("TertiaryText")
    static let canvas = Color("Canvas")
    static let surfaceSoft = Color("SurfaceSoft")
    static let surfaceStrong = Color("SurfaceStrong")
    static let hairline = Color("Hairline")
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let error = Color("Error")
    static let orange = Color("Orange")
}

// MARK: - Font System
extension Font {
    static let display = Font.system(size: 56, weight: .bold, design: .monospaced)
    static let h1 = Font.system(size: 32, weight: .semibold, design: .default)
    static let h2 = Font.system(size: 22, weight: .semibold, design: .default)
    static let h3 = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let subhead = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let label = Font.system(size: 11, weight: .regular, design: .default)
    static let timer = Font.system(size: 48, weight: .semibold, design: .monospaced)
}

// MARK: - Spacing System
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius
enum CornerRadius {
    static let xxs: CGFloat = 3
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let full: CGFloat = 999
}

// MARK: - Touch Targets
enum TouchTarget {
    static let minSize: CGFloat = 44
    static let buttonSecondary: CGFloat = 36
    static let buttonPrimary: CGFloat = 44
    static let buttonLarge: CGFloat = 50
}

// MARK: - Line Heights
enum LineHeight {
    static let h1: CGFloat = 1.08
    static let h2: CGFloat = 1.2
    static let h3: CGFloat = 1.3
    static let body: CGFloat = 1.4
    static let subhead: CGFloat = 1.4
    static let caption: CGFloat = 1.3
    static let label: CGFloat = 1.2
    static let timer: CGFloat = 1.0
}

// MARK: - Shadows
enum Elevation {
    /// 卡片柔和阴影（surfaceSoft 上浮一档）
    static let card = (color: Color.black.opacity(0.06), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
    /// 悬浮按钮阴影
    static let floating = (color: Color.forest.opacity(0.25), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(6))
    /// 重点强调阴影（CTA / 头部 hero）
    static let hero = (color: Color.forest.opacity(0.18), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
}

extension View {
    /// 给卡片加柔和阴影
    func cardElevation() -> some View {
        shadow(color: Elevation.card.color, radius: Elevation.card.radius, x: Elevation.card.x, y: Elevation.card.y)
    }

    /// 悬浮元素阴影
    func floatingElevation() -> some View {
        shadow(color: Elevation.floating.color, radius: Elevation.floating.radius, x: Elevation.floating.x, y: Elevation.floating.y)
    }

    /// hero 区阴影
    func heroElevation() -> some View {
        shadow(color: Elevation.hero.color, radius: Elevation.hero.radius, x: Elevation.hero.x, y: Elevation.hero.y)
    }
}

// MARK: - Gradients
enum BrandGradient {
    /// 头部卡片渐变（forest 深浅过渡）
    static let profileCard = LinearGradient(
        colors: [Color.forest, Color.forest.opacity(0.82)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 启动页 / 登录页 hero 渐变
    static let hero = LinearGradient(
        colors: [Color.forest.opacity(0.08), Color.canvas],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 倒计时进度环底色
    static let focusRing = AngularGradient(
        colors: [Color.forest, Color.forest.opacity(0.6), Color.forest],
        center: .center
    )
}

