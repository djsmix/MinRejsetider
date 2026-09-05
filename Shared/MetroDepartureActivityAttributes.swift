import ActivityKit
import Foundation

struct MetroDepartureActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var departures: [LiveDeparture]
        var updatedAt: Date
    }

    struct LiveDeparture: Codable, Hashable {
        var line: String
        var direction: String
        var departureDate: Date
        var scheduledTime: String
        var realtimeTime: String?
        var track: String?
        var cancelled: Bool
        var delayMinutes: Int

        var displayTime: String {
            realtimeTime ?? scheduledTime
        }
    }

    var stationID: String
    var stationName: String
}
