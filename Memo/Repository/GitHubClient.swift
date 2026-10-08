//
//  GitHubClient.swift
//  Memo
//
//  GitHub over its REST API. No git and no SSH: reading and writing a handful
//  of JSON files needs neither, and the API does it with nothing but HTTPS.
//

import Foundation

enum GitHubFailure: LocalizedError, Equatable {

    case notSignedIn
    case unauthorized
    case notFound
    case outOfDate
    case signInExpired
    case signInDenied
    case service(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            String(localized: "Sign in to GitHub in Settings first.")
        case .unauthorized:
            String(localized: "GitHub did not accept the sign-in. Sign out and in again in Settings.")
        case .notFound:
            String(localized: "The repository could not be found, or this account cannot see it.")
        case .outOfDate:
            String(localized: "The repository changed while you were looking at it. Refresh and try again.")
        case .signInExpired:
            String(localized: "The code expired before it was used. Start the sign-in again.")
        case .signInDenied:
            String(localized: "The sign-in was cancelled on GitHub.")
        case .service(let message):
            String(localized: "GitHub reported a problem. \(message)")
        case .network(let message):
            String(localized: "GitHub could not be reached. \(message)")
        }
    }
}

/// What GitHub hands back to start a sign-in: a code for the user to type on
/// github.com, and one for the app to ask about.
struct GitHubDeviceCode: Equatable {
    var deviceCode: String
    var userCode: String
    var verificationURL: URL
    var interval: TimeInterval
    var expiresAt: Date
}

struct GitHubRepository: Identifiable, Hashable {
    var fullName: String
    var isPrivate: Bool

    var id: String { fullName }
}

/// A file or folder in a repository's listing.
struct GitHubEntry: Equatable {
    var path: String
    /// What a later write must quote to prove it saw this version.
    var sha: String
    var isFile: Bool
}

/// The part of GitHub that syncing uses, so it can be tested without it.
protocol GitHubFiles {

    /// The entries at the root, or `nil` if the repository has no commits yet.
    func entries(in repository: String, token: String) async throws -> [GitHubEntry]?

    func contents(of path: String, in repository: String, token: String) async throws -> Data

    /// Creates the file, or replaces the version identified by `sha`.
    func write(
        _ data: Data,
        to path: String,
        replacing sha: String?,
        message: String,
        in repository: String,
        token: String
    ) async throws
}

struct GitHubClient: GitHubFiles {

    private static let api = URL(string: "https://api.github.com")!
    private static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private static let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!

    /// Read and write access to the user's repositories, which is the least
    /// an OAuth app can ask for and still write to a private one.
    private static let scope = "repo"

    // MARK: - Signing in

    /// Starts the device flow: no password is typed into the app, and no
    /// redirect back to it is needed.
    func requestDeviceCode(clientID: String) async throws -> GitHubDeviceCode {
        let request = Self.formRequest(
            to: Self.deviceCodeURL,
            fields: ["client_id": clientID, "scope": Self.scope]
        )
        let object = try Self.object(in: try await Self.send(request))

        guard let deviceCode = object["device_code"] as? String,
              let userCode = object["user_code"] as? String,
              let address = object["verification_uri"] as? String,
              let url = URL(string: address)
        else { throw GitHubFailure.service(Self.message(in: object) ?? "") }

        return GitHubDeviceCode(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURL: url,
            interval: object["interval"] as? TimeInterval ?? 5,
            expiresAt: Date().addingTimeInterval(object["expires_in"] as? TimeInterval ?? 900)
        )
    }

    /// Waits for the user to approve on github.com, and returns the token.
    func waitForToken(clientID: String, code: GitHubDeviceCode) async throws -> String {
        var interval = code.interval

        while Date() < code.expiresAt {
            try await Task.sleep(for: .seconds(interval))

            let request = Self.formRequest(to: Self.tokenURL, fields: [
                "client_id": clientID,
                "device_code": code.deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ])

            switch Self.pollResult(from: try await Self.send(request)) {
            case .token(let token): return token
            case .pending:          continue
            case .slowDown:         interval += 5
            case .failed(let failure): throw failure
            }
        }

        throw GitHubFailure.signInExpired
    }

    enum PollResult: Equatable {
        case token(String)
        case pending
        case slowDown
        case failed(GitHubFailure)
    }

    /// GitHub answers every poll with 200; what happened is in the body.
    static func pollResult(from data: Data) -> PollResult {
        let object = (try? Self.object(in: data)) ?? [:]

        if let token = object["access_token"] as? String { return .token(token) }

        switch object["error"] as? String {
        case "authorization_pending": return .pending
        case "slow_down":             return .slowDown
        case "expired_token":         return .failed(.signInExpired)
        case "access_denied":         return .failed(.signInDenied)
        default:
            return .failed(.service(object["error_description"] as? String ?? ""))
        }
    }

    // MARK: - Account

    func login(token: String) async throws -> String {
        let object = try Self.object(in: try await Self.send(Self.apiRequest("user", token: token)))
        return object["login"] as? String ?? ""
    }

    /// The repositories the account can write to, most recently used first.
    /// One page: a hundred is more than a picker can usefully show.
    func repositories(token: String) async throws -> [GitHubRepository] {
        let request = Self.apiRequest(
            "user/repos",
            query: ["per_page": "100", "sort": "updated"],
            token: token
        )
        let list = try JSONSerialization.jsonObject(with: try await Self.send(request)) as? [[String: Any]]

        return (list ?? []).compactMap { item in
            guard let name = item["full_name"] as? String else { return nil }

            let permissions = item["permissions"] as? [String: Any]
            guard permissions?["push"] as? Bool ?? false else { return nil }

            return GitHubRepository(fullName: name, isPrivate: item["private"] as? Bool ?? false)
        }
    }

    // MARK: - Files

    func entries(in repository: String, token: String) async throws -> [GitHubEntry]? {
        let request = Self.apiRequest("repos/\(repository)/contents", token: token)

        do {
            return Self.entries(from: try await Self.send(request))
        } catch GitHubFailure.service(let message) where Self.saysEmpty(message) {
            return nil
        }
    }

    static func entries(from data: Data) -> [GitHubEntry] {
        let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []

        return list.compactMap { item in
            guard let path = item["path"] as? String, let sha = item["sha"] as? String else { return nil }
            return GitHubEntry(path: path, sha: sha, isFile: item["type"] as? String == "file")
        }
    }

    /// A repository with no commits answers its listing with a 404 that says
    /// so, which is the only thing telling it apart from one that is missing.
    static func saysEmpty(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("repository is empty")
    }

    func contents(of path: String, in repository: String, token: String) async throws -> Data {
        var request = Self.apiRequest("repos/\(repository)/contents/\(path)", token: token)
        // The file itself rather than a JSON wrapper around a base64 copy.
        request.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")

        return try await Self.send(request)
    }

    func write(
        _ data: Data,
        to path: String,
        replacing sha: String?,
        message: String,
        in repository: String,
        token: String
    ) async throws {
        _ = try await Self.send(
            try Self.writeRequest(data, to: path, replacing: sha, message: message, in: repository, token: token)
        )
    }

    static func writeRequest(
        _ data: Data,
        to path: String,
        replacing sha: String?,
        message: String,
        in repository: String,
        token: String
    ) throws -> URLRequest {
        var body: [String: Any] = [
            "message": message,
            "content": data.base64EncodedString(),
        ]
        if let sha { body["sha"] = sha }

        var request = apiRequest("repos/\(repository)/contents/\(path)", token: token)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return request
    }

    // MARK: - Requests

    static func apiRequest(_ path: String, query: [String: String] = [:], token: String) -> URLRequest {
        // Appended a component at a time, so a space or an emoji in a deck's
        // file name is escaped and a slash in the path stays a slash.
        var url = api
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
        }

        if !query.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = query.sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
            url = components.url ?? url
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return request
    }

    private static func formRequest(to url: URL, fields: [String: String]) -> URLRequest {
        var components = URLComponents()
        components.queryItems = fields.sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        return request
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw GitHubFailure.network(error.localizedDescription)
        }

        guard let status = (response as? HTTPURLResponse)?.statusCode else { return data }

        switch status {
        case 200..<300:
            return data
        case 401:
            throw GitHubFailure.unauthorized
        case 409, 422:
            // A write that quoted a version the file has moved on from.
            throw GitHubFailure.outOfDate
        default:
            let object = (try? Self.object(in: data)) ?? [:]
            let message = Self.message(in: object) ?? String(localized: "Status \(status).")

            // A missing repository and an empty one are both a 404; only the
            // message tells them apart, so it has to survive.
            if status == 404, !saysEmpty(message) { throw GitHubFailure.notFound }
            throw GitHubFailure.service(message)
        }
    }

    private static func object(in data: Data) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private static func message(in object: [String: Any]) -> String? {
        object["message"] as? String ?? object["error_description"] as? String
    }
}
