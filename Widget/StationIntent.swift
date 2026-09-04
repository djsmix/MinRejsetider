import AppIntents
import Foundation

// MARK: - Tidsrum for widgetten (vælges på widgetten — ingen App Groups nødvendig)
enum TidsrumPreset: String, AppEnum {
    case pendler
    case lang
    case altid

    static var typeDisplayName: LocalizedStringResource = "Tidsrum"
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tidsrum"

    static var caseDisplayRepresentations: [TidsrumPreset: DisplayRepresentation] = [
        .pendler: DisplayRepresentation(title: "Pendler", subtitle: "Man–fre 06–09 + 15–18:30"),
        .lang: DisplayRepresentation(title: "Lang dag", subtitle: "Alle dage 05–23"),
        .altid: DisplayRepresentation(title: "Altid", subtitle: "Henter hele døgnet"),
    ]

    var displayRepresentation: DisplayRepresentation {
        switch self {
        case .pendler:
            DisplayRepresentation(title: "Pendler", subtitle: "Man–fre 06–09 + 15–18:30")
        case .lang:
            DisplayRepresentation(title: "Lang dag", subtitle: "Alle dage 05–23")
        case .altid:
            DisplayRepresentation(title: "Altid", subtitle: "Henter hele døgnet (bruger mere kvote)")
        }
    }

    func windows() -> [TimeWindow] {
        switch self {
        case .pendler:
            [TimeWindow(weekdays: [2, 3, 4, 5, 6], startMinutes: 6*60, endMinutes: 9*60),
             TimeWindow(weekdays: [2, 3, 4, 5, 6], startMinutes: 15*60, endMinutes: 18*60+30)]
        case .lang:
            [TimeWindow(weekdays: [1, 2, 3, 4, 5, 6, 7], startMinutes: 5*60, endMinutes: 23*60)]
        case .altid:
            []
        }
    }

    func isActive(now: Date = Date()) -> Bool {
        if self == .altid { return true }
        return ScheduleGate.isActive(now: now, windows: windows())
    }

    func nextStart(after date: Date) -> Date? {
        if self == .altid { return Calendar.current.date(byAdding: .minute, value: 5, to: date) }
        return ScheduleGate.nextWindowStart(after: date, windows: windows())
    }
}

// MARK: - Metrostation som valgmulighed (alle 44, indbygget — 0 API-kald)
enum MetroStationOption: String, AppEnum {
    case vanloese = "8603301"
    case flintholm = "8603302"
    case lindevang = "8603303"
    case fasanvej = "8603304"
    case frederiksberg = "8603305"
    case forum = "8603306"
    case noerreport = "8603307"
    case kongensNytorv = "8603308"
    case christianshavn = "8603309"
    case islandsBrygge = "8603310"
    case drByen = "8603311"
    case sundby = "8603312"
    case bellaCenter = "8603313"
    case oerestad = "8603315"
    case vestamager = "8603317"
    case amagerbro = "8603321"
    case lergravsparken = "8603322"
    case oeresund = "8603323"
    case amagerStrand = "8603324"
    case femoeren = "8603326"
    case kastrup = "8603327"
    case lufthavnen = "8603328"
    case koebenhavnH = "8603330"
    case raadhuspladsen = "8603331"
    case gammelStrand = "8603332"
    case marmorkirken = "8603333"
    case oesterport = "8603334"
    case trianglen = "8603335"
    case poulHenningsen = "8603336"
    case vibenshus = "8603337"
    case skjoldsPlads = "8603338"
    case noerrebro = "8603339"
    case noerrebrosRunddel = "8603340"
    case nuuksPlads = "8603341"
    case akselMoellers = "8603342"
    case frederiksbergAlle = "8603343"
    case enghavePlads = "8603344"
    case orientkaj = "8603345"
    case nordhavn = "8603346"
    case havneholmen = "8603347"
    case enghaveBrygge = "8603348"
    case sluseholmen = "8603349"
    case mozartsPlads = "8603350"
    case koebenhavnSyd = "8603351"

    static var typeDisplayName: LocalizedStringResource = "Metrostation"
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Metrostation"

    var station: MetroStation {
        MetroStations.all.first(where: { $0.extId == rawValue })
            ?? MetroStation(extId: rawValue, name: rawValue, short: rawValue, lines: "")
    }

    var displayRepresentation: DisplayRepresentation {
        let s = station
        return DisplayRepresentation(title: "\(s.short)", subtitle: "\(s.lines)")
    }

    static var caseDisplayRepresentations: [MetroStationOption: DisplayRepresentation] = [
        .vanloese: DisplayRepresentation(title: "Vanløse", subtitle: "M1 · M2"),
        .flintholm: DisplayRepresentation(title: "Flintholm", subtitle: "M1 · M2"),
        .lindevang: DisplayRepresentation(title: "Lindevang", subtitle: "M1 · M2"),
        .fasanvej: DisplayRepresentation(title: "Fasanvej", subtitle: "M1 · M2"),
        .frederiksberg: DisplayRepresentation(title: "Frederiksberg", subtitle: "M1 · M2 · M3"),
        .forum: DisplayRepresentation(title: "Forum", subtitle: "M1 · M2"),
        .noerreport: DisplayRepresentation(title: "Nørreport", subtitle: "M1 · M2"),
        .kongensNytorv: DisplayRepresentation(title: "Kongens Nytorv", subtitle: "M1 · M2 · M3 · M4"),
        .christianshavn: DisplayRepresentation(title: "Christianshavn", subtitle: "M1 · M2"),
        .islandsBrygge: DisplayRepresentation(title: "Islands Brygge", subtitle: "M1"),
        .drByen: DisplayRepresentation(title: "DR Byen", subtitle: "M1"),
        .sundby: DisplayRepresentation(title: "Sundby", subtitle: "M1"),
        .bellaCenter: DisplayRepresentation(title: "Bella Center", subtitle: "M1"),
        .oerestad: DisplayRepresentation(title: "Ørestad", subtitle: "M1"),
        .vestamager: DisplayRepresentation(title: "Vestamager", subtitle: "M1"),
        .amagerbro: DisplayRepresentation(title: "Amagerbro", subtitle: "M2"),
        .lergravsparken: DisplayRepresentation(title: "Lergravsparken", subtitle: "M2"),
        .oeresund: DisplayRepresentation(title: "Øresund", subtitle: "M2"),
        .amagerStrand: DisplayRepresentation(title: "Amager Strand", subtitle: "M2"),
        .femoeren: DisplayRepresentation(title: "Femøren", subtitle: "M2"),
        .kastrup: DisplayRepresentation(title: "Kastrup", subtitle: "M2"),
        .lufthavnen: DisplayRepresentation(title: "Lufthavnen", subtitle: "M2"),
        .koebenhavnH: DisplayRepresentation(title: "København H", subtitle: "M3 · M4"),
        .raadhuspladsen: DisplayRepresentation(title: "Rådhuspladsen", subtitle: "M3 · M4"),
        .gammelStrand: DisplayRepresentation(title: "Gammel Strand", subtitle: "M3 · M4"),
        .marmorkirken: DisplayRepresentation(title: "Marmorkirken", subtitle: "M3 · M4"),
        .oesterport: DisplayRepresentation(title: "Østerport", subtitle: "M3 · M4"),
        .trianglen: DisplayRepresentation(title: "Trianglen", subtitle: "M3"),
        .poulHenningsen: DisplayRepresentation(title: "Poul Henningsens Pl.", subtitle: "M3"),
        .vibenshus: DisplayRepresentation(title: "Vibenshus Runddel", subtitle: "M3"),
        .skjoldsPlads: DisplayRepresentation(title: "Skjolds Plads", subtitle: "M3"),
        .noerrebro: DisplayRepresentation(title: "Nørrebro", subtitle: "M3"),
        .noerrebrosRunddel: DisplayRepresentation(title: "Nørrebros Runddel", subtitle: "M3"),
        .nuuksPlads: DisplayRepresentation(title: "Nuuks Plads", subtitle: "M3"),
        .akselMoellers: DisplayRepresentation(title: "Aksel Møllers Have", subtitle: "M3"),
        .frederiksbergAlle: DisplayRepresentation(title: "Frederiksberg Allé", subtitle: "M3"),
        .enghavePlads: DisplayRepresentation(title: "Enghave Plads", subtitle: "M3"),
        .orientkaj: DisplayRepresentation(title: "Orientkaj", subtitle: "M4"),
        .nordhavn: DisplayRepresentation(title: "Nordhavn", subtitle: "M4"),
        .havneholmen: DisplayRepresentation(title: "Havneholmen", subtitle: "M4"),
        .enghaveBrygge: DisplayRepresentation(title: "Enghave Brygge", subtitle: "M4"),
        .sluseholmen: DisplayRepresentation(title: "Sluseholmen", subtitle: "M4"),
        .mozartsPlads: DisplayRepresentation(title: "Mozarts Plads", subtitle: "M4"),
        .koebenhavnSyd: DisplayRepresentation(title: "København Syd", subtitle: "M4"),
    ]
}

// MARK: - Selve konfigurationen (langt tryk på widget → Rediger)
struct StationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Vælg station"
    static var description = IntentDescription("Vis afgange for præcis den station og retning du bruger.")

    @Parameter(title: "Station", default: .kongensNytorv)
    var station: MetroStationOption

    @Parameter(title: "Retning", description: "Fx Vestamager. Lad den stå tom for alle retninger.")
    var direction: String?

    @Parameter(title: "Tidsrum", default: .pendler)
    var tidsrum: TidsrumPreset

    @Parameter(title: "Access ID", description: "Dit private Rejseplanen accessId (UUID). Samme som i appen — findes under Indstillinger.")
    var accessId: String?
}
