import SwiftUI

struct SplashView: View {
    @State private var breath = false
    @State private var appear = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.forest.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .scaleEffect(breath ? 1.15 : 0.85)
                    .opacity(breath ? 0.5 : 0.2)

                Circle()
                    .fill(Color.forest.opacity(0.14))
                    .frame(width: 96, height: 96)
                    .scaleEffect(breath ? 1.06 : 0.96)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.forest)
            }
            .opacity(appear ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breath = true }
                withAnimation(.easeOut(duration: 0.6)) { appear = true }
            }

            VStack(spacing: Spacing.xxs) {
                Text("朝夕同序")
                    .font(.h1)
                    .foregroundStyle(Color.ink)
                Text("一起努力，顶峰相见")
                    .font(.body)
                    .foregroundStyle(Color.secondaryText)
            }
            .opacity(appear ? 1 : 0)

            Spacer()
            ProgressView()
                .tint(.forest)
                .opacity(appear ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandGradient.hero)
    }
}
