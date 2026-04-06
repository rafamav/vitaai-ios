import Foundation

/// Direct Canvas REST API client.
/// Runs on the iOS device using the same IP that performed the OAuth login,
/// which is required because Canvas sessions are IP-bound.
actor CanvasAPIClient {
    private let instanceUrl: String
    private let cookies: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(instanceUrl: String, cookies: String) {
        self.instanceUrl = instanceUrl.hasSuffix("/") ? String(instanceUrl.dropLast()) : instanceUrl
        self.cookies = cookies

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - Public API

    func fetchUser() async throws -> CanvasAPIUser {
        try await get("/api/v1/users/self")
    }

    func fetchCourses() async throws -> [CanvasAPICourse] {
        try await getPaginated("/api/v1/courses", queryItems: [
            URLQueryItem(name: "include[]", value: "total_scores"),
            URLQueryItem(name: "include[]", value: "teachers"),
            URLQueryItem(name: "include[]", value: "term"),
            URLQueryItem(name: "enrollment_state", value: "active"),
            URLQueryItem(name: "per_page", value: "100"),
        ])
    }

    func fetchFiles(courseId: Int) async throws -> [CanvasAPIFile] {
        try await getPaginated("/api/v1/courses/\(courseId)/files", queryItems: [
            URLQueryItem(name: "per_page", value: "100"),
        ])
    }

    func fetchAssignments(courseId: Int) async throws -> [CanvasAPIAssignment] {
        try await getPaginated("/api/v1/courses/\(courseId)/assignments", queryItems: [
            URLQueryItem(name: "include[]", value: "submission"),
            URLQueryItem(name: "per_page", value: "100"),
        ])
    }

    func fetchCalendarEvents() async throws -> [CanvasAPICalendarEvent] {
        try await getPaginated("/api/v1/calendar_events", queryItems: [
            URLQueryItem(name: "type", value: "event"),
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "all_events", value: "true"),
        ])
    }

    /// Downloads file data from a Canvas authenticated URL.
    func downloadFile(url: String) async throws -> Data {
        guard let fileUrl = URL(string: url) else {
            throw CanvasClientError.invalidURL(url)
        }
        var request = URLRequest(url: fileUrl)
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw CanvasClientError.httpError(code, url)
        }
        return data
    }

    // MARK: - Internal

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let data = try await fetch(path, queryItems: queryItems)
        return try decoder.decode(T.self, from: data)
    }

    /// Fetches all pages of a paginated Canvas endpoint using Link header.
    private func getPaginated<T: Decodable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> [T] {
        var allItems: [T] = []
        var nextURL: URL? = buildURL(path, queryItems: queryItems)

        while let url = nextURL {
            var request = URLRequest(url: url)
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw CanvasClientError.httpError(code, url.absoluteString)
            }

            let page = try decoder.decode([T].self, from: data)
            allItems.append(contentsOf: page)

            // Parse Link header for next page
            nextURL = Self.parseNextLink(from: http)

            // Safety: max 20 pages to prevent infinite loops
            if allItems.count > 2000 { break }
        }
        return allItems
    }

    private func fetch(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> Data {
        guard let url = buildURL(path, queryItems: queryItems) else {
            throw CanvasClientError.invalidURL(path)
        }
        var request = URLRequest(url: url)
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw CanvasClientError.httpError(code, url.absoluteString)
        }
        return data
    }

    private func buildURL(_ path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        guard var components = URLComponents(string: instanceUrl + path) else { return nil }
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        return components.url
    }

    /// Parses the `Link` header for `rel="next"` pagination.
    static func parseNextLink(from response: HTTPURLResponse) -> URL? {
        guard let link = response.value(forHTTPHeaderField: "Link") else { return nil }
        // Format: <https://...?page=2&per_page=100>; rel="next", <...>; rel="last"
        let parts = link.components(separatedBy: ",")
        for part in parts {
            let segments = part.components(separatedBy: ";")
            guard segments.count >= 2 else { continue }
            let relPart = segments[1].trimmingCharacters(in: .whitespaces)
            if relPart == "rel=\"next\"" {
                let urlPart = segments[0]
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                return URL(string: urlPart)
            }
        }
        return nil
    }
}

// MARK: - Errors

enum CanvasClientError: LocalizedError {
    case invalidURL(String)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "URL inválida: \(url)"
        case .httpError(let code, let url): return "Canvas HTTP \(code): \(url)"
        }
    }
}
