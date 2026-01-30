import Testing
@testable import Netmonitor

@Suite("PingService Tests")
struct PingServiceTests {

    @Test("Calculate statistics with successful pings")
    func calculateStatisticsSuccess() async {
        let service = PingService()
        let results: [PingResult] = [
            PingResult(sequence: 1, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 10.0, size: 64, isTimeout: false),
            PingResult(sequence: 2, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 20.0, size: 64, isTimeout: false),
            PingResult(sequence: 3, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 15.0, size: 64, isTimeout: false),
            PingResult(sequence: 4, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 25.0, size: 64, isTimeout: false),
        ]

        let stats = await service.calculateStatistics(results)

        #expect(stats != nil)
        if let stats {
            #expect(stats.transmitted == 4)
            #expect(stats.received == 4)
            #expect(stats.packetLoss == 0.0)
            #expect(stats.minTime == 10.0)
            #expect(stats.maxTime == 25.0)
            #expect(stats.avgTime == 17.5)
        }
    }

    @Test("Calculate statistics with packet loss")
    func calculateStatisticsWithLoss() async {
        let service = PingService()
        let results: [PingResult] = [
            PingResult(sequence: 1, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 10.0, size: 64, isTimeout: false),
            PingResult(sequence: 2, host: "1.1.1.1", ipAddress: nil, ttl: 0, time: 5000.0, size: 64, isTimeout: true),
        ]

        let stats = await service.calculateStatistics(results, requestedCount: 2)

        #expect(stats != nil)
        if let stats {
            #expect(stats.transmitted == 2)
            #expect(stats.received == 1)
            #expect(stats.packetLoss == 50.0)
        }
    }

    @Test("Calculate statistics with empty results returns nil")
    func calculateStatisticsEmpty() async {
        let service = PingService()
        let stats = await service.calculateStatistics([])
        #expect(stats == nil)
    }
}
