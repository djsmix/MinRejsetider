import WidgetKit
import SwiftUI
import AppIntents

struct RejsetiderEntry: TimelineEntry {
    var date: Date
    var departures: [Departure]
    var active: Bool
    var nextWindow: Date?
    var budgetUsed: Int
    var stationLabel: String = ""
    var needsKey: Bool = false
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RejsetiderEntry {
        RejsetiderEntry(date: Date(), departures: [], active: true, nextWindow: nil,
                        budgetUsed: 0, stationLabel: "Kongens Nytorv")
    }

    func snapshot(for configuration: StationIntent, in context: Context) async -> RejsetiderEntry {
        let cache = SharedStore.loadCache()
        return RejsetiderEntry(date: Date(),
                               departures: cache?.departures ?? [],
                               active: true, nextWindow: nil,
                               budgetUsed: BudgetStore.shared.currentCount(),
                               stationLabel: configuration.station.station.short)
    }

    func timeline(for configuration: StationIntent, in context: Context) async -> Timeline<RejsetiderEntry> {
        let now = Date()
        let ms = configuration.station.station
        let dirText = (configuration.direction ?? "").trimmingCharacters(in: .whitespaces)
        let st = Station(id: ms.extId, name: ms.name,
                         directions: dirText.isEmpty ? [] : [dirText])
        let preset = configuration.tidsrum
        let label = ms.short
        let key = (configuration.accessId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        func entry(_ active: Bool, _ deps: [Departure], _ next: Date?, _ budget: Int, _ needsKey: Bool) -> RejsetiderEntry {
            RejsetiderEntry(date: now, departures: deps, active: active,
                            nextWindow: next, budgetUsed: budget, stationLabel: label, needsKey: needsKey)
        }

        // REGEL 0: intet accessId på widgetten endnu => vis vejledning, 0 kald
        if key.isEmpty {
            let next = now.addingTimeInterval(30*60)
            return Timeline(entries: [entry(true, [], nil, BudgetStore.shared.currentCount(), true)],
                            policy: .after(next))
        }

        // REGEL 1: uden for valgt tidsrum => NUL kald, sov til næste vindue
        if !preset.isActive(now: now) {
            let next = preset.nextStart(after: now) ?? now.addingTimeInterval(3600)
            return Timeline(entries: [entry(false, [], next, BudgetStore.shared.currentCount(), false)],
                            policy: .after(next))
        }

        // REGEL 2: budgetvagt (widgetten har sin egen lokale tæller)
        if !BudgetStore.shared.canCall(hardStop: true) || !BudgetStore.shared.tryConsume(hardStop: true) {
            let cache = SharedStore.loadCache()
            let next = now.addingTimeInterval(15*60)
            return Timeline(entries: [entry(true, cache?.departures ?? [], nil, BudgetStore.shared.currentCount(), false)],
                            policy: .after(next))
        }

        // ÉT kald for DENNE widgets station (single departureBoard)
        do {
            var deps = try await RejseplanenAPI.fetchSingleDepartures(
                station: st, accessId: key)
            deps = RejseplanenAPI.applyFilter(deps, for: st)
            SharedStore.saveCache(deps, at: now)
            let merged = WidgetData.sorted(deps, now: now)
            let next = WidgetData.nextRefresh(after: now, merged: merged)
            return Timeline(entries: [entry(true, deps, nil, BudgetStore.shared.currentCount(), false)],
                            policy: .after(next))
        } catch {
            let cache = SharedStore.loadCache()
            let next = now.addingTimeInterval(10*60)
            return Timeline(entries: [entry(true, cache?.departures ?? [], nil, BudgetStore.shared.currentCount(), false)],
                            policy: .after(next))
        }
    }
}

/// Fælles hjælpere: sortér afgange efter tid (allerede filtreret af provideren).
enum WidgetData {
    static func sorted(_ deps: [Departure], now: Date) -> [(Departure, Date)] {
        deps.compactMap { d in
            Countdown.date(plan: d.time, rt: d.rtTime, now: now).map { (d, $0) }
        }.sorted { $0.1 < $1.1 }
    }

    /// Næste refresh: senest om 5 min, men gerne lige efter nærmeste afgang er kørt
    static func nextRefresh(after now: Date, merged: [(Departure, Date)]) -> Date {
        let five = Calendar.current.date(byAdding: .minute, value: 5, to: now)!
        if let first = merged.first {
            let afterDep = first.1.addingTimeInterval(90)
            if afterDep > now { return min(five, afterDep) }
        }
        return five
    }
}

struct RejsetiderWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: RejsetiderEntry
    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenView(entry: entry)
        case .accessoryCircular:
            CircularView(entry: entry)
        default:
            StandardWidgetView(entry: entry)
        }
    }
}

/// Lille cirkel-widget: kun nedtælling.
struct CircularView: View {
    var entry: RejsetiderEntry
    var body: some View {
        let list = WidgetData.sorted(entry.departures, now: entry.date)
        if entry.needsKey {
            Text("Nøgle").font(.caption2)
        } else if !entry.active {
            Text("Pause").font(.caption2)
        } else if let first = list.first {
            VStack(spacing: 0) {
                Text(first.0.line).font(.caption2.bold())
                Text(first.1, style: .timer).font(.caption.monospaced())
            }
        } else {
            Text("–").font(.headline)
        }
    }
}

/// Låseskærm: én næste afgang med LIVE nedtælling (tikker uden nye API-kald).
struct LockScreenView: View {
    var entry: RejsetiderEntry
    var body: some View {
        let list = WidgetData.sorted(entry.departures, now: entry.date)
        if entry.needsKey {
            VStack(alignment: .leading) {
                Text("Tilføj Access ID").font(.headline)
                Text("Langt tryk → Rediger").font(.caption2)
            }
        } else if !entry.active {
            VStack(alignment: .leading) {
                Text(entry.stationLabel.isEmpty ? "Metro pause" : "\(entry.stationLabel) pause").font(.headline)
                Text(entry.nextWindow.map { "Igang \($0.formatted(date: .omitted, time: .shortened))" } ?? "0 kald uden for vindue")
                    .font(.caption2)
            }
        } else if let first = list.first {
            HStack {
                Text(first.0.line).font(.headline)
                Text(first.0.direction).font(.caption).lineLimit(1)
                Spacer()
                Text(first.1, style: .timer).font(.headline.monospaced())
            }
        } else {
            Text("Ingen afgange — åbn appen").font(.caption)
        }
    }
}

struct StandardWidgetView: View {
    var entry: RejsetiderEntry
    var body: some View {
        let list = WidgetData.sorted(entry.departures, now: entry.date)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.stationLabel.isEmpty ? "Metro" : entry.stationLabel).font(.caption.bold()).lineLimit(1)
                Spacer()
                Text("\(entry.budgetUsed/1000)k").font(.caption2).foregroundStyle(.secondary)
            }
            if entry.needsKey {
                Text("Tilføj Access ID").font(.headline)
                Text("Langt tryk → Rediger widget").font(.caption).foregroundStyle(.secondary)
            } else if !entry.active {
                Text("Udenfor tidsrum")
                    .font(.headline)
                Text(entry.nextWindow.map { "Næste: \($0.formatted(date: .omitted, time: .shortened))" } ?? "Pause — bruger 0 kald")
                    .font(.caption).foregroundStyle(.secondary)
                if let first = list.prefix(2).first {
                    Text("Sidst: \(first.0.line) \(first.0.displayTime)").font(.caption2).foregroundStyle(.secondary)
                }
            } else if list.isEmpty {
                Text("Ingen afgange").font(.headline)
                Text("Åbn appen for at hente").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(list.prefix(4).map { $0.0 }) { d in
                    HStack {
                        Text(d.line).font(.caption.bold().monospaced()).frame(width: 30, alignment: .leading)
                        Text(d.direction).font(.caption).lineLimit(1)
                        Spacer()
                        Text(Countdown.display(for: d, now: entry.date).main)
                            .font(.caption.bold().monospaced())
                            .foregroundStyle(d.cancelled ? .red : (d.isDelayed ? .orange : .primary))
                    }
                }
            }
        }
        .padding(4)
    }
}

struct RejsetiderWidget: Widget {
    let kind = "RejsetiderWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StationIntent.self, provider: Provider()) { entry in
            RejsetiderWidgetView(entry: entry)
        }
        .configurationDisplayName("MinRejsetider")
        .description("Vælg station, retning og tidsrum direkte på widgetten (langt tryk → Rediger).")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}
