import ActivityKit
import Combine
import Foundation

@MainActor
final class LiveActivityController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var statusText = "Ikke startet"

    init() {
        refreshStatus()
    }

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func refreshStatus() {
        isActive = !Activity<MetroDepartureActivityAttributes>.activities.isEmpty
        if isActive {
            statusText = "Vises på låseskærmen"
        }
    }

    func start(settings: AppSettings, departures: [Departure], updatedAt: Date) async {
        guard isAvailable else {
            isActive = false
            statusText = "Live Activities er slået fra i iOS"
            return
        }
        guard let station = settings.stations.first else {
            statusText = "Tilføj først en station"
            return
        }
        guard let state = makeState(station: station, departures: departures, updatedAt: updatedAt) else {
            statusText = "Hent afgange, før du starter"
            return
        }

        await endAll()

        let attributes = MetroDepartureActivityAttributes(
            stationID: station.id,
            stationName: station.shortName
        )
        let content = ActivityContent(
            state: state,
            staleDate: updatedAt.addingTimeInterval(2 * 60)
        )

        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            isActive = true
            statusText = "Vises på låseskærmen"
        } catch {
            isActive = false
            statusText = "Kunne ikke starte: \(error.localizedDescription)"
        }
    }

    func update(settings: AppSettings, departures: [Departure], updatedAt: Date) async {
        let activities = Activity<MetroDepartureActivityAttributes>.activities
        guard !activities.isEmpty else {
            refreshStatus()
            return
        }

        for activity in activities {
            guard let station = settings.stations.first(where: { $0.id == activity.attributes.stationID }),
                  let state = makeState(station: station, departures: departures, updatedAt: updatedAt) else {
                continue
            }
            let content = ActivityContent(
                state: state,
                staleDate: updatedAt.addingTimeInterval(2 * 60)
            )
            await activity.update(content)
        }
        refreshStatus()
    }

    func stop() async {
        await endAll()
        isActive = false
        statusText = "Stoppet"
    }

    private func endAll() async {
        for activity in Activity<MetroDepartureActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func makeState(
        station: Station,
        departures: [Departure],
        updatedAt: Date
    ) -> MetroDepartureActivityAttributes.ContentState? {
        let filtered = RejseplanenAPI.applyFilter(departures, for: station)
        let liveDepartures = filtered.compactMap { departure -> MetroDepartureActivityAttributes.LiveDeparture? in
            guard let date = Countdown.date(
                plan: departure.time,
                rt: departure.rtTime,
                now: updatedAt
            ), date > updatedAt.addingTimeInterval(-30) else {
                return nil
            }
            return MetroDepartureActivityAttributes.LiveDeparture(
                line: departure.line,
                direction: departure.direction,
                departureDate: date,
                scheduledTime: departure.time,
                realtimeTime: departure.rtTime,
                track: departure.track,
                cancelled: departure.cancelled,
                delayMinutes: departure.delayMinutes
            )
        }
        .sorted { $0.departureDate < $1.departureDate }

        guard !liveDepartures.isEmpty else { return nil }
        return MetroDepartureActivityAttributes.ContentState(
            departures: Array(liveDepartures.prefix(4)),
            updatedAt: updatedAt
        )
    }
}
