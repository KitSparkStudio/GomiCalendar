#!/usr/bin/env python3
"""Fetch nationwide Japanese municipalities and write Shared/Resources/japan_all_municipalities.json.

Source: https://github.com/hysakhr/japan-local-government-code-json (pref.json)
"""

from __future__ import annotations

import json
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Shared" / "Resources"
OUT = RES / "japan_all_municipalities.json"
SOURCE_URL = (
    "https://raw.githubusercontent.com/hysakhr/"
    "japan-local-government-code-json/master/pref.json"
)


def to_jis5(code: str) -> str:
    digits = "".join(ch for ch in str(code) if ch.isdigit())
    if len(digits) == 6:
        return digits[:5]
    if len(digits) == 5:
        return digits.zfill(6)[:5]
    return digits.zfill(5)


def detailed_map() -> dict[str, str]:
    mapping: dict[str, str] = {}
    for path in RES.glob("jp_*.json"):
        if path.name in {
            "jp_region_catalog.json",
            "jp_national_dictionary.json",
            "jp_CITY_TEMPLATE.json",
            "jp_standard_household.json",
            "japan_all_municipalities.json",
        }:
            continue
        try:
            data = json.loads(path.read_text())
        except Exception:
            continue
        if "cityId" not in data or "jisCode" not in data:
            continue
        if data["cityId"] == "jp_standard_household":
            continue
        jis = data["jisCode"]
        city_id = data["cityId"]
        prev = mapping.get(jis)
        if prev is None or (prev.endswith("_template") and not city_id.endswith("_template")):
            mapping[jis] = city_id
    return mapping


def is_detailed(city_id: str) -> bool:
    if not city_id or city_id.endswith("_template") or city_id.startswith("jp_custom_"):
        return False
    path = RES / f"{city_id}.json"
    if not path.exists():
        return False
    data = json.loads(path.read_text())
    return bool(data.get("districts"))


def main() -> None:
    req = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "GomiCalendar/1.0"})
    with urllib.request.urlopen(req, timeout=120) as response:
        pref = json.loads(response.read().decode("utf-8"))

    jis_to_city_id = detailed_map()
    prefectures = []
    counts: Counter[str] = Counter()

    for key, pdata in pref.items():
        if key == "0" or pdata.get("name") == "全国":
            continue
        pref_num = int(pdata.get("code") or key)
        if pref_num < 1 or pref_num > 47:
            continue
        pref_code = f"{pref_num:02d}"
        cities_out = []
        seen: set[str] = set()
        for city in (pdata.get("cities") or {}).values():
            jis = to_jis5(city["code"])
            if jis in seen:
                continue
            seen.add(jis)
            city_id = jis_to_city_id.get(jis) or f"jp_{jis}_template"
            cities_out.append(
                {
                    "jisCode": jis,
                    "cityId": city_id,
                    "nameJa": city["name"],
                    "kana": city.get("yomi") or city.get("yomi_kana") or "",
                    "hasDetailedRules": is_detailed(city_id),
                }
            )
        cities_out.sort(key=lambda c: (0 if c["hasDetailedRules"] else 1, c["jisCode"]))
        prefectures.append(
            {
                "code": pref_code,
                "nameJa": pdata["name"],
                "kana": pdata.get("yomi") or "",
                "cities": cities_out,
            }
        )
        counts[pref_code] = len(cities_out)

    prefectures.sort(key=lambda p: p["code"])
    total = sum(counts.values())
    assert len(prefectures) == 47, len(prefectures)
    assert total == 1741, total
    assert min(counts.values()) >= 10

    payload = {
        "schemaVersion": 1,
        "source": SOURCE_URL,
        "sourceNote": "Nationwide local government codes normalized to JIS X 0402",
        "generatedAt": "2026-11-20",
        "prefectureCount": 47,
        "municipalityCount": total,
        "prefectures": prefectures,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {OUT} ({total} municipalities, 47 prefectures)")


if __name__ == "__main__":
    main()
