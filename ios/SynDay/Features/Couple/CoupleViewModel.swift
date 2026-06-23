import Foundation
import SwiftUI

@Observable
final class CoupleViewModel {
    var bindingState: BindingState = .unknown
    var partner: PartnerOverview?
    var monthlyReport: CoupleMonthlyReport?
    var isLoading = false
    var error: String?

    // 绑定流程临时态
    var generatedPairing: PairingToken?
    var claimCode: String = ""
    var isBusy = false

    // MARK: - 加载：判定绑定状态
    func load() async {
        isLoading = true
        do {
            let overview: PartnerOverview = try await APIClient.shared.request("/v1/couple/partner")
            self.partner = overview
            self.bindingState = .bound(overview)
            self.error = nil
        } catch let error as APIClient.APIError where error.status == 404 {
            // 未绑定
            self.partner = nil
            self.bindingState = .unbound
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 生成星图令牌（5 分钟有效）
    func createPairing() async {
        isBusy = true
        do {
            let pairing: PairingToken = try await APIClient.shared.request("/v1/couple/pairings", method: .POST)
            self.generatedPairing = pairing
            self.bindingState = .awaitingClaim(pairing)
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
        isBusy = false
    }

    // MARK: - 认领（输入令牌或 6 位码）
    func claimPairing() async {
        let token = claimCode.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { return }
        isBusy = true
        do {
            let input = PairingClaimInput(token: token, code: token)
            let pairing: PairingToken = try await APIClient.shared.request("/v1/couple/pairings/claim", method: .POST, body: input)
            self.generatedPairing = pairing
            self.bindingState = .awaitingConfirm(pairing)
            Haptics.success()
        } catch let error as APIClient.APIError where error.status == 404 {
            self.error = "令牌无效或已过期"
            Haptics.error()
        } catch let error as APIClient.APIError where error.status == 409 {
            self.error = "令牌已被其他人认领"
            Haptics.error()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
        isBusy = false
    }

    // MARK: - 双方确认（自己点确认）
    func confirmPairing() async {
        guard case .awaitingConfirm(let pairing) = bindingState else { return }
        isBusy = true
        do {
            let result: PairingConfirmation = try await APIClient.shared.request(
                "/v1/couple/pairings/\(pairing.id)/confirm", method: .POST)
            if result.status == "completed" {
                Haptics.taskCompleted()
                await load() // 刷新绑定态
            } else {
                // waiting — 对方还没确认
                self.bindingState = .awaitingConfirm(pairing)
                self.error = "等待 TA 确认中…"
            }
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
        isBusy = false
    }

    // MARK: - 解绑
    func unbind() async {
        do {
            try await APIClient.shared.requestEmpty("/v1/couple/binding", method: .DELETE)
            self.partner = nil
            self.bindingState = .unbound
            self.generatedPairing = nil
            Haptics.mediumImpact()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - 月度报告
    func loadMonthlyReport(month: String) async {
        do {
            let report: CoupleMonthlyReport = try await APIClient.shared.request(
                "/v1/couple/reports", query: [URLQueryItem(name: "month", value: month)])
            self.monthlyReport = report
        } catch let error as APIClient.APIError where error.status == 404 {
            self.monthlyReport = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}