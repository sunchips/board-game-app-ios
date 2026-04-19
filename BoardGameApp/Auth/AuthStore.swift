import AuthenticationServices
import Foundation
import Observation

/// Single source of truth for the signed-in session. Views observe this to
/// decide whether to show the login gate. `restore()` reads Keychain on
/// launch so returning users skip straight to the home screen.
@MainActor
@Observable
final class AuthStore {
    private(set) var session: AuthSession?
    private(set) var errorMessage: String?
    private(set) var isAuthenticating: Bool = false

    private static let sessionKey = "session"

    init() {
        restore()
        observeExpiryNotifications()
    }

    private func observeExpiryNotifications() {
        NotificationCenter.default.addObserver(
            forName: .apiSessionExpired,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in self?.signOut() }
        }
    }

    var isSignedIn: Bool { session != nil && session?.isExpired == false }

    func restore() {
        guard let raw = KeychainStore.read(Self.sessionKey),
              let data = raw.data(using: .utf8),
              let decoded = try? Self.decoder.decode(AuthSession.self, from: data),
              !decoded.isExpired
        else {
            session = nil
            return
        }
        session = decoded
    }

    func handleAppleAuthorization(_ authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8)
        else {
            errorMessage = "Apple didn't return an identity token"
            return
        }
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        await exchangeToken(identityToken: token, fullName: fullName.isEmpty ? nil : fullName)
    }

    func signOut() {
        KeychainStore.delete(Self.sessionKey)
        session = nil
    }

    private func exchangeToken(identityToken: String, fullName: String?) async {
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }
        do {
            let response: AuthResponse = try await APIClient.shared.signInWithApple(
                AppleAuthRequest(identityToken: identityToken, fullName: fullName),
            )
            let newSession = AuthSession(
                token: response.token,
                expiresAt: response.expiresAt,
                user: response.user,
            )
            try persist(newSession)
            session = newSession
        } catch let apiError as APIError {
            errorMessage = apiError.errorDescription ?? "Sign-in failed"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist(_ session: AuthSession) throws {
        let data = try Self.encoder.encode(session)
        guard let json = String(data: data, encoding: .utf8) else { return }
        try KeychainStore.save(json, for: Self.sessionKey)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
