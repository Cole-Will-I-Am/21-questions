// echo-api client: Bearer auth + a generic JSON helper. Echo's turns are plain JSON (no
// streaming), so this stays simple. Mirrors the Negotiator/RUNG Backend.
import Foundation

enum BackendError: Error, LocalizedError {
    case network
    case server(Int, String)
    case decode
    var errorDescription: String? {
        switch self {
        case .network: return "Network error."
        case .server(let code, let msg): return "Server error \(code): \(msg)"
        case .decode: return "Could not read the server's response."
        }
    }
}

private struct ErrorBody: Decodable { let error: String }

final class Backend {
    static let baseURLString = "https://echo-api.manticthink.com"
    private let session = URLSession.shared
    private func enc<E: Encodable>(_ v: E) -> Data { (try? JSONEncoder().encode(v)) ?? Data("{}".utf8) }

    private func send<R: Decodable>(_ path: String, method: String = "GET",
                                    token: String? = nil, bodyData: Data? = nil) async throws -> R {
        guard let url = URL(string: Backend.baseURLString + path) else { throw BackendError.network }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 60
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let bodyData {
            req.httpBody = bodyData
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw BackendError.network }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "http \(http.statusCode)"
            throw BackendError.server(http.statusCode, msg)
        }
        do { return try JSONDecoder().decode(R.self, from: data) }
        catch { throw BackendError.decode }
    }

    func registerAnon(deviceId: String, deviceSecret: String?) async throws -> AccountResponse {
        struct B: Encodable { let deviceId: String; let deviceSecret: String? }
        return try await send("/v1/account", method: "POST", bodyData: enc(B(deviceId: deviceId, deviceSecret: deviceSecret)))
    }

    func startSession(token: String, mode: String) async throws -> StartResponse {
        struct B: Encodable { let mode: String }
        return try await send("/v1/session/start", method: "POST", token: token, bodyData: enc(B(mode: mode)))
    }

    func answer(token: String, sessionId: String, answer: String) async throws -> AnswerResponse {
        struct B: Encodable { let sessionId: String; let answer: String }
        return try await send("/v1/session/answer", method: "POST", token: token,
                              bodyData: enc(B(sessionId: sessionId, answer: answer)))
    }

    func rate(token: String, sessionId: String, rating: Int) async throws {
        struct B: Encodable { let sessionId: String; let rating: Int }
        struct R: Decodable { let saved: Bool }
        let _: R = try await send("/v1/session/rate", method: "POST", token: token,
                                  bodyData: enc(B(sessionId: sessionId, rating: rating)))
    }
}
