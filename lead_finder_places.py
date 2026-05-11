#!/usr/bin/env python3
"""
Lead finder for wholesale electronics offers using Google Places API.

Usage:
  export GOOGLE_MAPS_API_KEY="your_key"
  python lead_finder_places.py --city "Москва" --country "RU"

Optional:
  python lead_finder_places.py --city "Москва" --country "RU" \
    --queries "магазин электроники,магазин смартфонов,салон связи" \
    --max-results 120 --out leads_moscow.csv --out-json leads_moscow.json
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from dataclasses import dataclass, asdict
from typing import Dict, Iterable, List, Optional
from urllib.parse import urlencode, urlparse
from urllib.request import urlopen

TEXT_SEARCH_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json"
DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json"

DEFAULT_QUERIES = [
    "магазин электроники",
    "магазин смартфонов",
    "салон связи",
    "магазин мобильных телефонов",
    "магазин цифровой техники",
]


@dataclass
class Lead:
    place_id: str
    name: str
    city: str
    country: str
    address: str = ""
    phone: str = ""
    website: str = ""
    domain: str = ""
    rating: Optional[float] = None
    user_ratings_total: Optional[int] = None
    types: str = ""
    query_source: str = ""
    maps_url: str = ""


def normalize_domain(url: str) -> str:
    if not url:
        return ""
    try:
        parsed = urlparse(url)
        host = parsed.netloc.lower().replace("www.", "")
        return host
    except Exception:
        return ""


def call_api(url: str, params: Dict[str, str], timeout: int = 25) -> Dict:
    full_url = f"{url}?{urlencode(params)}"
    with urlopen(full_url, timeout=timeout) as response:
        status_code = getattr(response, "status", 200)
        if status_code >= 400:
            raise RuntimeError(f"HTTP error {status_code}")
        payload = json.loads(response.read().decode("utf-8"))
    status = payload.get("status")
    if status not in {"OK", "ZERO_RESULTS"}:
        error_message = payload.get("error_message", "")
        raise RuntimeError(f"Google API status={status}. {error_message}".strip())
    return payload


def text_search(
    api_key: str,
    full_query: str,
    language: str,
    max_results: int,
    sleep_between_pages: float = 2.2,
) -> List[Dict]:
    collected: List[Dict] = []
    next_page_token: Optional[str] = None

    while len(collected) < max_results:
        params = {
            "key": api_key,
            "query": full_query,
            "language": language,
        }
        if next_page_token:
            params = {"key": api_key, "pagetoken": next_page_token}

        payload = call_api(TEXT_SEARCH_URL, params)
        results = payload.get("results", [])
        if not results:
            break

        collected.extend(results)
        next_page_token = payload.get("next_page_token")
        if not next_page_token:
            break

        # Google requires short delay before token becomes active.
        time.sleep(sleep_between_pages)

    return collected[:max_results]


def get_details(api_key: str, place_id: str, language: str) -> Dict:
    params = {
        "key": api_key,
        "place_id": place_id,
        "language": language,
        "fields": "place_id,name,formatted_phone_number,website,url",
    }
    payload = call_api(DETAILS_URL, params)
    return payload.get("result", {})


def build_lead(
    city: str,
    country: str,
    query_source: str,
    place_obj: Dict,
    details_obj: Dict,
) -> Lead:
    website = details_obj.get("website", "")
    maps_url = details_obj.get("url", "")
    domain = normalize_domain(website)
    return Lead(
        place_id=place_obj.get("place_id", ""),
        name=place_obj.get("name", ""),
        city=city,
        country=country,
        address=place_obj.get("formatted_address", ""),
        phone=details_obj.get("formatted_phone_number", ""),
        website=website,
        domain=domain,
        rating=place_obj.get("rating"),
        user_ratings_total=place_obj.get("user_ratings_total"),
        types=",".join(place_obj.get("types", [])),
        query_source=query_source,
        maps_url=maps_url,
    )


def dedupe(leads: Iterable[Lead]) -> List[Lead]:
    by_key: Dict[str, Lead] = {}
    for lead in leads:
        key = lead.place_id or lead.domain or f"{lead.name}|{lead.address}"
        if key not in by_key:
            by_key[key] = lead
        else:
            existing = by_key[key]
            if not existing.website and lead.website:
                by_key[key] = lead
    return list(by_key.values())


def write_csv(leads: List[Lead], path: str) -> None:
    fieldnames = list(asdict(leads[0]).keys()) if leads else list(asdict(Lead("", "", "", "")).keys())
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for lead in leads:
            writer.writerow(asdict(lead))


def write_json(leads: List[Lead], path: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump([asdict(item) for item in leads], f, ensure_ascii=False, indent=2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect stores from search results for wholesale electronics outreach."
    )
    parser.add_argument("--city", required=True, help='City name, e.g. "Москва"')
    parser.add_argument("--country", default="RU", help='Country code label, e.g. "RU"')
    parser.add_argument("--language", default="ru", help="Google Places response language")
    parser.add_argument(
        "--queries",
        default=",".join(DEFAULT_QUERIES),
        help="Comma-separated search intents (without city)",
    )
    parser.add_argument(
        "--max-results",
        type=int,
        default=80,
        help="Max results per query before dedupe",
    )
    parser.add_argument("--out", default="leads.csv", help="CSV output path")
    parser.add_argument("--out-json", default="", help="Optional JSON output path")
    parser.add_argument(
        "--api-key",
        default=os.getenv("GOOGLE_MAPS_API_KEY", ""),
        help="Google Maps Platform API key (or env GOOGLE_MAPS_API_KEY)",
    )
    parser.add_argument(
        "--skip-details",
        action="store_true",
        help="Skip details endpoint (faster, but no website/phone)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.api_key:
        print("Error: API key is required. Use --api-key or GOOGLE_MAPS_API_KEY.", file=sys.stderr)
        return 2

    query_list = [q.strip() for q in args.queries.split(",") if q.strip()]
    if not query_list:
        print("Error: at least one query is required.", file=sys.stderr)
        return 2

    leads_raw: List[Lead] = []

    for q in query_list:
        full_query = f"{q} {args.city}"
        print(f"[search] {full_query}")
        try:
            results = text_search(
                api_key=args.api_key,
                full_query=full_query,
                language=args.language,
                max_results=args.max_results,
            )
        except Exception as exc:
            print(f"[warn] Query failed '{q}': {exc}", file=sys.stderr)
            continue

        for place in results:
            place_id = place.get("place_id", "")
            details = {}
            if place_id and not args.skip_details:
                try:
                    details = get_details(args.api_key, place_id, args.language)
                except Exception as exc:
                    print(f"[warn] Details failed place_id={place_id}: {exc}", file=sys.stderr)
            lead = build_lead(
                city=args.city,
                country=args.country,
                query_source=q,
                place_obj=place,
                details_obj=details,
            )
            leads_raw.append(lead)

    leads = dedupe(leads_raw)
    leads.sort(
        key=lambda x: (
            x.domain == "",
            x.website == "",
            -(x.user_ratings_total or 0),
            x.name.lower(),
        )
    )

    write_csv(leads, args.out)
    print(f"[ok] Saved {len(leads)} leads to: {args.out}")

    if args.out_json:
        write_json(leads, args.out_json)
        print(f"[ok] Saved JSON to: {args.out_json}")

    if leads:
        print("[sample]")
        for item in leads[:5]:
            print(f" - {item.name} | {item.phone or '-'} | {item.website or '-'}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
