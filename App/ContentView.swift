import SwiftUI
import WidgetKit

@MainActor
final class BoardViewModel: ObservableObject {
    @Published var settings = SharedStore.loadSettings()
    @Published var departures: [Departure] = SharedStore.loadCache()?.departures ?? []
    @Published var lastFetch: Date? = SharedStore.lastFetch()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var badStations: [String] = []
    @Published var budgetCount = BudgetStore.shared.currentCount()

    var isActiveNow: Bool {
        ScheduleGate.isActive(windows: settings.windows)
    }

    func refresh(force: Bool = false) async {
        let now = Date()
        if !force {
            guard ScheduleGate.appMayFetch(now: now, lastFetch: SharedStore.lastFetch()) else {
                return
            }
        }
        guard BudgetStore.shared.canCall(hardStop: settings.hardStopAtLimit) else {
            errorMessage = "Månedskvote på 50.000 opbrugt. Slå hard-stop fra i Opsætning, hvis du vil fortsætte."
            return
        }
        guard !settings.accessId.isEmpty, !settings.stations.isEmpty else {
            errorMessage = "Tilføj dit Access ID og mindst én station under Opsætning."
            return
        }
        isLoading = true
        errorMessage = nil
        badStations = []
        do {
            // Ét kald for alle stationer. Ved et ugyldigt ID prøves stationerne enkeltvis.
            let (deps, bad, calls) = try await RejseplanenAPI.fetchResilient(
                stations: settings.stations,
                accessId: settings.accessId
            )
            var counted = 0
            for _ in 0..<calls {
                if BudgetStore.shared.tryConsume(hardStop: counted == 0 ? settings.hardStopAtLimit : false) {
                    counted += 1
                }
            }
            departures = deps
            badStations = bad
            lastFetch = now
            SharedStore.saveCache(deps, at: now)
            budgetCount = BudgetStore.shared.currentCount()
            WidgetCenter.shared.reloadAllTimelines()
            if !bad.isEmpty {
                errorMessage = "Kunne ikke bruge: \(bad.joined(separator: ", ")). Vælg stationen igen under Opsætning."
            }
        } catch let fetchError {
            errorMessage = "Kunne ikke hente afgange: \(fetchError.localizedDescription)"
        }
        isLoading = false
    }

    func save() {
        SharedStore.saveSettings(settings)
        budgetCount = BudgetStore.shared.currentCount()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private enum AppTab: Hashable {
    case departures
    case setup
}

struct ContentView: View {
    @StateObject private var vm = BoardViewModel()
    @State private var selectedTab: AppTab = .departures

    var body: some View {
        TabView(selection: $selectedTab) {
            DeparturesScreen(viewModel: vm) {
                selectedTab = .setup
            }
            .tabItem {
                Label("Afgange", systemImage: "tram.fill")
            }
            .tag(AppTab.departures)

            SettingsView(settings: $vm.settings) {
                vm.save()
            }
            .tabItem {
                Label("Opsætning", systemImage: "slider.horizontal.3")
            }
            .tag(AppTab.setup)
        }
    }
}

private struct DeparturesScreen: View {
    @ObservedObject var viewModel: BoardViewModel
    var openSetup: () -> Void
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OverviewCard(
                        count: viewModel.budgetCount,
                        lastFetch: viewModel.lastFetch,
                        active: viewModel.isActiveNow,
                        loading: viewModel.isLoading
                    ) {
                        Task { await viewModel.refresh(force: true) }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: error)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                if viewModel.settings.stations.isEmpty {
                    Section {
                        VStack(spacing: 14) {
                            Image(systemName: "tram.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.accentColor)
                            Text("Tilføj din første station")
                                .font(.title3.bold())
                            Text("Vælg blandt alle metrostationer uden at indtaste navn eller stop-ID.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Gå til Opsætning", action: openSetup)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                } else {
                    ForEach(viewModel.settings.stations.indices, id: \.self) { index in
                        let station = viewModel.settings.stations[index]
                        Section {
                            let items = filtered(station)
                            if items.isEmpty {
                                EmptyDeparturesRow(hasKey: !viewModel.settings.accessId.isEmpty)
                            } else {
                                ForEach(items.prefix(8)) { departure in
                                    DepartureRow(departure: departure)
                                }
                            }
                        } header: {
                            StationSectionHeader(station: station)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Afgange")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.refresh(force: true) }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Label("Opdater", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable { await viewModel.refresh(force: false) }
            .task { await viewModel.refresh(force: false) }
            .onAppear {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    Task { await viewModel.refresh(force: false) }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }

    private func filtered(_ station: Station) -> [Departure] {
        RejseplanenAPI.applyFilter(viewModel.departures, for: station)
    }
}

private struct OverviewCard: View {
    let count: Int
    let lastFetch: Date?
    let active: Bool
    let loading: Bool
    var refresh: () -> Void

    private var progress: Double {
        min(Double(count) / Double(SharedConstants.monthlyLimit), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metro lige nu")
                        .font(.title2.bold())
                    Text(lastFetch.map { "Opdateret \($0.formatted(date: .omitted, time: .shortened))" } ?? "Ikke opdateret endnu")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(active: active)
            }

            HStack(spacing: 12) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("API-forbrug")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(count.formatted()) / \(SharedConstants.monthlyLimit.formatted())")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress)
                        .tint(progress > 0.8 ? .orange : Color.accentColor)
                }
            }

            Button(action: refresh) {
                HStack {
                    if loading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(loading ? "Henter afgange…" : "Opdater afgange")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(loading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
        }
    }
}

private struct StationSectionHeader: View {
    let station: Station

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "m.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text(station.shortName)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            if let lines = MetroStations.all.first(where: { $0.extId == station.id })?.lines {
                Text(lines)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
    }
}

private struct DepartureRow: View {
    let departure: Departure

    var body: some View {
        HStack(spacing: 12) {
            Text(departure.line)
                .font(.subheadline.bold().monospaced())
                .foregroundStyle(departure.line.uppercased() == "M2" ? Color.black : Color.white)
                .frame(minWidth: 38, minHeight: 38)
                .background(Circle().fill(lineColor))

            VStack(alignment: .leading, spacing: 4) {
                Text(departure.direction)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Plan \(departure.time)")
                    if let realtime = departure.rtTime, realtime != departure.time {
                        Text("→ \(realtime)")
                            .foregroundStyle(.orange)
                    }
                    if let track = departure.track, !track.isEmpty {
                        Text("• Spor \(track)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            DepartureTimeView(departure: departure)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private var lineColor: Color {
        switch departure.line.uppercased() {
        case "M1": return .green
        case "M2": return .yellow
        case "M3": return .red
        case "M4": return .blue
        default: return Color.accentColor
        }
    }
}

private struct EmptyDeparturesRow: View {
    let hasKey: Bool

    var body: some View {
        Label(
            hasKey ? "Ingen afgange endnu — træk ned for at hente" : "Tilføj dit Access ID under Opsætning",
            systemImage: hasKey ? "clock.badge.questionmark" : "key"
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.vertical, 10)
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}

/// Tikkende nedtælling: sekunder (M:SS) vises kun under 120 sek. før afgang.
struct DepartureTimeView: View {
    var departure: Departure

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let time = Countdown.display(for: departure, now: context.date)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if time.live {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                    }
                    Text(time.main)
                        .font(.headline.monospacedDigit())
                }
                .foregroundStyle(departure.cancelled ? .red : (time.urgent ? .orange : .primary))
                if !time.sub.isEmpty {
                    Text(time.sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if departure.cancelled {
                    Text("Aflyst")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if departure.isDelayed && !time.live {
                    Text("+\(departure.delayMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

struct StatusPill: View {
    var active: Bool

    var body: some View {
        Label(active ? "Tidsrum aktivt" : "Udenfor tidsrum", systemImage: active ? "bolt.fill" : "moon.fill")
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(active ? Color.green.opacity(0.16) : Color.secondary.opacity(0.12))
            .clipShape(Capsule())
            .foregroundStyle(active ? .green : .secondary)
    }
}
