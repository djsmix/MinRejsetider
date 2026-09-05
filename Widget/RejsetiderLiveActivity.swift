import ActivityKit
import SwiftUI
import WidgetKit

struct RejsetiderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MetroDepartureActivityAttributes.self) { context in
            LockScreenActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.88))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.stationName, systemImage: "tram.fill")
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let first = context.state.departures.first {
                        ActivityCountdown(departure: first, compact: true)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        ForEach(context.state.departures.prefix(3), id: \.self) { departure in
                            LiveDepartureRow(departure: departure)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Text(context.state.departures.first?.line ?? "M")
                    .font(.caption.bold())
                    .foregroundStyle(lineColor(context.state.departures.first?.line))
            } compactTrailing: {
                if let first = context.state.departures.first {
                    ActivityCountdown(departure: first, compact: true)
                } else {
                    Text("–")
                }
            } minimal: {
                Image(systemName: "tram.fill")
                    .foregroundStyle(.blue)
            }
            .keylineTint(.blue)
            .widgetURL(URL(string: "minrejsetider://afgange"))
        }
    }
}

private struct LockScreenActivityView: View {
    let context: ActivityViewContext<MetroDepartureActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Label(context.attributes.stationName, systemImage: "tram.fill")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("MinRejsetider")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Opdateret \(context.state.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let first = context.state.departures.first {
                    ActivityCountdown(departure: first, compact: false)
                }
            }

            VStack(spacing: 7) {
                ForEach(context.state.departures, id: \.self) { departure in
                    LiveDepartureRow(departure: departure)
                }
            }
        }
        .padding(16)
        .widgetURL(URL(string: "minrejsetider://afgange"))
    }
}

private struct LiveDepartureRow: View {
    let departure: MetroDepartureActivityAttributes.LiveDeparture

    var body: some View {
        HStack(spacing: 9) {
            Text(departure.line)
                .font(.caption.bold().monospaced())
                .foregroundStyle(lineColor(departure.line))
                .frame(width: 28, alignment: .leading)
            Text(departure.direction)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(departure.departureDate, style: .time)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(departure.cancelled ? .red : .primary)
        }
    }
}

private struct ActivityCountdown: View {
    let departure: MetroDepartureActivityAttributes.LiveDeparture
    let compact: Bool

    var body: some View {
        Text(departure.departureDate, style: .timer)
            .font(compact ? .caption.bold().monospacedDigit() : .headline.monospacedDigit())
            .foregroundStyle(departure.cancelled ? .red : .primary)
            .multilineTextAlignment(.trailing)
    }
}

private func lineColor(_ line: String?) -> Color {
    switch line?.uppercased() {
    case "M1": return .green
    case "M2": return .yellow
    case "M3": return .red
    case "M4": return .blue
    default: return .blue
    }
}
