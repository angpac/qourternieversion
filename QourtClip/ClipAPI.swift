//
//  ClipAPI.swift
//  QourtClip
//
//  Talks to the same `guest_*` Postgres functions the web guest client
//  calls, over plain URLSession rather than the Supabase SDK.
//
//  Two reasons for hand-rolling it. An App Clip has a hard uncompressed
//  size budget and the SDK is the single biggest thing we could drag in;
//  and none of what the SDK provides is needed here — the guest flow is
//  unauthenticated (anon key only), and the web client already polls for
//  updates rather than using Realtime, so there is no socket to manage.
//

import Foundation

enum ClipAPI {
    static let supabaseURL = URL(string: "https://izanyjrbgguidttflpvp.supabase.co")!
    static let anonKey = "sb_publishable_Jlrs6NAUoAb5uUBl_XO6Gg_QQ0LGtwq"

    /// Raised with the message Postgres sent back, so a guest sees "This
    /// game has ended" rather than "the server returned 400".
    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }

        /// The guest's session token no longer resolves - the game was
        /// deleted, or the row was cleaned up. Distinct from a network
        /// blip, because the only recovery is to join again rather than
        /// retry. Matches the `raise ... using errcode = 'P0002'` in
        /// `guest_status` and friends.
        var isSessionGone: Bool {
            message.localizedCaseInsensitiveContains("session not found")
        }
    }

    /// The polling loop runs every 2 seconds, so a request left on the
    /// default 60-second timeout would stall updates for half a minute on
    /// a flaky gym wifi. Fifteen seconds is well past a normal round trip
    /// and still recovers quickly.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    private struct PostgresError: Decodable {
        let message: String?
        let hint: String?
        let details: String?
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            // Postgres timestamptz comes back with a variable number of
            // fractional-second digits; ISO8601DateFormatter is all-or-
            // nothing about them, so try both spellings.
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: text) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Unrecognised date: \(text)"
            )
        }
        return decoder
    }()

    /// Calls a `security definer` RPC as the anon role.
    static func rpc<T: Decodable>(
        _ function: String,
        body: [String: Any],
        as type: T.Type
    ) async throws -> T {
        let data = try await rpcData(function, body: body)
        return try decoder.decode(T.self, from: data)
    }

    /// For the RPCs that return void — there is no body worth decoding,
    /// but the call still has to surface an error.
    @discardableResult
    static func rpc(_ function: String, body: [String: Any]) async throws -> Data {
        try await rpcData(function, body: body)
    }

    private static func rpcData(_ function: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: supabaseURL.appending(path: "rest/v1/rpc/\(function)"))
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError(message: error.code == .notConnectedToInternet
                           ? "No internet connection."
                           : "Couldn't reach Qourt. Check your connection.")
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "No response from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let decoded = try? JSONDecoder().decode(PostgresError.self, from: data)
            throw APIError(message: decoded?.message ?? "Something went wrong. Try again.")
        }
        return data
    }
}
