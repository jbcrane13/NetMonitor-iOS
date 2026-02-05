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
    private var downloadStartTime: Date?
    private var uploadBytesSent: Int64 = 0
    private var uploadStartTime: Date?
    private var uploadTotalBytes: Int64 = 0

    private static let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")!
    private static let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
    private static let uploadSize: Int = 10_000_000  // 10 MB

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

        for _ in 0..<iterations {
            let start = Date()
            var request = URLRequest(url: Self.downloadURL)
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
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 30
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: Self.downloadURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let start = Date()
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SpeedTestError.serverError
        }

        let expectedLength = httpResponse.expectedContentLength
        var totalReceived: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(8192) // Pre-allocate for performance

        for try await byte in bytes {
            buffer.append(byte)
            
            // Process in chunks to improve performance
            if buffer.count >= 8192 || (expectedLength > 0 && totalReceived + Int64(buffer.count) >= expectedLength) {
                totalReceived += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                
                if expectedLength > 0 {
                    let newProgress = Double(totalReceived) / Double(expectedLength)
                    // Update progress at intervals to avoid UI thrashing
                    if Int(newProgress * 100) > Int(progress * 100) {
                        progress = min(newProgress, 1.0)
                        let elapsed = Date().timeIntervalSince(start)
                        if elapsed > 0.1 {
                            downloadSpeed = Double(totalReceived * 8) / elapsed / 1_000_000
                        }
                    }
                }
                try Task.checkCancellation()
            }
        }
        
        // Process any remaining bytes
        if !buffer.isEmpty {
            totalReceived += Int64(buffer.count)
        }

        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return 0 }
        return Double(totalReceived * 8) / elapsed / 1_000_000  // bits to Mbps
    }

    // MARK: - Upload Measurement

    private func measureUpload() async throws -> Double {
        let uploadData = Data(count: Self.uploadSize)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 30
        let delegate = UploadProgressDelegate { [weak self] fractionCompleted, bytesSent in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.progress = fractionCompleted
            }
        }
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: Self.uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let start = Date()
        let (_, response) = try await session.upload(for: request, from: uploadData)

        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return 0 }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SpeedTestError.serverError
        }

        let speedMbps = Double(Self.uploadSize * 8) / elapsed / 1_000_000
        uploadSpeed = speedMbps
        return speedMbps
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

// MARK: - Upload Progress Delegate

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    let onProgress: @Sendable (Double, Int64) -> Void

    init(onProgress: @escaping @Sendable (Double, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress(fraction, totalBytesSent)
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
