import SwiftUI

/// Her indtaster du selv metro-stationer + tidsrum.
/// Hver søgning koster 1 API-kald — skriv præcist for at spare.
struct SettingsView: View {
    @Binding var settings: AppSettings
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [Station] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var pickerIndex: Int?  // hvilken stationsrække vælger fra listen?
    @State private var showPicker = false
    @State private var dirIndex: Int?
    @State private var showDirections = false

    private func directionLabel(_ i: Int) -> String {
        let d = settings.stations[i].directions
        return d.isEmpty ? "Retninger: Alle" : "Retninger: \(d.joined(separator: ", "))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rejseplanen accessId") {
                    TextField("UUID", text: $settings.accessId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.caption.monospaced())
                    if settings.accessId.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("INDSÆT DIN NØGLE HER — uden den kan appen ikke hente. Din private UUID fra Rejseplanen Labs.")
                            .font(.caption).foregroundStyle(.red)
                    } else {
                        Text("Din private nøgle. Del den ikke. Alle kald tæller mod 50.000/md.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Mine stationer (metro)") {
                    ForEach(settings.stations.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(settings.stations[i].name.isEmpty ? "Ny station" : settings.stations[i].name)
                                    .font(.headline)
                                Spacer()
                                Button("Vælg fra liste") { pickerIndex = i; showPicker = true }
                                    .font(.subheadline)
                            }
                            TextField("Navn", text: $settings.stations[i].name)
                            TextField("Stop-ID (fx 8603330)", text: $settings.stations[i].id)
                                .font(.caption.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            TextField("Linjer (fx M1,M2 — tom = alle)", text: $settings.stations[i].lineFilter)
                                .font(.caption)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                            Button(directionLabel(i)) {
                                dirIndex = i; showDirections = true
                            }
                            .font(.subheadline)
                            TextField("Retning fritekst (legacy — tom = alle)", text: $settings.stations[i].directionFilter)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { settings.stations.remove(atOffsets: $0) }
                    Button("Tilføj station") {
                        settings.stations.append(Station(id: "", name: "", lineFilter: "", directionFilter: ""))
                    }

                    DisclosureGroup("Avanceret: søg via API (koster 1 kald)") {
                        HStack {
                            TextField("Søg station", text: $searchText)
                            Button("Søg") { Task { await search() } }
                                .disabled(searchText.count < 3 || searching)
                        }
                        if searching { ProgressView() }
                        if let e = searchError { Text(e).font(.caption).foregroundStyle(.red) }
                        ForEach(searchResults, id: \.id) { r in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(r.name).font(.subheadline)
                                    Text("ID: \(r.id)").font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Tilføj") {
                                    settings.stations.append(r)
                                }
                            }
                        }
                    }
                    Text("Vælg fra listen — det koster 0 kald. API-søgning koster 1 kald pr. søgning.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Widget-tidsvinduer (KUN her må widgets kalde)") {
                    ForEach($settings.windows) { $w in
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(w.label, isOn: $w.enabled)
                            Stepper("Start: \(TimeWindow.mm(w.startMinutes))", value: $w.startMinutes, in: 0...1439, step: 15)
                            Stepper("Slut: \(TimeWindow.mm(w.endMinutes))", value: $w.endMinutes, in: 0...1439, step: 15)
                            WeekdayPicker(selection: $w.weekdays)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { settings.windows.remove(atOffsets: $0) }
                    Button("Tilføj vindue (fx morgen)") {
                        settings.windows.append(TimeWindow())
                    }
                    Text("Eksempel: Man–fre 06:00–09:00 + 15:00–18:30. Uden for vinduer laver widgets NUL kald — de viser cache og vågner først ved næste vindue.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Kvotestop") {
                    Toggle("Hårdt stop ved 50.000 kald/md.", isOn: $settings.hardStopAtLimit)
                    Text(BudgetStore.shared.statusText).font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Indstillinger")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gem") { onSave(); dismiss() }
                }
            }
            .sheet(isPresented: $showPicker) {
                StationPickerSheet { picked in
                    if let i = pickerIndex, settings.stations.indices.contains(i) {
                        settings.stations[i].id = picked.extId
                        settings.stations[i].name = picked.name
                    }
                    showPicker = false
                }
            }
            .sheet(isPresented: $showDirections) {
                if let i = dirIndex, settings.stations.indices.contains(i) {
                    DirectionPickerSheet(
                        station: settings.stations[i],
                        cache: SharedStore.loadCache()?.departures ?? [],
                        initial: Set(settings.stations[i].directions)
                    ) { picked in
                        settings.stations[i].directions = picked.sorted()
                    }
                }
            }
        }
    }
    private func search() async {
        searching = true; searchError = nil
        guard BudgetStore.shared.tryConsume(hardStop: settings.hardStopAtLimit) else {
            searchError = "Kvoten er opbrugt."; searching = false; return
        }
        do {
            searchResults = try await RejseplanenAPI.searchStations(query: searchText, accessId: settings.accessId)
            if searchResults.isEmpty { searchError = "Ingen fund — prøv andet stavemåde." }
        } catch {
            searchError = error.localizedDescription
        }
        searching = false
    }
}

/// Dropdown med alle metrostationer — søgning sker lokalt, koster 0 kald.
struct StationPickerSheet: View {
    var onPick: (MetroStation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List(MetroStations.search(query)) { st in
                Button {
                    onPick(st); dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(st.short).font(.headline)
                            Text("ID \(st.extId)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(st.lines).font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            .searchable(text: $query, prompt: "Søg station")
            .navigationTitle("Vælg metrostation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Luk") { dismiss() }
                }
            }
        }
    }
}

/// Retningsvælger: kryds af hvilke retninger tavlen skal vise (tom = alle).
/// Forslag kommer fra live-afgange i cachen + kendte endestationer. Koster 0 kald.
struct DirectionPickerSheet: View {
    var station: Station
    var cache: [Departure]
    var initial: Set<String>
    var onDone: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sel: Set<String> = []

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
                if live.isEmpty && hints.isEmpty {
                    Text("Hent først afgange på forsiden (træk ned), så kender jeg retningerne herfra. Kom tilbage bagefter.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !live.isEmpty {
                    Section("Set i afgange") {
                        ForEach(live, id: \.self) { d in Toggle(d, isOn: binding(d)) }
                    }
                }
                if !hints.isEmpty {
                    Section("Endestationer") {
                        ForEach(hints, id: \.self) { d in Toggle(d, isOn: binding(d)) }
                    }
                }
                Section {
                    Button("Vis alle retninger") { sel = [] }
                        .disabled(sel.isEmpty)
                }
            }
            .navigationTitle("Retninger: \(station.shortName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuller") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gem") { onDone(Array(sel)); dismiss() }
                }
            }
            .onAppear { if sel.isEmpty { sel = initial } }
        }
    }

    private func binding(_ d: String) -> Binding<Bool> {
        Binding(get: { sel.contains(d) }, set: { on in
            if on { sel.insert(d) } else { sel.remove(d) }
        })
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    let days = [(2,"M"),(3,"T"),(4,"O"),(5,"T"),(6,"F"),(7,"L"),(1,"S")]
    var body: some View {
        HStack {
            ForEach(days, id: \.0) { d in
                Button(d.1) {
                    if selection.contains(d.0) { selection.remove(d.0) } else { selection.insert(d.0) }
                }
                .frame(width: 30, height: 30)
                .background(selection.contains(d.0) ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundStyle(selection.contains(d.0) ? .white : .primary)
                .clipShape(Circle())
                .font(.caption.bold())
            }
        }
    }
}
