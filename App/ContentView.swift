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
                errorMessage = "Venter: der er under 60 sek. siden sidste kald (sparer kvote)."
                return
            }
        }
        guard BudgetStore.shared.canCall(hardStop: settings.hardStopAtLimit) else {
            errorMessage = "Månedskvote på 50.000 opbrugt. Slå hard-stop fra i Indstillinger hvis du vil fortsætte."
            return
        }
        guard !settings.accessId.isEmpty, !settings.stations.isEmpty else {
            errorMessage = "Tilføj accessId + mindst 1 station under Indstillinger."
            return
        }
        isLoading = true; errorMessage = nil; badStations = []
        do {
            // ÉT kald for alle stationer (multiDepartureBoard) — det er hele tricket.
            // Virker ét ID ikke, prøver den automatisk hver station for sig.
            let (deps, bad, calls) = try await RejseplanenAPI.fetchResilient(
                stations: settings.stations, accessId: settings.accessId
            )
            // Bogfør alle kald mod månedskvoten (første tæller hårdt, resten blødt)
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
                errorMessage = "Ugyldigt stop-ID for: \(bad.joined(separator: ", ")). Vælg stationen igen fra metrolisten."
            }
        } catch let fetchError {
            errorMessage = "Kunne ikke hente: \(fetchError.localizedDescription)"
        }
        isLoading = false
    }

    func save() {
        SharedStore.saveSettings(settings)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct ContentView: View {
    @StateObject private var vm = BoardViewModel()
    @State private var showSettings = false
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(BudgetStore.shared.currentCount()) / 50.000")
                                .font(.headline)
                            Text("Tilbage i md.: \(BudgetStore.shared.remaining())")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(active: vm.isActiveNow)
                    }
                    ProgressView(value: BudgetStore.shared.percentUsed())
                    if BudgetStore.shared.percentUsed() > 0.8 {
                        Text("⚠️ Over 80% af kvoten brugt — widgets kører kun i tidsvinduer.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if let last = vm.lastFetch {
                        Text("Sidst hentet: \(last.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: { Text("Forbrug & status") }

                if let err = vm.errorMessage {
                    Section { Text(err).font(.caption).foregroundStyle(.red) }
                }

                ForEach(vm.settings.stations.indices, id: \.self) { i in
                    let st = vm.settings.stations[i]
                    Section(st.shortName) {
                        let list = filtered(st)
                        if list.isEmpty {
                            Text("Ingen afgange i cache endnu — træk ned for at hente.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(list.prefix(8)) { d in
                            HStack {
                                Text(d.line)
                                    .font(.headline.monospaced())
                                    .frame(width: 44, alignment: .leading)
                                VStack(alignment: .leading) {
                                    Text(d.direction).font(.subheadline).lineLimit(1)
                                    Text("Plan \(d.time)" + (d.rtTime.map { " • RT \($0)" } ?? ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                DepartureTimeView(departure: d)
                            }
                        }
                    }
                }
            }
            .navigationTitle("MinRejsetider")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showSettings = true } label: { Image(systemName: "gear") }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { Task { await vm.refresh(force: true) } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .refreshable { await vm.refresh(force: false) }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: $vm.settings, onSave: { vm.save() })
            }
            .task { await vm.refresh(force: false) }
            .onAppear {
                // Auto-refresh kun mens appen er åben, hvert 60. sek
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    Task { await vm.refresh(force: false) }
                }
            }
            .onDisappear { timer?.invalidate() }
        }
    }

    private func filtered(_ st: Station) -> [Departure] {
        RejseplanenAPI.applyFilter(vm.departures, for: st)
    }
}

/// Tikkende nedtælling: sekunder (M:SS) vises KUN under 120 sek. før afgang.
struct DepartureTimeView: View {
    var departure: Departure
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let t = Countdown.display(for: departure, now: ctx.date)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if t.live { Circle().fill(Color.green).frame(width: 7, height: 7) }
                    Text(t.main).font(.headline.monospaced())
                }
                .foregroundStyle(departure.cancelled ? .red : (t.urgent ? .orange : .primary))
                if !t.sub.isEmpty {
                    Text(t.sub).font(.caption).foregroundStyle(.secondary)
                }
                if departure.cancelled { Text("Aflyst").font(.caption).foregroundStyle(.red) }
                else if departure.isDelayed && !t.live {
                    Text("+\(departure.delayMinutes) min").font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }
}

struct StatusPill: View {    var active: Bool
    var body: some View {
        Text(active ? "● I vindue" : "○ Udenfor vindue")
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(active ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
            .clipShape(Capsule())
            .foregroundStyle(active ? .green : .secondary)
    }
}
