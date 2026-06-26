// Fetches and caches favicons for HTTP(S) URLs.
import AppKit
import Foundation

final class FaviconService {
    static let shared = FaviconService()

    private let cache = NSCache<NSString, NSImage>()
    private let session: URLSession
    private let lock = NSLock()
    private var pendingCallbacks: [String: [(NSImage?) -> Void]] = [:]

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        session = URLSession(configuration: configuration)
    }

    func cachedFavicon(for pageURL: URL) -> NSImage? {
        guard let key = cacheKey(for: pageURL) else {
            return nil
        }

        return cache.object(forKey: key as NSString)
    }

    func fetchFavicon(for pageURL: URL, completion: @escaping (NSImage?) -> Void) {
        guard let key = cacheKey(for: pageURL) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        if let cached = cache.object(forKey: key as NSString) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }

        lock.lock()
        if pendingCallbacks[key] != nil {
            pendingCallbacks[key]?.append(completion)
            lock.unlock()
            return
        }
        pendingCallbacks[key] = [completion]
        lock.unlock()

        loadBestFavicon(for: pageURL) { [weak self] image in
            guard let self else {
                return
            }

            if let image {
                self.cache.setObject(image, forKey: key as NSString)
            }

            self.finishRequest(for: key, image: image)
        }
    }

    private func loadBestFavicon(for pageURL: URL, completion: @escaping (NSImage?) -> Void) {
        guard let baseURL = baseSiteURL(for: pageURL) else {
            completion(nil)
            return
        }

        let directCandidates = [
            baseURL.appending(path: "favicon.ico"),
            baseURL.appending(path: "favicon.png"),
            baseURL.appending(path: "apple-touch-icon.png")
        ]

        loadFirstAvailableImage(from: directCandidates, index: 0) { [weak self] image in
            guard let self else {
                completion(image)
                return
            }

            if let image {
                completion(image)
                return
            }

            self.discoverIconURLs(from: baseURL) { iconURLs in
                self.loadFirstAvailableImage(from: iconURLs, index: 0, completion: completion)
            }
        }
    }

    private func loadFirstAvailableImage(
        from urls: [URL],
        index: Int,
        completion: @escaping (NSImage?) -> Void
    ) {
        guard index < urls.count else {
            completion(nil)
            return
        }

        fetchImage(at: urls[index]) { [weak self] image in
            guard let self else {
                completion(image)
                return
            }

            if let image {
                completion(image)
                return
            }

            self.loadFirstAvailableImage(from: urls, index: index + 1, completion: completion)
        }
    }

    private func fetchImage(at url: URL, completion: @escaping (NSImage?) -> Void) {
        session.dataTask(with: url) { [weak self] data, response, _ in
            guard let self else {
                completion(nil)
                return
            }

            completion(self.makeImage(data: data, response: response))
        }.resume()
    }

    private func discoverIconURLs(from baseURL: URL, completion: @escaping ([URL]) -> Void) {
        session.dataTask(with: baseURL) { [weak self] data, response, _ in
            guard let self,
                  let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  let data,
                  let html = String(data: data, encoding: .utf8) else {
                completion([])
                return
            }

            completion(self.extractIconURLs(from: html, baseURL: baseURL))
        }.resume()
    }

    private func extractIconURLs(from html: String, baseURL: URL) -> [URL] {
        let linkPattern = #"<link[^>]*rel=[\"'][^\"']*icon[^\"']*[\"'][^>]*>"#
        let hrefPattern = #"href=[\"']([^\"']+)[\"']"#

        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive]),
              let hrefRegex = try? NSRegularExpression(pattern: hrefPattern, options: [.caseInsensitive]) else {
            return []
        }

        let htmlRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let linkMatches = linkRegex.matches(in: html, range: htmlRange)

        var urls: [URL] = []
        for linkMatch in linkMatches {
            guard let linkRange = Range(linkMatch.range, in: html) else {
                continue
            }

            let linkTag = String(html[linkRange])
            let linkTagRange = NSRange(linkTag.startIndex..<linkTag.endIndex, in: linkTag)
            guard let hrefMatch = hrefRegex.firstMatch(in: linkTag, range: linkTagRange),
                  hrefMatch.numberOfRanges > 1,
                  let hrefRange = Range(hrefMatch.range(at: 1), in: linkTag) else {
                continue
            }

            let href = String(linkTag[hrefRange])
            guard let resolvedURL = URL(string: href, relativeTo: baseURL)?.absoluteURL else {
                continue
            }

            urls.append(resolvedURL)
        }

        return urls
    }

    private func finishRequest(for key: String, image: NSImage?) {
        lock.lock()
        let callbacks = pendingCallbacks.removeValue(forKey: key) ?? []
        lock.unlock()

        DispatchQueue.main.async {
            callbacks.forEach { $0(image) }
        }
    }

    private func makeImage(data: Data?, response: URLResponse?) -> NSImage? {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              let data,
              let image = NSImage(data: data) else {
            return nil
        }

        image.size = NSSize(width: 16, height: 16)
        return image
    }

    private func cacheKey(for pageURL: URL) -> String? {
        guard let scheme = pageURL.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = pageURL.host?.lowercased() else {
            return nil
        }

        let portPart = pageURL.port.map { ":\($0)" } ?? ""
        return "\(scheme)://\(host)\(portPart)"
    }

    private func baseSiteURL(for pageURL: URL) -> URL? {
        guard let key = cacheKey(for: pageURL),
              let keyURL = URL(string: key),
              var components = URLComponents(url: keyURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.path = "/"
        return components.url
    }
}