import Foundation

/// Rejseplanen API 2.0 — https://www.rejseplanen.dk/api/
/// Auth: ?accessId=<UUID>&format=json
/// VIGTIGT for budget: brug multiDepartureBoard med idList=A|B så 2 stationer = 1 kald.
/// Fejl med serverens egen forklaring (fx SVC_LOC ved ugyldigt stop-ID).
struct RPError: Error, LocalizedError {
    var status: Int
    var serverText: String
    var errorDescription: String? {
        "Rejseplanen svarede \(status): \(serverText)"
    }
}

enum RejseplanenAPI {
    static let base = "https://www.rejseplanen.dk/api"

    private static func check(_ data: Data, _ resp: URLResponse) throws -> Data {
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            var text = "HTTP \(status)"
            if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let t = (j["errorText"] as? String) ?? (j["internalErrorTextOut"] as? String) {
                text += " – " + t
            }
            throw RPError(status: status, serverText: text)
        }
        return data
    }

    // MARK: - Departures (multi = 1 kald for alle stationer)
    static func fetchMultiDepartures(stations: [Station], accessId: String, maxPerStation: Int = 8) async throws -> [Departure] {
        let ids = stations.map { $0.id }.joined(separator: "|")
        guard !ids.isEmpty else { return [] }
        var comps = URLComponents(string: base + "/multiDepartureBoard")!
        comps.queryItems = [
            .init(name: "accessId", value: accessId),
            .init(name: "format", value: "json"),
            .init(name: "idList", value: ids),
            .init(name: "duration", value: "60"),
            .init(name: "maxJourneys", value: String(maxPerStation * stations.count)),
            .init(name: "type", value: "DEP")
        ]
        let url = comps.url!
        let (data, resp) = try await URLSession.shared.data(from: url)
        try check(data, resp)
        return try parseMulti(data: data, stations: stations)
    }

    /// Robust variant: prøv ét multi-kald; hvis serveren afviser (fx ét ugyldigt
    /// ID ødelægger hele listen), fald tilbage til ét kald pr. station og meld
    /// tilbage hvilke ID'er der er dårlige.
    /// Returnerer (afgange, dårligeStationsNavne, antalKaldBrugt).
    /// Koster 1 kald i normaltilfældet, ellers 1 + antal stationer.
    static func fetchResilient(stations: [Station], accessId: String) async throws -> ([Departure], [String], Int) {
        do {
            let deps = try await fetchMultiDepartures(stations: stations, accessId: accessId)
            return (deps, [], 1)
        } catch {
            // Fallback: isolér den dårlige station
            var all: [Departure] = []
            var bad: [String] = []
            for st in stations {
                do {
                    all += try await fetchSingleDepartures(station: st, accessId: accessId)
                } catch {
                    bad.append("\(st.name) (ID \(st.id))")
                }
            }
            if all.isEmpty && !bad.isEmpty { throw error }
            return (all, bad, 1 + stations.count)
        }
    }

    /// Single (bruges kun som fallback / ved 1 station)
    static func fetchSingleDepartures(station: Station, accessId: String) async throws -> [Departure] {
        var comps = URLComponents(string: base + "/departureBoard")!
        comps.queryItems = [
            .init(name: "accessId", value: accessId),
            .init(name: "format", value: "json"),
            .init(name: "id", value: station.id),
            .init(name: "duration", value: "60"),
            .init(name: "maxJourneys", value: "12"),
            .init(name: "type", value: "DEP")
        ]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        try check(data, resp)
        return try parseSingle(data: data, station: station)
    }

    // MARK: - Station-søgning (koster også 1 kald — cache resultatet!)
    static func searchStations(query: String, accessId: String) async throws -> [Station] {
        var comps = URLComponents(string: base + "/location.name")!
        comps.queryItems = [
            .init(name: "accessId", value: accessId),
            .init(name: "format", value: "json"),
            .init(name: "input", value: query)
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        // location.name svarer enten med stopLocationOrCoordLocation eller StopLocation-liste
        var out: [Station] = []
        if let arr = (json["stopLocationOrCoordLocation"] as? [[String: Any]]) {
            for item in arr {
                if let s = item["StopLocation"] as? [String: Any],
                   let id = (s["extId"] as? String) ?? (s["id"] as? String),
                   let name = s["name"] as? String {
                    out.append(Station(id: id, name: name, lineFilter: "", directionFilter: ""))
                }
            }
        }
        return out
    }

    // MARK: - Parsing
    private static func parseMulti(data: Data, stations: [Station]) throws -> [Departure] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        // multiDepartureBoard svarer med "Departure" array hvor hvert item har stop-field
        let deps = json["Departure"] as? [[String: Any]]
            ?? (json["MultiDepartureBoard"] as? [String: Any])?["Departure"] as? [[String: Any]]
            ?? []
        return deps.compactMap { mapDeparture($0, stations: stations) }
    }

    private static func parseSingle(data: Data, station: Station) throws -> [Departure] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let deps = json["Departure"] as? [[String: Any]]
            ?? (json["DepartureBoard"] as? [String: Any])?["Departure"] as? [[String: Any]]
            ?? []
        return deps.compactMap { mapDeparture($0, stations: [station]) }
    }

    private static func mapDeparture(_ d: [String: Any], stations: [Station]) -> Departure? {
        // stop-id kan ligge i flere felter afhængigt af version
        let stopId = (d["stopExtId"] as? String) ?? (d["stopid"] as? String) ?? (d["stop"] as? String) ?? ""
        let name = (d["name"] as? String) ?? ""
        // Product kan være dict eller array
        var line = ""
        if let p = d["Product"] as? [String: Any] {
            line = (p["line"] as? String) ?? (p["name"] as? String) ?? ""
        } else if let arr = d["Product"] as? [[String: Any]], let p = arr.first {
            line = (p["line"] as? String) ?? (p["name"] as? String) ?? ""
        }
        if line.isEmpty { line = name }
        let direction = (d["direction"] as? String) ?? ""
        let time = (d["time"] as? String) ?? ""
        let rtTime = d["rtTime"] as? String
        let track = (d["rtTrack"] as? String) ?? (d["track"] as? String)
        let cancelled = (d["cancelled"] as? Bool) ?? false
        let stopName = (d["stop"] as? String) ?? stations.first(where: { $0.id == stopId })?.name ?? stopId

        // delay i minutter
        var delay = 0
        if let rt = rtTime, rt != time {
            delay = minutesBetween(plan: time, real: rt)
        }

        return Departure(stopId: stopId, stopName: stopName, line: line, name: name,
                         direction: direction, time: time, rtTime: rtTime,
                         track: track, cancelled: cancelled, delayMinutes: delay)
    }

    private static func minutesBetween(plan: String, real: String) -> Int {
        func m(_ s: String) -> Int? {
            let p = s.split(separator: ":").compactMap { Int($0) }
            guard p.count >= 2 else { return nil }
            return p[0]*60 + p[1]
        }
        guard let a = m(plan), let b = m(real) else { return 0 }
        var diff = b - a
        if diff < -12*60 { diff += 24*60 } // midnat
        return max(0, diff)
    }

    // MARK: - Klient-side filtrering (SPARER kald: filtrér lokalt, ikke med nye requests)
    static func applyFilter(_ deps: [Departure], for station: Station) -> [Departure] {
        deps.filter { d in
            guard d.stopId == station.id || station.id.isEmpty || d.stopName == station.name else {
                // multi-svar uden stopId-match: behold hvis kun 1 station er konfigureret
                return false
            }
            if !station.lineFilter.isEmpty {
                let allowed = station.lineFilter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
                if !allowed.contains(d.line.uppercased()) && !allowed.contains(d.name.uppercased()) { return false }
            }
            if !station.directions.isEmpty {
                // Valgte retninger — tilgivende match begge veje ("Lufthavnen" ⇔ "Lufthavn")
                let dd = d.direction.lowercased()
                let ok = station.directions.contains { s in
                    let sl = s.lowercased()
                    return dd.contains(sl) || sl.contains(dd)
                }
                if !ok { return false }
            } else if !station.directionFilter.isEmpty {
                if !d.direction.localizedCaseInsensitiveContains(station.directionFilter) { return false }
            }
            return true
        }
    }

    /// Unikke retninger set i cache for en station — bruges til retningsvælgeren.
    static func knownDirections(for station: Station, in deps: [Departure]) -> [String] {
        let mine = deps.filter { $0.stopId == station.id || $0.stopName == station.name }
        return Array(Set(mine.map { $0.direction }.filter { !$0.isEmpty })).sorted()
    }
}
