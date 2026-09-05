import SwiftUI

struct SettingsView: View {
    @Binding var settings: AppSettings
    var onSave: () -> Void

    @State private var revealAccessId = false
    @State private var searchText = ""
    @State private var searchResults: [Station] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var pickerIndex: Int?
    @State private var showPicker = false
    @State private var directionIndex: Int?
    @State private var showDirections = false
    @State private var savePulse = 0

    var body: some View {
        NavigationStack {
            Form {
                accessSection
                stationsSection
                timeWindowsSection

                Section("API-budget") {
                    Toggle("Stop automatisk ved 50.000 kald", isOn: $settings.hardStopAtLimit)
                    Label(BudgetStore.shared.statusText, systemImage: "gauge.with.dots.needle.33percent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Opsætning")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Gem") {
                        onSave()
                        savePulse += 1
                    }
                    .fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.success, trigger: savePulse)
            .onDisappear(perform: onSave)
            .sheet(isPresented: $showPicker) {
                StationPickerSheet(
                    title: pickerIndex == nil ? "Tilføj station" : "Skift station",
                    unavailableIDs: unavailableStationIDs
                ) { picked in
                    select(picked)
                }
            }
            .sheet(isPresented: $showDirections) {
                if let index = directionIndex, settings.stations.indices.contains(index) {
                    DirectionPickerSheet(
                        station: settings.stations[index],
                        cache: SharedStore.loadCache()?.departures ?? [],
                        initial: Set(settings.stations[index].directions)
                    ) { picked in
                        settings.stations[index].directions = picked.sorted()
                    }
                }
            }
        }
    }

    private var accessSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)

                Group {
                    if revealAccessId {
                        TextField("Indsæt Access ID", text: $settings.accessId)
                    } else {
                        SecureField("Indsæt Access ID", text: $settings.accessId)
                    }
                }
                .privateKeyInput()
                .font(.callout.monospaced())

                Button {
                    revealAccessId.toggle()
                } label: {
                    Image(systemName: revealAccessId ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(revealAccessId ? "Skjul Access ID" : "Vis Access ID")
            }

            if settings.accessId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("Access ID mangler — indsæt din private UUID fra Rejseplanen Labs.", systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Label("Gemt lokalt på telefonen. Del ikke denne nøgle.", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Rejseplanen")
        }
    }

    private var stationsSection: some View {
        Section {
            if settings.stations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "m.circle")
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                    Text("Ingen stationer valgt")
                        .font(.headline)
                    Text("Tryk nedenfor og vælg direkte fra metrolisten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            ForEach(settings.stations.indices, id: \.self) { index in
                StationEditorRow(
                    station: $settings.stations[index],
                    changeStation: {
                        pickerIndex = index
                        showPicker = true
                    },
                    chooseDirections: {
                        directionIndex = index
                        showDirections = true
                    }
                )
            }
            .onDelete { offsets in
                settings.stations.remove(atOffsets: offsets)
            }
            .onMove { source, destination in
                settings.stations.move(fromOffsets: source, toOffset: destination)
            }

            Button {
                pickerIndex = nil
                showPicker = true
            } label: {
                Label("Tilføj metrostation", systemImage: "plus.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            }

            DisclosureGroup("Andre stationer via API") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("Søg fx Hellerup", text: $searchText)
                            .stationSearchInput()
                            .onSubmit { Task { await search() } }
                        Button {
                            Task { await search() }
                        } label: {
                            if searching {
                                ProgressView()
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSearch)
                    }

                    if let error = searchError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    ForEach(searchResults, id: \.id) { result in
                        Button {
                            addSearchResult(result)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name)
                                        .foregroundStyle(.primary)
                                    Text("Stop-ID \(result.id)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: settings.stations.contains(where: { $0.id == result.id }) ? "checkmark.circle.fill" : "plus.circle")
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(settings.stations.contains(where: { $0.id == result.id }))
                    }

                    Text("Brug kun API-søgning til tog og bus. Hver søgning bruger ét API-kald.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        } header: {
            Text("Mine stationer")
        } footer: {
            Text("Metrolisten indeholder alle 44 stationer og bruger ingen API-kald. Hold og træk for at ændre rækkefølgen, eller swipe for at slette.")
        }
    }

    private var timeWindowsSection: some View {
        Section {
            ForEach($settings.windows) { $window in
                TimeWindowEditor(window: $window)
            }
            .onDelete { offsets in
                settings.windows.remove(atOffsets: offsets)
            }

            Button {
                settings.windows.append(TimeWindow())
            } label: {
                Label("Tilføj tidsrum", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            }
        } header: {
            Text("Widget-tidsrum")
        } footer: {
            Text("Widgetten henter kun afgange i aktive tidsrum. Udenfor viser den seneste data og bruger ingen API-kald.")
        }
    }

    private var unavailableStationIDs: Set<String> {
        Set(settings.stations.enumerated().compactMap { index, station in
            index == pickerIndex ? nil : station.id
        })
    }

    private var canSearch: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
            && !settings.accessId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !searching
    }

    private func select(_ picked: MetroStation) {
        let station = Station(id: picked.extId, name: picked.name)
        if let index = pickerIndex, settings.stations.indices.contains(index) {
            settings.stations[index] = station
        } else if !settings.stations.contains(where: { $0.id == station.id }) {
            settings.stations.append(station)
        }
        showPicker = false
    }

    private func addSearchResult(_ result: Station) {
        guard !settings.stations.contains(where: { $0.id == result.id }) else { return }
        settings.stations.append(result)
    }

    private func search() async {
        guard canSearch else {
            if settings.accessId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchError = "Indsæt først dit Access ID."
            }
            return
        }
        searching = true
        searchError = nil
        guard BudgetStore.shared.tryConsume(hardStop: settings.hardStopAtLimit) else {
            searchError = "API-kvoten er opbrugt."
            searching = false
            return
        }
        do {
            searchResults = try await RejseplanenAPI.searchStations(
                query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
                accessId: settings.accessId
            )
            if searchResults.isEmpty {
                searchError = "Ingen stationer fundet — prøv en anden stavemåde."
            }
        } catch {
            searchError = error.localizedDescription
        }
        searching = false
    }
}

private struct StationEditorRow: View {
    @Binding var station: Station
    var changeStation: () -> Void
    var chooseDirections: () -> Void

    private var metro: MetroStation? {
        MetroStations.all.first(where: { $0.extId == station.id })
    }

    private var directionSummary: String {
        station.directions.isEmpty ? "Alle retninger" : station.directions.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "m.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(station.shortName.isEmpty ? "Ny station" : station.shortName)
                        .font(.headline)
                    Text(metro?.lines ?? "Stop-ID \(station.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Skift", action: changeStation)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Button(action: chooseDirections) {
                HStack {
                    Label(directionSummary, systemImage: "arrow.triangle.branch")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            DisclosureGroup("Avanceret") {
                VStack(spacing: 10) {
                    TextField("Visningsnavn", text: $station.name)
                    TextField("Stop-ID", text: $station.id)
                        .font(.caption.monospaced())
                        .privateKeyInput()
                    TextField("Linjer, fx M1,M2 — tom viser alle", text: $station.lineFilter)
                        .lineFilterInput()
                    TextField("Retning som fritekst — tom viser alle", text: $station.directionFilter)
                }
                .padding(.top, 8)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

/// Alle metrostationer søges lokalt, så valg her bruger ingen API-kald.
struct StationPickerSheet: View {
    let title: String
    let unavailableIDs: Set<String>
    var onPick: (MetroStation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var matches: [MetroStation] {
        MetroStations.search(query)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Alle 44 metrostationer er gemt i appen. Søgning her bruger 0 API-kald.", systemImage: "bolt.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if matches.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    Section(query.isEmpty ? "Alle stationer" : "Resultater") {
                        ForEach(matches) { station in
                            Button {
                                onPick(station)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "m.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(station.short)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(station.lines)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if unavailableIDs.contains(station.extId) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(unavailableIDs.contains(station.extId))
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Søg metrostation")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Luk") { dismiss() }
                }
            }
        }
    }
}

/// Retninger kommer fra seneste afgange plus kendte endestationer og bruger 0 API-kald.
struct DirectionPickerSheet: View {
    var station: Station
    var cache: [Departure]
    var initial: Set<String>
    var onDone: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []

    private var live: [String] {
        RejseplanenAPI.knownDirections(for: station, in: cache)
    }

    private var hints: [String] {
        let lines = MetroStations.all.first(where: { $0.extId == station.id })?.lines ?? ""
        return MetroStations.termini(forLineHint: lines).filter { !live.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selection = []
                    } label: {
                        HStack {
                            Label("Vis alle retninger", systemImage: "arrow.left.arrow.right")
                            Spacer()
                            if selection.isEmpty {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }

                if !live.isEmpty {
                    Section("Set i seneste afgange") {
                        ForEach(live, id: \.self) { direction in
                            Toggle(direction, isOn: binding(direction))
                        }
                    }
                }

                if !hints.isEmpty {
                    Section("Typiske endestationer") {
                        ForEach(hints, id: \.self) { direction in
                            Toggle(direction, isOn: binding(direction))
                        }
                    }
                }

                if live.isEmpty && hints.isEmpty {
                    ContentUnavailableView(
                        "Ingen retninger endnu",
                        systemImage: "arrow.triangle.branch",
                        description: Text("Hent afgange på forsiden først, og prøv derefter igen.")
                    )
                }
            }
            .navigationTitle(station.shortName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuller") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gem") {
                        onDone(Array(selection))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selection = initial
            }
        }
    }

    private func binding(_ direction: String) -> Binding<Bool> {
        Binding(
            get: { selection.contains(direction) },
            set: { selected in
                if selected {
                    selection.insert(direction)
                } else {
                    selection.remove(direction)
                }
            }
        )
    }
}

private struct TimeWindowEditor: View {
    @Binding var window: TimeWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $window.enabled) {
                Label(window.enabled ? "Aktivt tidsrum" : "Tidsrum slået fra", systemImage: "clock.fill")
                    .font(.headline)
            }

            if window.enabled {
                HStack(spacing: 18) {
                    MinuteTimePicker(title: "Fra", minutes: $window.startMinutes)
                    MinuteTimePicker(title: "Til", minutes: $window.endMinutes)
                }
                WeekdayPicker(selection: $window.weekdays)
            }
        }
        .padding(.vertical, 5)
    }
}

private struct MinuteTimePicker: View {
    let title: String
    @Binding var minutes: Int

    var body: some View {
        DatePicker(title, selection: dateBinding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.compact)
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                let start = Calendar.current.startOfDay(for: Date())
                return Calendar.current.date(byAdding: .minute, value: minutes, to: start) ?? start
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    private let days = [(2, "M"), (3, "T"), (4, "O"), (5, "T"), (6, "F"), (7, "L"), (1, "S")]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { day in
                Button {
                    if selection.contains(day.0) {
                        selection.remove(day.0)
                    } else {
                        selection.insert(day.0)
                    }
                } label: {
                    Text(day.1)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(selection.contains(day.0) ? Color.accentColor : Color.secondary.opacity(0.12))
                        .foregroundStyle(selection.contains(day.0) ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dayName(day.0))
                .accessibilityAddTraits(selection.contains(day.0) ? .isSelected : [])
            }
        }
    }

    private func dayName(_ value: Int) -> String {
        [1: "Søndag", 2: "Mandag", 3: "Tirsdag", 4: "Onsdag", 5: "Torsdag", 6: "Fredag", 7: "Lørdag"][value] ?? ""
    }
}

private extension View {
    @ViewBuilder
    func privateKeyInput() -> some View {
#if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
#else
        self
#endif
    }

    @ViewBuilder
    func stationSearchInput() -> some View {
#if os(iOS)
        textInputAutocapitalization(.words)
            .submitLabel(.search)
#else
        self
#endif
    }

    @ViewBuilder
    func lineFilterInput() -> some View {
#if os(iOS)
        textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
#else
        self
#endif
    }
}
