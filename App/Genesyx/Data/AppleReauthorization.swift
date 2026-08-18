import AuthenticationServices
import UIKit

/// Asks Apple for a fresh authorization code at the moment she confirms a deletion.
///
/// It is collected here rather than kept from sign-in because there is nothing to keep:
/// `signInWithIdToken` exchanges the identity token directly with Supabase and never performs the
/// code exchange, so no Apple refresh token is ever stored. The code Apple hands back is valid for
/// about five minutes — long enough to be spent by the `delete_account` edge function against
/// `/auth/revoke`, and short enough that nothing durable is held on the device.
///
/// Running this presents Apple's own sheet a second time, which is also the honest thing: revoking
/// her Apple credential is a separate decision from deleting a Genesyx account, and Apple is the
/// party that should ask.
@MainActor
final class AppleReauthorization: NSObject {

    enum Failure: Error {
        /// She dismissed Apple's sheet. Distinct from every other failure because it is an answer:
        /// the deletion must stop, not proceed without the revoke.
        case cancelled
        case noCode
    }

    private var continuation: CheckedContinuation<String, Error>?

    func authorizationCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

extension AppleReauthorization: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        let code = (authorization.credential as? ASAuthorizationAppleIDCredential)
            .flatMap(\.authorizationCode)
            .flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor in
            self.finish(code.map { .success($0) } ?? .failure(Failure.noCode))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        Task { @MainActor in
            self.finish(.failure(cancelled ? Failure.cancelled : error))
        }
    }
}

extension AppleReauthorization: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
