# HANDOVER — MinRejsetider (privat Rejseplanen-app + widget)

> Alt kode + historik ligger i dette repo. Det ENESTE der ikke ligger her,
> er Rejseplanen accessId (UUID) — det står kun på telefonen (app + widgets).
> Ejeren har det fra Rejseplanen Labs.

## Status (2026-09-04)
- Appen virker via eSign (repo-kilde nedenfor). Widgets installerer IKKE:
  eSign/certifikat dækker kun ét eksplicit bundle-ID.
- Certifikat: Apple Distribution, Team 26MAN4YX87, profil for App ID
  `26MAN4YX87.app.tomato6046.gypsum1956` → bundle `app.tomato6046.gypsum1956`.
  eSign omskriver vores app-hertil (basis virker). Widget-ID'et
  `dk.minrejsetider.MinRejsetider.widget` er ikke dækket → iOS afviser.
- Næste skridt (afventer ejer): få RustSign til at tilføje
  `app.tomato6046.gypsum1956.widget`, eller bruge RustSign Forge-upload,
  eller Sideloadly (afvist af ejer).

## Bygget (verificeret sundt)
- App bundle-ID: `dk.minrejsetider.MinRejsetider` (PRODUCT_BUNDLE_IDENTIFIER i project.yml)
- Widget bundle-ID: `dk.minrejsetider.MinRejsetider.widget` (SKAL have app-præfiks — iOS-krav)
- Appex valideret i CI: arm64, XPC!, exec-bit, MinimumOS 17.0, komplet plist.
- SwiftUI, iOS 17+ (virker på iOS 26). Xcode 16.4 via xcodegen (`project.yml`).

## Workflows (.github/workflows)
| Workflow | Resultat | Brug |
|---|---|---|
| build-ipa.yml | Fuld: app+widget+App Groups | Kræver betalt dev-konto |
| build-ipa-esign.yml | App-only, ingen widget/groups | eSign, virker nu |
| build-ipa-freewidget.yml | App+widget, ingen groups | eSign/Sideloadly, BLOKERET af cert |
| build-ipa-widgettest.yml | Statisk test-widget (dispatch only) | Isolationstest, kan slettes |
| update-source.yml | Opdaterer docs/*.json efter builds | Kører selv |

Alle builds laver GitHub Releases (`esign-N`, `freewidget-N`, `full-N`, `widgettest-N`).

## eSign app-kilde (virker, verificeret i eSign)
- `https://djsmix.github.io/MinRejsetider/esign.json` (eSign-format) og `apps.json` (AltStore-format)
- Hostet på GitHub Pages fra `/docs`. Auto-opdateres af update-source.yml.
- Formatet SKAL matche beviselige kilder: name, identifier, sourceURL,
  apps[{name, bundleIdentifier, developerName, subtitle, version, versionDate (ISO),
  versionDescription, downloadURL, localizedDescription, iconURL, tintColor,
  size, screenshotURLs[], beta}] + news[].

## App-logik (kort)
- Rejseplanen API 2.0: `multiDepartureBoard?idList=A|B` = 1 kald for alle stationer.
  Et ugyldigt ID giver 400 på HELE kaldet → `fetchResilient` falder tilbage til
  singles og flagger dårlige ID'er. Fejltekst fra server vises i UI.
- Budget: 50.000 kald/md. Tælles i UserDefaults (App Group hvor muligt),
  hårdt stop ved limit, advarsel ved 80%.
- Widgets må KUN kalde i tidsvinduer (ScheduleGate). Udenfor: 0 kald, sov til næste vindue.
- 44 metrostationer indbygget i `Shared/MetroStations.swift` (hentet via
  `location.name "(Metro)"`, maxNo=50) — stationsvalg koster 0 kald.
- Widget er konfigurerbar (AppIntent: station/retning/tidsrum/Access ID),
  vælges med langt tryk → Rediger. Access ID indtastes også på widgetten
  (deles ikke uden App Groups).
- Live-nedtælling: sekunder (M:SS) kun ≤120 s før afgang (`Shared/Countdown.swift`).
  Widget låseskærm bruger `Text(date, style: .timer)` = live uden kald.

## Ny PC — kom i gang
1. Installér git + GitHub CLI (`gh`), kør `gh auth login`.
2. `git clone https://github.com/djsmix/MinRejsetider.git`
3. Åbn mappen `MinRejsetider/` — det er repo-roden (project.yml ligger der).
4. Ingen secrets at kopiere: accessId tastes på telefonen. Alt andet er i repoet.
5. Push til `main` = nye builds + releases + opdateret eSign-kilde, automatisk.
