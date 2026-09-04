"""Opdaterer docs/apps.json (AltStore-format) og docs/esign.json (eSign-format)
med nyeste freewidget-* og esign-* releases. Kører i update-source workflow
ved hvert nyt release. Kræver `gh` CLI (findes på runneren).
"""
import json
import os
import pathlib
import subprocess

REPO = os.environ.get("GITHUB_REPOSITORY", "djsmix/MinRejsetider")
PAGES = "https://djsmix.github.io/MinRejsetider"
ICON = PAGES + "/icon.png"
BUNDLE = "dk.minrejsetider.MinRejsetider"


def sh(*args: str) -> str:
    return subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout


def latest_tag(prefix: str) -> str | None:
    out = sh("release", "list", "--repo", REPO, "--limit", "30", "--json", "tagName")
    tags = [r["tagName"] for r in json.loads(out)]
    cands = []
    for t in tags:
        if t.startswith(prefix + "-"):
            try:
                cands.append((int(t.split("-")[-1]), t))
            except ValueError:
                pass
    return max(cands)[1] if cands else None


def asset(tag: str) -> dict:
    out = sh("api", f"repos/{REPO}/releases/tags/{tag}",
             "--jq", "{date: .published_at, body: .body, assets: [.assets[] | {name, size, url: .browser_download_url, date: .updated_at}]}")
    j = json.loads(out)
    return {"tag": tag, "date": j["assets"][0]["date"] if j["assets"] else j["date"],
            "body": (j.get("body") or "")[:400],
            "file": j["assets"][0]}


def build() -> tuple[dict, dict]:
    fw_tag, es_tag = latest_tag("freewidget"), latest_tag("esign")
    if not fw_tag or not es_tag:
        raise SystemExit(f"Mangler tags (freewidget={fw_tag}, esign={es_tag}) — springer over.")
    fw, es = asset(fw_tag), asset(es_tag)

    def app_block(kind: str, a: dict, name: str, subtitle: str, desc: str, vdesc: str) -> dict:
        return {
            "name": name,
            "bundleIdentifier": BUNDLE,
            "developerName": "privat",
            "subtitle": subtitle,
            "version": f"1.0-{a['tag']}",
            "versionDate": a["date"],
            "versionDescription": vdesc or a["body"],
            "downloadURL": a["file"]["url"],
            "localizedDescription": desc,
            "iconURL": ICON,
            "tintColor": "DC262E",
            "size": a["file"]["size"],
        }

    apps = [
        app_block("freewidget", fw, "MinRejsetider + widget",
                  "App + konfigurerbar widget til gratis certs",
                  "Personlig metro-afgangstavle med konfigurerbar widget (vælg station, retning og tidsrum direkte på widgetten). Henter kun i dine tidsvinduer og holder sig langt under 50.000 API-kald/md. Usigneret — signér selv i eSign/Sideloadly. OBS: app og widget deler ikke indstillinger (ingen App Groups på gratis certs).",
                  "App + widget uden App Groups. Konfigurerbar widget, live-nedtælling, retningsvælger."),
        app_block("esign", es, "MinRejsetider basis",
                  "Kun appen, uden widget",
                  "Kun selve appen, uden widget. Mindste flade der kan drille ved signering — vælg denne hvis +widget-varianten ikke vil installere. Usigneret — signér selv i eSign/Sideloadly.",
                  "Samme app som +widget-varianten, men uden widget-extension."),
    ]
    apps_json = {
        "name": "MinRejsetider",
        "identifier": "dk.minrejsetider.source",
        "subtitle": "Privat metro-afgangstavle",
        "description": "Privat metro-afgangstavle (Rejseplanen API) med budget-loft på 50.000 kald/md. Til eSign/Sideloadly/SideStore/AltStore. Opdateres automatisk ved hvert build.",
        "iconURL": ICON,
        "website": f"https://github.com/{REPO}",
        "tintColor": "DC262E",
        "featuredApps": [BUNDLE],
        "apps": apps,
        "news": [],
    }
    esign_json = {
        "name": "MinRejsetider",
        "identifier": "dk.minrejsetider.source",
        "apps": [
            {"name": a["name"], "bundleID": BUNDLE, "version": a["version"],
             "icon": ICON, "down": a["downloadURL"], "size": a["size"],
             "description": a["localizedDescription"][:200]}
            for a in apps
        ],
    }
    return apps_json, esign_json


if __name__ == "__main__":
    docs = pathlib.Path("docs")
    docs.mkdir(exist_ok=True)
    apps_json, esign_json = build()
    (docs / "apps.json").write_text(json.dumps(apps_json, ensure_ascii=False, indent=2), encoding="utf-8")
    (docs / "esign.json").write_text(json.dumps(esign_json, ensure_ascii=False, indent=2), encoding="utf-8")
    print("docs/apps.json + docs/esign.json opdateret.")
