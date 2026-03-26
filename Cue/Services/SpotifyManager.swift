import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import Combine
import SpotifyiOS
import UIKit

class SpotifyManager: NSObject, ObservableObject {
    static let shared = SpotifyManager()

    private let keychainService = "com.cue.spotify"
    private var currentUserUID: String?

    /// Single source of truth: user has valid Spotify credentials
    var isAuthenticated: Bool {
        (accessToken != nil || apiAccessToken != nil) && !isFinishingAuth
    }

    private func keychainKey(_ base: String) -> String? {
        guard let uid = currentUserUID else { return nil }
        return "\(base)_\(uid)"
    }

    let spotifyClientID = "93c38381b8ff4b7d984fa217cbb3dcd3"
    let spotifyRedirectURL = URL(string: "spotify-ios-quick-start://spotify-login-callback")!

    @Published var isConnected = false
    @Published var currentTrackName = ""
    @Published var currentArtistName = ""
    @Published var currentArtwork: UIImage?
    @Published var isPaused = true
    @Published var nextTrackTitle = ""
    @Published var currentTrackRemainingSeconds = 0
    @Published var currentTrackURI = ""
    /// True while exchanging auth code for token (user returned from browser but token not ready yet)
    @Published var isFinishingAuth = false
    @Published var accessToken: String? {
        didSet {
            appRemote.connectionParameters.accessToken = accessToken
            guard let key = keychainKey("spotify_access_token") else { return }
            if let token = accessToken {
                KeychainHelper.save(key: key, value: token, service: keychainService)
            } else {
                KeychainHelper.delete(key: key, service: keychainService)
            }
        }
    }
    private var refreshToken: String? {
        didSet {
            guard let key = keychainKey("spotify_refresh_token") else { return }
            if let token = refreshToken {
                KeychainHelper.save(key: key, value: token, service: keychainService)
            } else {
                KeychainHelper.delete(key: key, service: keychainService)
            }
        }
    }

    /// Token with playlist scopes (from PKCE). Used for Web API: create playlist, add tracks, /me. App Remote only accepts token from Spotify app.
    @Published var apiAccessToken: String? {
        didSet {
            guard let key = keychainKey("spotify_api_access_token") else { return }
            if let token = apiAccessToken {
                KeychainHelper.save(key: key, value: token, service: keychainService)
            } else {
                KeychainHelper.delete(key: key, service: keychainService)
            }
        }
    }
    private var apiRefreshToken: String? {
        didSet {
            guard let key = keychainKey("spotify_api_refresh_token") else { return }
            if let token = apiRefreshToken {
                KeychainHelper.save(key: key, value: token, service: keychainService)
            } else {
                KeychainHelper.delete(key: key, service: keychainService)
            }
        }
    }

    override init() {
        super.init()
        // Observe Firebase auth state — load tokens for the signed-in user, or clear on sign-out.
        // Only clear when a previously signed-in user signs out (not during onboarding when no user exists yet).
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let uid = user?.uid {
                self?.loadTokens(for: uid)
            } else if self?.currentUserUID != nil {
                // User was signed in and now isn't → actual sign-out
                self?.clearInMemoryState()
            }
        }
    }

    /// Token to use for Web API (playlists, /me). Prefer API token (has playlist scopes); fallback to main token.
    var tokenForWebAPI: String? { apiAccessToken ?? accessToken }

    /// Token that has playlist-read scope. Prefer API token; fall back to main token if it came from PKCE (has refresh token = full scopes).
    var tokenForPlaylistRead: String? { apiAccessToken ?? (refreshToken != nil ? accessToken : nil) }
    
    var playURI = ""
    private let webAPIBaseURL = "https://api.spotify.com/v1"
    
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
    
    /// Connect: on device use Spotify app (playback works); on simulator use Web PKCE. Use grantPlaylistAccess() for playlist creation on device.
    @MainActor
    @discardableResult
    func connect() -> Bool {
        #if targetEnvironment(simulator)
        print("[Spotify] Simulator: using web PKCE (search only; no playback).")
        return connectWithWebAuth()
        #else
        // If we already have a token, prefer a direct App Remote connect.
        // This matches the expected "Link Spotify app" behavior and avoids unnecessary re-authorization.
        if accessToken != nil {
            let didConnect = connectAppRemoteIfNeeded()
            if didConnect { return true }
        }

        print("[Spotify] Opening Spotify app to connect (playback). For creating playlists, tap \"Allow creating playlists\" after connecting.")
        // App Remote playback/control needs app-remote-control. We also request playback scopes for state/control.
        let scopes = ["app-remote-control", "user-read-playback-state", "user-modify-playback-state", "user-read-private"]
        appRemote.authorizeAndPlayURI("", asRadio: false, additionalScopes: scopes, sessionIdentifier: nil)
        return true
        #endif
    }

    /// Device-only: open Spotify app and immediately start playing the given URI.
    /// This matches the "Link Spotify app" flow and avoids Web API "No active device found".
    @MainActor
    @discardableResult
    func connectAndPlay(uri: String) -> Bool {
        guard let normalizedURI = normalizedContextURI(from: uri) else { return connect() }
        #if targetEnvironment(simulator)
        print("[Spotify] Simulator: playback requires a physical device.")
        playbackError = "Playback requires a physical device with the Spotify app installed."
        return false
        #else
        print("[Spotify] Opening Spotify app to play URI: \(normalizedURI)")
        let scopes = ["app-remote-control", "user-read-playback-state", "user-modify-playback-state", "user-read-private"]
        appRemote.authorizeAndPlayURI(normalizedURI, asRadio: false, additionalScopes: scopes, sessionIdentifier: nil)
        return true
        #endif
    }

    /// Start a workout playlist. If App Remote is not connected yet, we open Spotify and start playback via App Remote.
    func startWorkoutPlaylist(playlistUri: String) {
        guard !playlistUri.isEmpty else { return }
        #if targetEnvironment(simulator)
        playbackError = "Playback requires a physical device with the Spotify app installed."
        return
        #endif

        if appRemote.isConnected {
            playPlaylistFromStart(playlistUri: playlistUri)
        } else {
            Task { @MainActor in _ = connectAndPlay(uri: playlistUri) }
        }
    }

    /// Run Web PKCE and store token as API token (playlist scopes). Call this on device after connect() to enable create playlist. On simulator we already use PKCE for connect() so this is no-op.
    @MainActor
    @discardableResult
    func grantPlaylistAccess() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return connectWithWebAuth(forPlaylistScopesOnly: true)
        #endif
    }

    /// Onboarding connect: use Web PKCE (full scopes including playlist read).
    /// Unlike connect(), this never uses App Remote — it authenticates via browser.
    /// On device: stores as apiAccessToken so tokenForPlaylistRead works.
    /// On simulator: stores as accessToken (main token, same as connect()).
    @MainActor
    @discardableResult
    func connectForOnboarding() -> Bool {
        #if targetEnvironment(simulator)
        return connectWithWebAuth(forPlaylistScopesOnly: false)
        #else
        return connectWithWebAuth(forPlaylistScopesOnly: true)
        #endif
    }

    /// Web OAuth with PKCE. Simulator: forPlaylistScopesOnly false (main connect). Device: forPlaylistScopesOnly true (store as API token only).
    @MainActor
    private func connectWithWebAuth(forPlaylistScopesOnly: Bool = false) -> Bool {
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
            URLQueryItem(name: "scope", value: "user-read-private user-read-playback-state user-modify-playback-state playlist-modify-public playlist-modify-private playlist-read-private playlist-read-collaborative"),
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
                self?.handlePKCECallback(url: callbackURL, codeVerifier: codeVerifier, forPlaylistScopesOnly: forPlaylistScopesOnly)
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

    private func handlePKCECallback(url: URL, codeVerifier: String, forPlaylistScopesOnly: Bool = false) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            if forPlaylistScopesOnly {
                exchangeCodeForApiToken(code: code, codeVerifier: codeVerifier)
            } else {
                isFinishingAuth = true
                exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
            }
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

    private func exchangeCodeForApiToken(code: String, codeVerifier: String) {
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
                    if let token = json?["access_token"] as? String {
                        self.apiAccessToken = token
                        if let refresh = json?["refresh_token"] as? String {
                            self.apiRefreshToken = refresh
                        }
                        print("[Spotify] Playlist access granted (API token saved)")
                    } else if let error = json?["error"] as? String {
                        print("[Spotify] API token exchange error: \(error)")
                    }
                }
            } catch {
                print("[Spotify] API token exchange failed: \(error)")
            }
        }
    }

    /// Refresh the access token using the saved refresh token (main token, used on simulator).
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

    /// Refresh the API token (playlist scopes). Use when Web API returns 401 and we have apiRefreshToken.
    @MainActor
    func refreshApiAccessTokenIfNeeded() async -> Bool {
        guard let refresh = apiRefreshToken else { return false }
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
                apiAccessToken = token
                if let newRefresh = json?["refresh_token"] as? String {
                    apiRefreshToken = newRefresh
                }
                print("[Spotify] API token refreshed successfully")
                return true
            }
        } catch {
            print("[Spotify] API token refresh failed: \(error)")
        }
        return false
    }

    /// Refresh the token used for Web API (playlists, /me). Tries API refresh first if we have API credentials.
    @MainActor
    func refreshWebAPITokenIfNeeded() async -> Bool {
        if apiRefreshToken != nil {
            return await refreshApiAccessTokenIfNeeded()
        }
        return await refreshAccessTokenIfNeeded()
    }

    /// Clear the credentials used for Web API when refresh fails (so UI can show "sign in again").
    /// Only clears tokens that have a corresponding refresh token (i.e., from PKCE flow).
    /// Never clears an App Remote–only access token (no refresh token) since Web API 401s are expected for it.
    func clearWebAPICredentialsOnRefreshFailure() {
        if apiRefreshToken != nil {
            apiAccessToken = nil
            apiRefreshToken = nil
        } else if refreshToken != nil {
            accessToken = nil
            refreshToken = nil
        }
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

    /// Ensure App Remote is connected so we can control playback + receive player state updates.
    @discardableResult
    func connectAppRemoteIfNeeded() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard accessToken != nil else { return false }
        guard !appRemote.isConnected else { return true }
        guard !isAppRemoteConnecting else { return false }
        isAppRemoteConnecting = true
        appRemote.connectionParameters.accessToken = accessToken
        appRemote.connect()
        return false
        #endif
    }

    func nextTrack() {
        #if targetEnvironment(simulator)
        playbackError = "Playback requires a physical device with the Spotify app installed."
        return
        #endif
        guard appRemote.isConnected else {
            pendingPlaybackCommand = .next
            connectAppRemoteIfNeeded()
            playbackError = "Connecting to Spotify…"
            return
        }
        appRemote.playerAPI?.skip(toNext: { [weak self] _, error in
            Task { @MainActor in
                if let error { self?.playbackError = error.localizedDescription }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self?.requestAppRemotePlayerStateNow()
            }
        })
    }

    func previousTrack() {
        #if targetEnvironment(simulator)
        playbackError = "Playback requires a physical device with the Spotify app installed."
        return
        #endif
        guard appRemote.isConnected else {
            pendingPlaybackCommand = .previous
            connectAppRemoteIfNeeded()
            playbackError = "Connecting to Spotify…"
            return
        }
        appRemote.playerAPI?.skip(toPrevious: { [weak self] _, error in
            Task { @MainActor in
                if let error { self?.playbackError = error.localizedDescription }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self?.requestAppRemotePlayerStateNow()
            }
        })
    }

    func pausePlayback() {
        #if targetEnvironment(simulator)
        return
        #endif
        guard appRemote.isConnected, !isPaused else { return }
        appRemote.playerAPI?.pause({ _, _ in })
    }

    func togglePlayPause() {
        #if targetEnvironment(simulator)
        playbackError = "Playback requires a physical device with the Spotify app installed."
        return
        #endif
        guard appRemote.isConnected else {
            pendingPlaybackCommand = .togglePlayPause
            connectAppRemoteIfNeeded()
            playbackError = "Connecting to Spotify…"
            return
        }
        if isPaused {
            appRemote.playerAPI?.resume({ [weak self] _, error in
                Task { @MainActor in
                    if let error { self?.playbackError = error.localizedDescription }
                    else { self?.playbackError = nil }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.requestAppRemotePlayerStateNow()
                }
            })
        } else {
            appRemote.playerAPI?.pause({ [weak self] _, error in
                Task { @MainActor in
                    if let error { self?.playbackError = error.localizedDescription }
                    else { self?.playbackError = nil }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.requestAppRemotePlayerStateNow()
                }
            })
        }
    }

    /// Play a playlist from the beginning. Prefers Web API (supports offset position 0), falls back to App Remote play(uri).
    func playPlaylistFromStart(playlistUri: String) {
        guard let normalizedURI = normalizedContextURI(from: playlistUri) else { return }
        #if targetEnvironment(simulator)
        playbackError = "Playback requires a physical device with the Spotify app installed."
        return
        #endif

        Task { @MainActor in
            do {
                // Spotify remembers shuffle state per device; explicitly disable it so order matches the playlist.
                try? await setShuffleViaWebAPI(false)
                try await playContextFromStartViaWebAPI(contextUri: normalizedURI)
                playbackError = nil
            } catch {
                // If Web API playback fails (e.g. no active device), explicitly open/link Spotify app and play context.
                print("[Spotify] Web API play failed, falling back to App Remote: \(error)")
                _ = self.connectAndPlay(uri: normalizedURI)
            }
        }
    }

    /// Fetch the next track in the user's playback queue via Web API and update `nextTrackTitle`.
    func refreshNextTrackFromQueue() {
        Task {
            guard let token = tokenForWebAPI else { return }
            var request = URLRequest(url: URL(string: "\(webAPIBaseURL)/me/player/queue")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

                if statusCode == 401 {
                    let refreshed = await refreshWebAPITokenIfNeeded()
                    if refreshed {
                        refreshNextTrackFromQueue()
                        return
                    }
                    await MainActor.run { self.clearWebAPICredentialsOnRefreshFailure() }
                    return
                }

                guard statusCode == 200 else {
                    return
                }

                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let queue = json?["queue"] as? [[String: Any]]
                let next = queue?.first
                let name = next?["name"] as? String ?? ""

                await MainActor.run {
                    self.nextTrackTitle = name
                }
            } catch {
                // Ignore errors; UI will simply not show an up-next title.
            }
        }
    }

    /// Queue can lag briefly right after track/context changes; refresh a few times.
    func refreshQueueWithBurst() {
        queueRefreshBurstTask?.cancel()
        queueRefreshBurstTask = Task { [weak self] in
            guard let self else { return }
            self.refreshNextTrackFromQueue()
            try? await Task.sleep(nanoseconds: 350_000_000)
            self.refreshNextTrackFromQueue()
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.refreshNextTrackFromQueue()
        }
    }

    private func setShuffleViaWebAPI(_ enabled: Bool) async throws {
        guard let token = tokenForWebAPI else { throw NSError(domain: "Spotify", code: 401) }
        var components = URLComponents(string: "\(webAPIBaseURL)/me/player/shuffle")!
        components.queryItems = [URLQueryItem(name: "state", value: enabled ? "true" : "false")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if statusCode == 401 {
            let refreshed = await refreshWebAPITokenIfNeeded()
            if refreshed {
                try await setShuffleViaWebAPI(enabled)
                return
            }
            await MainActor.run { self.clearWebAPICredentialsOnRefreshFailure() }
            throw NSError(domain: "Spotify", code: 401)
        }
        guard statusCode == 204 else {
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            let message = (json?["error"] as? [String: Any])?["message"] as? String
            throw NSError(domain: "Spotify", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message ?? "HTTP \(statusCode)"])
        }
    }

    /// Accepts spotify URI, playlist ID, or open.spotify.com playlist URL and returns context URI.
    private func normalizedContextURI(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("spotify:playlist:") {
            return trimmed
        }

        if let url = URL(string: trimmed), let host = url.host?.lowercased(), host.contains("spotify.com") {
            let components = url.pathComponents.filter { $0 != "/" }
            if let idx = components.firstIndex(of: "playlist"), idx + 1 < components.count {
                return "spotify:playlist:\(components[idx + 1])"
            }
        }

        if !trimmed.contains(":") && !trimmed.contains("/") {
            return "spotify:playlist:\(trimmed)"
        }

        return nil
    }

    private func playContextFromStartViaWebAPI(contextUri: String) async throws {
        guard let token = tokenForWebAPI else { throw NSError(domain: "Spotify", code: 401) }
        var request = URLRequest(url: URL(string: "\(webAPIBaseURL)/me/player/play")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "context_uri": contextUri,
            "offset": ["position": 0],
            "position_ms": 0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        if statusCode == 401 {
            let refreshed = await refreshWebAPITokenIfNeeded()
            if refreshed {
                try await playContextFromStartViaWebAPI(contextUri: contextUri)
                return
            }
            await MainActor.run { self.clearWebAPICredentialsOnRefreshFailure() }
            throw NSError(domain: "Spotify", code: 401)
        }
        guard statusCode == 204 else {
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            let message = (json?["error"] as? [String: Any])?["message"] as? String
            throw NSError(domain: "Spotify", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message ?? "HTTP \(statusCode)"])
        }
    }

    /// URI to play when App Remote connects (e.g. after app launch)
    private var pendingPlayURI: String?

    /// True from connect() until we get connected or failed (avoids multiple connection attempts when user taps repeatedly).
    private var isAppRemoteConnecting = false
    
    private enum PendingPlaybackCommand {
        case togglePlayPause
        case next
        case previous
    }
    private var pendingPlaybackCommand: PendingPlaybackCommand?

    /// Last playback error message for UI
    @Published var playbackError: String?
    private var playbackSyncTask: Task<Void, Never>?
    private var lastProgressMS: Int = 0
    private var lastDurationMS: Int = 0
    private var isRefreshingPlaybackSnapshot = false
    private var lastArtworkTrackURI: String?
    private var queueRefreshBurstTask: Task<Void, Never>?
    private var lastLocalProgressUpdateAt: Date?

    /// Explicitly disconnect Spotify — clears Keychain tokens for this user.
    /// Called when the user intentionally wants to unlink Spotify from their account.
    func signOut() {
        // nil tokens while currentUserUID is still set → didSets delete from Keychain
        accessToken = nil
        refreshToken = nil
        apiAccessToken = nil
        apiRefreshToken = nil
        currentUserUID = nil
        disconnect()
        print("[Spotify] Signed out, credentials cleared")
    }

    /// Load tokens from Keychain for the given Firebase UID. Called automatically on Cue sign-in.
    func loadTokens(for uid: String) {
        currentUserUID = uid
        // Persist any in-memory tokens from account creation PKCE flow (set before UID existed)
        if let t = accessToken { KeychainHelper.save(key: "spotify_access_token_\(uid)", value: t, service: keychainService) }
        if let t = refreshToken { KeychainHelper.save(key: "spotify_refresh_token_\(uid)", value: t, service: keychainService) }
        if let t = apiAccessToken { KeychainHelper.save(key: "spotify_api_access_token_\(uid)", value: t, service: keychainService) }
        if let t = apiRefreshToken { KeychainHelper.save(key: "spotify_api_refresh_token_\(uid)", value: t, service: keychainService) }
        // Load from Keychain only if nothing is already in memory
        if accessToken == nil && apiAccessToken == nil {
            accessToken = KeychainHelper.load(key: "spotify_access_token_\(uid)", service: keychainService)
            refreshToken = KeychainHelper.load(key: "spotify_refresh_token_\(uid)", service: keychainService)
            apiAccessToken = KeychainHelper.load(key: "spotify_api_access_token_\(uid)", service: keychainService)
            apiRefreshToken = KeychainHelper.load(key: "spotify_api_refresh_token_\(uid)", service: keychainService)
        }
        print("[Spotify] Tokens loaded for user \(uid), authenticated: \(isAuthenticated)")
    }

    /// Clear in-memory Spotify state on Cue sign-out. Preserves Keychain so tokens reload on next sign-in.
    func clearInMemoryState() {
        currentUserUID = nil  // Must come first — keychainKey() returns nil → didSets skip Keychain deletion
        accessToken = nil
        refreshToken = nil
        apiAccessToken = nil
        apiRefreshToken = nil
        disconnect()
        print("[Spotify] In-memory state cleared (Keychain preserved for re-login)")
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
        isAppRemoteConnecting = false
        stopPlaybackSyncLoop()
    }

    func startPlaybackSyncLoop() {
        if playbackSyncTask != nil { return }
        playbackSyncTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshPlaybackSnapshot()
                // Periodic correction from Spotify Web API.
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    func stopPlaybackSyncLoop() {
        playbackSyncTask?.cancel()
        playbackSyncTask = nil
    }

    func tickPlaybackProgress() {
        // Lightweight in-app ticking for smoother UI while the workout screen is visible.
        // Source of truth still comes from Spotify snapshots and App Remote events.
        guard !isPaused else { return }
        guard currentTrackRemainingSeconds > 0 else { return }
        let now = Date()
        let lastTick = lastLocalProgressUpdateAt ?? now
        let elapsed = max(0, now.timeIntervalSince(lastTick))
        // Use real elapsed time instead of assuming perfect 1s timer cadence.
        let elapsedMS = Int(elapsed * 1000)
        guard elapsedMS > 0 else { return }
        lastLocalProgressUpdateAt = now

        lastProgressMS = min(lastDurationMS, lastProgressMS + elapsedMS)
        // Round up so we don't look behind Spotify near second boundaries.
        let remaining = max(0, Int(ceil(Double(lastDurationMS - lastProgressMS) / 1000.0)))
        currentTrackRemainingSeconds = remaining

        if currentTrackRemainingSeconds == 0 {
            // Force immediate rollover sync when a track ends.
            requestAppRemotePlayerStateNow()
            refreshQueueWithBurst()
            refreshPlaybackStateNow()
        }
    }

    func refreshPlaybackStateNow() {
        Task { [weak self] in
            await self?.refreshPlaybackSnapshot()
        }
    }

    func requestAppRemotePlayerStateNow() {
        appRemote.playerAPI?.getPlayerState({ [weak self] result, error in
            if let error {
                print("[Spotify] getPlayerState failed: \(error.localizedDescription)")
                return
            }
            if let state = result as? SPTAppRemotePlayerState {
                self?.updateFromPlayerState(state)
                self?.refreshQueueWithBurst()
            }
        })
    }

    private func refreshPlaybackSnapshot() async {
        if isRefreshingPlaybackSnapshot { return }
        isRefreshingPlaybackSnapshot = true
        defer { isRefreshingPlaybackSnapshot = false }
        guard let token = tokenForWebAPI else { return }
        var request = URLRequest(url: URL(string: "\(webAPIBaseURL)/me/player")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            if statusCode == 401 {
                let refreshed = await refreshWebAPITokenIfNeeded()
                if refreshed {
                    await refreshPlaybackSnapshot()
                    return
                }
                await MainActor.run { self.clearWebAPICredentialsOnRefreshFailure() }
                return
            }

            guard statusCode == 200 else { return }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            let isPlaying = (json["is_playing"] as? Bool) ?? false
            let progressMS = (json["progress_ms"] as? Int) ?? 0
            let item = json["item"] as? [String: Any]
            let trackName = item?["name"] as? String ?? ""
            let trackURI = item?["uri"] as? String ?? ""
            let durationMS = item?["duration_ms"] as? Int ?? 0
            let artists = item?["artists"] as? [[String: Any]]
            let artistName = artists?.first?["name"] as? String ?? ""
            let album = item?["album"] as? [String: Any]
            let images = album?["images"] as? [[String: Any]]
            let artworkURLString = images?.first?["url"] as? String

            let remaining = max(0, Int(ceil(Double(durationMS - progressMS) / 1000.0)))

            await MainActor.run {
                let trackDidChange = self.currentTrackURI != trackURI && !trackURI.isEmpty
                self.currentTrackName = trackName
                self.currentTrackURI = trackURI
                self.currentArtistName = artistName
                self.isPaused = !isPlaying
                self.currentTrackRemainingSeconds = remaining
                self.lastProgressMS = progressMS
                self.lastDurationMS = durationMS
                self.lastLocalProgressUpdateAt = Date()
                if trackDidChange {
                    self.refreshQueueWithBurst()
                }
            }

            if let artworkURLString, let url = URL(string: artworkURLString) {
                do {
                    let (imgData, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: imgData) {
                        await MainActor.run {
                            self.currentArtwork = image
                        }
                    }
                } catch {
                    // Ignore artwork fetch errors.
                }
            }

            refreshQueueWithBurst()
        } catch {
            // Ignore snapshot errors; next loop tick can recover.
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
        Task { @MainActor in
            self.isConnected = true
            self.isAppRemoteConnecting = false
        }
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { result, error in
            if let error { debugPrint(error.localizedDescription) }
        })
        // Fetch initial state immediately (subscribe only delivers changes).
        appRemote.playerAPI?.getPlayerState({ [weak self] result, error in
            if let error {
                print("[Spotify] getPlayerState failed: \(error.localizedDescription)")
                return
            }
            if let state = result as? SPTAppRemotePlayerState {
                self?.updateFromPlayerState(state)
            }
        })
        startPlaybackSyncLoop()

        if let cmd = pendingPlaybackCommand {
            pendingPlaybackCommand = nil
            switch cmd {
            case .togglePlayPause:
                togglePlayPause()
            case .next:
                nextTrack()
            case .previous:
                previousTrack()
            }
        }
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
        Task { @MainActor in
            self.isConnected = false
        }
        stopPlaybackSyncLoop()
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("failed")
        Task { @MainActor in
            self.isConnected = false
            self.isAppRemoteConnecting = false
        }
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
        updateFromPlayerState(playerState)
        refreshNextTrackFromQueue()
    }
}

private extension SpotifyManager {
    func updateFromPlayerState(_ state: SPTAppRemotePlayerState) {
        // Placeholder states can appear briefly around transitions; pull a fresh snapshot instead.
        if state.track.name == "--" {
            refreshPlaybackStateNow()
            return
        }

        Task { @MainActor in
            self.currentTrackName = state.track.name
            self.currentTrackURI = state.track.uri
            self.currentArtistName = state.track.artist.name
            self.isPaused = state.isPaused
        }

        // Avoid repeated image fetches for duplicate player-state events on same track.
        guard lastArtworkTrackURI != state.track.uri else { return }
        lastArtworkTrackURI = state.track.uri

        appRemote.imageAPI?.fetchImage(forItem: state.track, with: CGSize(width: 64, height: 64), callback: { [weak self] image, error in
            if let error {
                print("[Spotify] fetchImage failed: \(error.localizedDescription)")
                return
            }
            guard let uiImage = image as? UIImage else { return }
            Task { @MainActor in
                self?.currentArtwork = uiImage
            }
        })
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
