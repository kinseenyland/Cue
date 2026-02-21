import AuthenticationServices
import CryptoKit
import Foundation
import Combine
import SpotifyiOS
import UIKit

class SpotifyManager: NSObject, ObservableObject {
    static let shared = SpotifyManager()

    private let keychainService = "com.cue.spotify"
    private let accessTokenKey = "spotify_access_token"
    private let refreshTokenKey = "spotify_refresh_token"

    let spotifyClientID = "93c38381b8ff4b7d984fa217cbb3dcd3"
    let spotifyRedirectURL = URL(string: "spotify-ios-quick-start://spotify-login-callback")!

    @Published var isConnected = false
    @Published var currentTrackName = ""
    /// True while exchanging auth code for token (user returned from browser but token not ready yet)
    @Published var isFinishingAuth = false
    @Published var accessToken: String? {
        didSet {
            appRemote.connectionParameters.accessToken = accessToken
            if let token = accessToken {
                KeychainHelper.save(key: accessTokenKey, value: token, service: keychainService)
            } else {
                KeychainHelper.delete(key: accessTokenKey, service: keychainService)
            }
        }
    }
    private var refreshToken: String? {
        didSet {
            if let token = refreshToken {
                KeychainHelper.save(key: refreshTokenKey, value: token, service: keychainService)
            } else {
                KeychainHelper.delete(key: refreshTokenKey, service: keychainService)
            }
        }
    }

    override init() {
        super.init()
        accessToken = KeychainHelper.load(key: accessTokenKey, service: keychainService)
        refreshToken = KeychainHelper.load(key: refreshTokenKey, service: keychainService)
    }
    
    var playURI = ""
    
    lazy var configuration = SPTConfiguration(
        clientID: spotifyClientID,
        redirectURL: spotifyRedirectURL
    )
    
    lazy var appRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(configuration: self.configuration, logLevel: .debug)
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()
    
    /// Connect: on device uses Spotify app (so App Remote works); on simulator uses Web PKCE (search only).
    @MainActor
    @discardableResult
    func connect() -> Bool {
        #if targetEnvironment(simulator)
        print("[Spotify] Simulator: using web PKCE (search only; no playback).")
        return connectWithWebAuth()
        #else
        // Native flow opens the Spotify app so it gives us a token and accepts App Remote connections.
        print("[Spotify] Opening Spotify app to connect (required for playback)...")
        let scopes = ["user-read-private", "user-modify-playback-state"]
        appRemote.authorizeAndPlayURI("", asRadio: false, additionalScopes: scopes, sessionIdentifier: nil)
        return true
        #endif
    }

    /// Web OAuth with PKCE - uses ASWebAuthenticationSession (no deprecated APIs)
    @MainActor
    private func connectWithWebAuth() -> Bool {
        let codeVerifier = generateCodeVerifier()
        guard let codeChallenge = createCodeChallenge(from: codeVerifier) else {
            print("[Spotify] Failed to create code challenge")
            return false
        }
        let state = generateCodeVerifier()

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: spotifyClientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: spotifyRedirectURL.absoluteString),
            URLQueryItem(name: "scope", value: "user-read-private user-modify-playback-state"), // Search + play
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge)
        ]
        guard let authURL = components.url else {
            print("[Spotify] Failed to build auth URL")
            return false
        }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: spotifyRedirectURL.scheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                if let error {
                    print("[Spotify] Auth session error: \(error.localizedDescription)")
                    return
                }
                guard let callbackURL else {
                    print("[Spotify] No callback URL received")
                    return
                }
                self?.handlePKCECallback(url: callbackURL, codeVerifier: codeVerifier)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        let started = session.start()
        if !started {
            print("[Spotify] Failed to start auth session")
        }
        return started
    }

    private func handlePKCECallback(url: URL, codeVerifier: String) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            isFinishingAuth = true
            exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
        } else if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            print("[Spotify] Auth error: \(error)")
        }
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": spotifyRedirectURL.absoluteString,
            "client_id": spotifyClientID,
            "code_verifier": codeVerifier
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&").data(using: .utf8)

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                await MainActor.run {
                    self.isFinishingAuth = false
                    if let token = json?["access_token"] as? String {
                        self.accessToken = token
                        self.appRemote.connectionParameters.accessToken = token
                        if let refresh = json?["refresh_token"] as? String {
                            self.refreshToken = refresh
                        }
                        print("[Spotify] Successfully received access token via PKCE (saved to Keychain)")
                    } else if let error = json?["error"] as? String {
                        print("[Spotify] Token exchange error: \(error)")
                    }
                }
            } catch {
                await MainActor.run { self.isFinishingAuth = false }
                print("[Spotify] Token exchange failed: \(error)")
            }
        }
    }

    /// Refresh the access token using the saved refresh token
    @MainActor
    func refreshAccessTokenIfNeeded() async -> Bool {
        guard let refresh = refreshToken else { return false }
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": spotifyClientID
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let token = json?["access_token"] as? String {
                accessToken = token
                appRemote.connectionParameters.accessToken = token
                if let newRefresh = json?["refresh_token"] as? String {
                    refreshToken = newRefresh
                }
                print("[Spotify] Access token refreshed successfully")
                return true
            }
        } catch {
            print("[Spotify] Token refresh failed: \(error)")
        }
        return false
    }

    /// Play a track by URI (e.g. "spotify:track:..."). Opens in Spotify app if not connected.
    func play(trackUri: String) {
        guard !trackUri.isEmpty else { return }
        playURI = trackUri
        #if targetEnvironment(simulator)
        playbackError = "Playback requires a physical device with the Spotify app installed."
        return
        #endif
        if appRemote.isConnected {
            appRemote.playerAPI?.play(trackUri, callback: { [weak self] _, error in
                if let error {
                    print("[Spotify] Play failed: \(error.localizedDescription)")
                    Task { @MainActor in self?.playbackError = error.localizedDescription }
                } else {
                    Task { @MainActor in self?.playbackError = nil }
                }
            })
        } else {
            pendingPlayURI = trackUri
            if isAppRemoteConnecting {
                return // one connection already in progress; we'll play this track when it connects
            }
            isAppRemoteConnecting = true
            appRemote.connectionParameters.accessToken = accessToken
            appRemote.connect()
        }
    }

    /// URI to play when App Remote connects (e.g. after app launch)
    private var pendingPlayURI: String?

    /// True from connect() until we get connected or failed (avoids multiple connection attempts when user taps repeatedly).
    private var isAppRemoteConnecting = false

    /// Last playback error message for UI
    @Published var playbackError: String?

    /// Call when signing out / disconnecting to clear saved credentials
    func signOut() {
        accessToken = nil
        refreshToken = nil
        disconnect()
        print("[Spotify] Signed out, credentials cleared")
    }

    private func generateCodeVerifier() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return String((0..<64).map { _ in chars.randomElement()! })
    }

    private func createCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    func disconnect() {
        if appRemote.isConnected {
            appRemote.disconnect()
        }
    }
    
    func handleURL(_ url: URL) {
        print("[Spotify] handleURL received: \(url.absoluteString)")
        let parameters = appRemote.authorizationParameters(from: url)
        if let accessToken = parameters?[SPTAppRemoteAccessTokenKey] {
            self.accessToken = accessToken
            appRemote.connectionParameters.accessToken = accessToken
            print("[Spotify] Successfully received access token from Spotify app")
            #if !targetEnvironment(simulator)
            // Connect App Remote now so playback works without an extra tap.
            appRemote.connect()
            #endif
        } else if let errorDescription = parameters?[SPTAppRemoteErrorDescriptionKey] {
            print("[Spotify] Auth error: \(errorDescription)")
        } else {
            // May be Web PKCE callback (code=...) — handled by ASWebAuthenticationSession.
            print("[Spotify] handleURL called but no token or error in parameters")
        }
    }
}

// MARK: - SPTAppRemoteDelegate
extension SpotifyManager: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("[Spotify] App Remote connected")
        isConnected = true
        isAppRemoteConnecting = false
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { result, error in
            if let error { debugPrint(error.localizedDescription) }
        })
        // Play pending track if user tapped one before we were connected
        if let uri = pendingPlayURI, !uri.isEmpty {
            pendingPlayURI = nil
            appRemote.playerAPI?.play(uri, callback: { [weak self] _, playError in
                if let playError {
                    Task { @MainActor in self?.playbackError = playError.localizedDescription }
                }
            })
        }
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("disconnected")
        isConnected = false
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("failed")
        isConnected = false
        isAppRemoteConnecting = false
        let hadPendingPlay = pendingPlayURI != nil
        pendingPlayURI = nil
        if hadPendingPlay {
            Task { @MainActor in
                playbackError = "Open the Spotify app and try again."
            }
        }
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate
extension SpotifyManager: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        debugPrint("Track name: \(playerState.track.name)")
        currentTrackName = playerState.track.name
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension SpotifyManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
