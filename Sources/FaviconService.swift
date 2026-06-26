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
        guard let requestURL = faviconURL(for: pageURL),
              let key = cacheKey(for: pageURL) else {
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

        session.dataTask(with: requestURL) { [weak self] data, response, _ in
            guard let self else {
                return
            }

            let image = self.makeImage(data: data, response: response)
            if let image {
                self.cache.setObject(image, forKey: key as NSString)
            }

            self.finishRequest(for: key, image: image)
        }.resume()
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

    private func faviconURL(for pageURL: URL) -> URL? {
        guard let key = cacheKey(for: pageURL),
              let keyURL = URL(string: key),
              var components = URLComponents(url: keyURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.path = "/favicon.ico"
        return components.url
    }
}