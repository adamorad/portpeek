# supermarket-tiktok/scrape.py
from pathlib import Path
from il_supermarket_scarper import ScarpingTask
from il_supermarket_scarper.utils.file_types import FileTypesFilters

RAW_DIR = Path(__file__).parent / "data" / "raw"

CHAINS = [
    "SHUFERSAL",
    "RAMI_LEVY",
    "YOHANANOF",
    "OSHER_AD",
    "HAZI_HINAM",
    "TIV_TAAM",
    "MAHSANI_ASHUK",
    "VICTORY_NEW_SOURCE",
    "YAYNO_BITAN_AND_CARREFOUR",
]

# file_types must be passed as string names (e.g. "PROMO_FULL_FILE"),
# not enum objects — the scrapers compare against FileTypesFilters.X.name
FILE_TYPES = [
    FileTypesFilters.PROMO_FULL_FILE.name,
    FileTypesFilters.PRICE_FULL_FILE.name,
]


def get_valid_chains():
    """Discover exact enum names at runtime in case they differ."""
    try:
        from il_supermarket_scarper.scrappers_factory import ScraperFactory
        available = set(ScraperFactory.all_scrapers_name())
        valid = [c for c in CHAINS if c in available]
        skipped = [c for c in CHAINS if c not in available]
        if skipped:
            print(f"Warning: chains not found, skipping: {skipped}")
        return valid
    except Exception as e:
        print(f"Warning: could not validate chain names ({e}), using hardcoded list")
        return CHAINS


def main():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    chains = get_valid_chains()
    print(f"Scraping {len(chains)} chains: {chains}")

    task = ScarpingTask(
        enabled_scrapers=chains,
        files_types=FILE_TYPES,
        output_configuration={
            "output_mode": "disk",
            "base_storage_path": str(RAW_DIR),
        },
        status_configuration={
            "database_type": "json",
            "base_path": str(RAW_DIR / "status"),
        },
    )
    task.start()
    task.join()
    print(f"Scraping complete. Files saved to {RAW_DIR}")


if __name__ == "__main__":
    main()
