# MinRejsetider — din egen Rejsetider-klon (kun til dig, iOS 26)

Personlig afgangstavle til metro med **hårdt budget-loft på 50.000 kald/md.**

## Hvorfor den ikke løber løbsk

50.000/md = ~1.666/dag = ~69/time i snit. Derfor:

1. **Ét kald for alle stationer**: bruger `multiDepartureBoard?idList=A|B` i stedet for ét kald pr. station.
2. **Appen henter kun når den er åben**, min. 60 sek. mellem kald (pull-to-refresh + 60-sek timer).
3. **Widgets må KUN kalde i dine tidsvinduer** (fx man–fre 06–09 + 15–18:30):
   - Uden for vindue = **0 kald**. Viser cache + "Næste: 06:00", og sætter næste refresh til vindues-start.
   - I vindue = max ét kald pr. 5 min. Genbruger cache hvis den er frisk.
4. **Filtrér lokalt**: linjer/retninger filtreres på telefonen, ikke med nye API-kald.
5. **Månedstæller + hårdt stop**: hvert kald tælles i App Group (`apiCalls_YYYY-MM`). Ved 50.000 blokeres kald (kan slås fra). Advarsel ved 80%.
6. **Søgning koster også**: stations-søgning (`location.name`) = 1 kald. Søg én gang, gem ID'et.

Regnestykke ved 2 stationer, 2 vinduer á 3 timer på hverdage:
- Widget: 12 kald/time × 6 timer × 22 dage = ~1.584 kald/md.
- App åben 30 min/dag: ~30 kald/dag × 30 = ~900 kald/md.
- Total ~2.500/md = **5% af kvoten**. Masser af luft.

## Opsætning (5 min, uden Mac)

Du har ingen Mac — derfor bygges IPA'en i skyen og signeres på din Windows-PC.

### 1. Læg på GitHub
1. Koden indeholder ingen nøgler — du kan roligt have repoet offentligt eller privat.
2. Upload **indholdet af `MinRejsetider/`-mappen** som repo-rod (så `project.yml` ligger i rod).
3. Gå til fanen **Actions** → kør **"Build unsigned IPA"** → download `MinRejsetider-unsigned` artifact (en `.ipa`).

> Alternativt: `git init` i MinRejsetider-mappen og push.

### 2. Signér + installér på iOS 26 (Windows)
Vælg én:

**A. Sideloadly (nemmest, Windows):**
1. Installér Sideloadly + iTunes fra Apple (ikke Microsoft Store).
2. Tilslut iPhone → trust.
3. Træk `MinRejsetider-unsigned.ipa` ind, indtast dit Apple-ID (gratis dev-cert, 7 dages holdbarhed).
4. På iPhone: Indstillinger → Generelt → VPN og enhedsadministration → godkend dit Apple-ID.
5. Gentag hver 7. dag (eller brug SideStore for auto-refresh).

**B. SideStore (ingen PC efter setup, virker på iOS 26):**
1. Følg SideStore + WireGuard guide, pair med SideServer på Windows.
2. Upload IPA'en i SideStore → signer med dit gratis Anisette certifikat.
3. Aktivér Background Refresh så widgets kan opdatere.

**C. AltStore:**
1. AltServer på Windows, samme WiFi.
2. AltStore på telefon → My Apps → + → vælg IPA'en.

### 3. Første start
1. Åbn appen → ⚙️ → indsæt dit Rejseplanen accessId (UUID) øverst. Uden det kan intet hente.
2. Tilføj dine 2 metrostationer: Søg (fx "Kongens Nytorv") → Tilføj. Sæt linje-filter `M1,M2` hvis du vil.
3. Ret tidsvinduer til dine pendler-tider.
4. Læg widget på hjemmeskærm/låseskærm → den viser straks cache og går live i næste vindue.
5. Husk App Group: `group.dk.minrejsetider.shared` skal matche i begge entitlements — den gør det allerede. Ved gratis signing skal du evt. ændre bundle-ID til noget unikt (`dk.ditnavn.minrejsetider`).

## Filer
- `Shared/Models.swift` — stationer, vinduer, afgange
- `Shared/RejseplanenAPI.swift` — multiDepartureBoard + lokal filtrering
- `Shared/BudgetStore.swift` — månedstæller
- `Shared/ScheduleGate.swift` — tidsvindue-logik
- `Shared/SharedCache.swift` — delt cache i App Group
- `App/ContentView.swift` + `SettingsView.swift` — UI
- `Widget/RejsetiderWidget.swift` — widget med 0-kald uden for vindue
- `project.yml` — xcodegen projekt (åbn med `xcodegen generate` hvis du en dag får Mac)
- `.github/workflows/build-ipa.yml` — bygger unsigned IPA på macOS-runner

## Privatliv
- Appen sender kun kald direkte til `rejseplanen.dk/api` med dit accessId.
- Ingen tracking, ingen server. Data (stationer, vinduer, cache, tæller) ligger kun i din App Group på telefonen.
- Dit accessId står kun på din telefon (app + widgets), aldrig i repoet.

## Næste skridt (forslag)
- Live Activity til "næste metro om X min" (kun i vindue).
- Push-varsling ved aflysning (kræver egen server — spring over for at spare kald).
- Favorit-retninger pr. vindue (morgen = mod centrum, eftermiddag = mod hjem).
