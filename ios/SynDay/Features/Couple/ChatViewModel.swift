import Foundation
import SwiftUI

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isSending = false
    var error: String?
    var channel: String?

    func load() async {
        do {
            let resp: RealtimeSession = try await APIClient.shared.request("/v1/realtime/session")
            self.channel = resp.channel
            // 阶段二-5：此处应接 GoEasy WS，订阅 channel 收消息。当前为本地态骨架。
            // 真机联调前先放一条欢迎消息。
            if messages.isEmpty {
                messages = [ChatMessage.placeholderWelcome()]
            }
        } catch let error as APIClient.APIError where error.status == 404 {
            // 未绑定伴侣：不进聊天
            self.channel = nil
            messages = []
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendText() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let msg = ChatMessage(id: UUID().uuidString, kind: .text(text), isMine: true, createdAt: Date(), status: .sending)
        messages.append(msg)
        inputText = ""
        Haptics.mediumImpact()
        // 占位：乐观标记为已送达；阶段二接 GoEasy 后改为真实 ACK
        Swift.Task {
            try? await Swift.Task.sleep(for: .milliseconds(400))
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                messages[idx].status = .sent
            }
        }
    }

    func sendImage(_ data: Data) async {
        isSending = true
        let msg = ChatMessage(id: UUID().uuidString, kind: .image(nil), isMine: true, createdAt: Date(), status: .sending, localData: data)
        messages.append(msg)
        Haptics.mediumImpact()
        do {
            let url = try await ImageUploader.shared.uploadImage(data: data, scene: .chat)
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                messages[idx].kind = .image(url)
                messages[idx].status = .sent
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                messages[idx].status = .failed
            }
            self.error = "图片发送失败"
            Haptics.error()
        }
        isSending = false
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    var kind: Kind
    let isMine: Bool
    let createdAt: Date
    var status: Status
    var localData: Data? // 发送中图片的本地预览

    enum Kind: Equatable {
        case text(String)
        case image(URL?)
    }

    enum Status: Equatable {
        case sending
        case sent
        case failed
    }

    static func placeholderWelcome() -> ChatMessage {
        ChatMessage(id: "welcome", kind: .text("情侣连线已就绪，开始和 TA 聊聊吧"), isMine: false, createdAt: Date(), status: .sent)
    }
}

struct RealtimeSession: Decodable {
    let channel: String
}