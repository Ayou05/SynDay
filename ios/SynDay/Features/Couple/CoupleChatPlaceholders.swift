import SwiftUI

// MARK: - 阶段二占位视图（情侣页 & IM页）
// 这两个 Tab 在阶段二实现，当前仅占位，保证 MainTabView 能编译

struct CoupleView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.tertiaryText)
                Text("情侣页").font(.body).foregroundStyle(Color.secondaryText)
                Text("绑定与陪伴功能将在阶段二上线").font(.caption).foregroundStyle(Color.tertiaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvas)
            .navigationTitle("情侣")
        }
    }
}

struct ChatView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                Image(systemName: "message.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.tertiaryText)
                Text("IM页").font(.body).foregroundStyle(Color.secondaryText)
                Text("聊天功能将在阶段二上线").font(.caption).foregroundStyle(Color.tertiaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvas)
            .navigationTitle("消息")
        }
    }
}
