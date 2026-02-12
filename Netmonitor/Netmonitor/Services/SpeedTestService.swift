import Foundation

/// Plain data struct returned from speed test (Sendable)
struct SpeedTestData: Sendable {
    let downloadSpeed: Double
    let uploadSpeed: Double
    let latency: Double
    let serverName: String
}

/// Service for measuring internet download/upload speed and latency
@MainActor
@Observable
final class SpeedTestService: NSObject {
    // MARK: - Public State

    var downloadSpeed: Double = 0  // Mbps
    var uploadSpeed: Double = 0    // Mbps
    var latency: Double = 0        // ms
    var progress: Double = 0       // 0-1
    var phase: Phase = .idle
    var isRunning: Bool = false
    var errorMessage: String?
    var duration: TimeInterval = 5.0  // seconds per phase

    enum Phase: String, Sendable {
        case idle
        case latency
        case download
        case upload
        case complete
    }

    // MARK: - Private

    private var currentTask: Task<SpeedTestData, Error>?
    private var downloadBytesReceived: Int64 = 0
    private var uploadBytesSent: Int64 = 0

    // MARK: - Public API

    func startTest() async throws -> SpeedTestData {
        reset()
        isRunning = true

        let task = Task<SpeedTestData, Error> {
            // Phase 1: Latency
            phase = .latency
            let measuredLatency = await measureLatency()
            try Task.checkCancellation()
            latency = measuredLatency

            // Phase 2: Download
            phase = .download
            let dlSpeed = try await measureDownload()
            try Task.checkCancellation()
            downloadSpeed = dlSpeed

            // Phase 3: Upload
            phase = .upload
            progress = 0
            let ulSpeed = try await measureUpload()
            try Task.checkCancellation()
            uploadSpeed = ulSpeed

            // Complete
            phase = .complete
            progress = 1
            isRunning = false

            return SpeedTestData(
                downloadSpeed: downloadSpeed,
                uploadSpeed: uploadSpeed,
                latency: latency,
                serverName: "Cloudflare"
            )
        }

        currentTask = task

        do {
            let result = try await task.value
            return result
        } catch {
            isRunning = false
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
                phase = .idle
            }
            throw error
        }
    }

    func stopTest() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        phase = .idle
    }

    // MARK: - Latency Measurement

    private func measureLatency() async -> Double {
        let iterations = 3
        var times: [Double] = []
        let session = URLSession.shared
        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=1000000")!

        for _ in 0..<iterations {
            let start = Date()
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            do {
                let (_, _) = try await session.data(for: request)
                let elapsed = Date().timeIntervalSince(start) * 1000
                times.append(elapsed)
            } catch {
                continue
            }
        }

        guard !times.isEmpty else { return 0 }
        return times.reduce(0, +) / Double(times.count)
    }

    // MARK: - Download Measurement

    private func measureDownload() async throws -> Double {
        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=1000000")!
        let startTime = Date()
        var totalBytes: Int64 = 0
        var peakSpeed: Double = 0

        while Date().timeIntervalSince(startTime) < duration {
            try Task.checkCancellation()

            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw SpeedTestError.serverError
            }

            totalBytes += Int64(data.count)
            let elapsed = Date().timeIntervalSince(startTime)
            let currentSpeed = Double(totalBytes * 8) / elapsed / 1_000_000
            peakSpeed = max(peakSpeed, currentSpeed)

            downloadSpeed = currentSpeed
            progress = min(elapsed / duration, 1.0)
            downloadBytesReceived = totalBytes
        }

        let totalElapsed = Date().timeIntervalSince(startTime)
        guard totalElapsed > 0, totalBytes > 0 else { return 0 }
        let finalSpeed = Double(totalBytes * 8) / totalElapsed / 1_000_000
        downloadSpeed = finalSpeed
        progress = 1.0
        return finalSpeed
    }

    // MARK: - Upload Measurement

    private func measureUpload() async throws -> Double {
        let chunkSize = 256 * 1024 // 256KB
        let url = URL(string: "https://speed.cloudflare.com/__up")!
        let startTime = Date()
        var totalBytes: Int64 = 0
        var peakSpeed: Double = 0

        while Date().timeIntervalSince(startTime) < duration {
            try Task.checkCancellation()

            let data = Data(count: chunkSize)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10

            let (_, response) = try await URLSession.shared.upload(for: request, from: data)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw SpeedTestError.serverError
            }

            totalBytes += Int64(chunkSize)
            let elapsed = Date().timeIntervalSince(startTime)
            let currentSpeed = Double(totalBytes * 8) / elapsed / 1_000_000
            peakSpeed = max(peakSpeed, currentSpeed)

            uploadSpeed = currentSpeed
            progress = min(elapsed / duration, 1.0)
            uploadBytesSent = totalBytes
        }

        let totalElapsed = Date().timeIntervalSince(startTime)
        guard totalElapsed > 0, totalBytes > 0 else { return 0 }
        let finalSpeed = Double(totalBytes * 8) / totalElapsed / 1_000_000
        uploadSpeed = finalSpeed
        progress = 1.0
        return finalSpeed
    }

    // MARK: - Helpers

    private func reset() {
        downloadSpeed = 0
        uploadSpeed = 0
        latency = 0
        progress = 0
        phase = .idle
        errorMessage = nil
        downloadBytesReceived = 0
        uploadBytesSent = 0
    }
}

// MARK: - Errors

/// Legacy alias — new code should use NetworkError directly
enum SpeedTestError: LocalizedError {
    case serverError
    case cancelled

    var errorDescription: String? {
        switch self {
        case .serverError: "Speed test server returned an error"
        case .cancelled: "Speed test was cancelled"
        }
    }

    var asNetworkError: NetworkError {
        switch self {
        case .serverError: .serverError
        case .cancelled: .cancelled
        }
    }
}
