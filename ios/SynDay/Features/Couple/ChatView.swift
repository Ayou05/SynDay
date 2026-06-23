import SwiftUI
import PhotosUI

struct ChatView: View {
    @State private var vm = ChatViewModel()
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.channel == nil && vm.messages.isEmpty {
                    emptyState
                } else {
                    messageList
                    inputBar
                }
            }
            .background(Color.canvas)
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await vm.load() }
        .photosPicker(isPresented: .constant(false), selection: $photoItem)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Swift.Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await vm.sendImage(data)
                }
                photoItem = nil
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.forest.opacity(0.5))
            Text("还未绑定榜样")
                .font(.h3)
                .foregroundStyle(Color.ink)
            Text("去情侣页绑定后即可开始聊天")
                .font(.subhead)
                .foregroundStyle(Color.tertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: Spacing.sm) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.forest)
                    .frame(width: 32, height: 32)
            }
            TextField("发送消息", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...4)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.surfaceSoft)
                .cornerRadius(CornerRadius.lg)
            Button {
                Swift.Task { await vm.sendText() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.tertiaryText : Color.forest)
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.surfaceSoft)
        .overlay(Divider(), alignment: .top)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: Spacing.xxs) {
                bubbleContent
                statusLine
            }
            if !message.isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.kind {
        case .text(let text):
            Text(text)
                .font(.body)
                .foregroundStyle(message.isMine ? .white : Color.ink)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(message.isMine ? Color.forest : Color.surfaceSoft)
                .cornerRadius(CornerRadius.lg)
        case .image(let url):
            if let url {
                AsyncImage(url: ImageUploader.shared.thumbnailURL(url, width: 240, height: 240)) { phase in
                    switch phase {
                    case .empty, .failure:
                        ProgressView().tint(.forest).frame(width: 200, height: 200)
                    case .success(let image):
                        image.resizable().scaledToFill().frame(width: 200, height: 200).clipped().cornerRadius(CornerRadius.lg)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if let data = message.localData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
                    .frame(width: 200, height: 200).clipped()
                    .cornerRadius(CornerRadius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg).stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                    .opacity(0.7)
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch message.status {
        case .sending:
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "clock").font(.system(size: 9))
                Text("发送中").font(.system(size: 10))
            }
            .foregroundStyle(Color.tertiaryText)
        case .failed:
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 10))
                Text("发送失败").font(.system(size: 10))
            }
            .foregroundStyle(Color.error)
        case .sent:
            EmptyView()
        }
    }
}