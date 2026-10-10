import asyncio
import math
import time
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Literal

import httpx
import structlog

from app.core.config import settings
from app.schemas.dashboard import (
    MetalHistoryResponse,
    MetalPricePoint,
    MetalPricesResponse,
    MetalQuote,
    MetalRetailBreakdown,
)

logger = structlog.get_logger()

_GOLD_BASE = Decimal("9032.00")
_SILVER_BASE = Decimal("95.00")
_TROY_OZ_GRAMS = Decimal("31.1034768")

_spot_cache: tuple[float, MetalPricesResponse] | None = None
_history_cache: dict[str, tuple[float, MetalHistoryResponse]] = {}
_live_source_cache: tuple[float, bool] | None = None
_goldapi_date_cache: dict[str, tuple[float, Decimal]] = {}
_GOLDAPI_DATE_CACHE_TTL_SECONDS = 86400

MetalRange = Literal["1M", "3M", "6M", "1Y", "3Y"]


def _quantize(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _metal_symbol(metal: str) -> str:
    return "XAU" if metal == "gold" else "XAG"


def _uses_new_gold_api() -> bool:
    """Dashboard hex keys use api.gold-api.com; legacy tokens use www.goldapi.io."""
    key = (settings.GOLDAPI_KEY or "").strip()
    return bool(key) and not key.startswith("goldapi-")


def _range_days(range_key: MetalRange) -> int:
    return {"1M": 30, "3M": 90, "6M": 180, "1Y": 365, "3Y": 1095}[range_key]


def _pct(value: float) -> Decimal:
    return Decimal(str(value))


def _to_customer_price(spot: Decimal, metal: str) -> Decimal:
    """India customer buy rate = live spot + GST + platform spread."""
    if metal == "gold":
        gst = _pct(settings.METAL_GOLD_GST_PERCENT)
        spread = _pct(settings.METAL_GOLD_BUY_SPREAD_PERCENT)
    else:
        gst = _pct(settings.METAL_SILVER_GST_PERCENT)
        spread = _pct(settings.METAL_SILVER_BUY_SPREAD_PERCENT)
    with_gst = spot * (Decimal("1") + gst / Decimal("100"))
    return _quantize(with_gst * (Decimal("1") + spread / Decimal("100")))


def _to_tn_bullion_rate(spot: Decimal, metal: str) -> Decimal:
    """Tamil Nadu bullion board rate (SLN CBE 9999 / Chennai silver T+1 parity)."""
    if metal == "gold":
        markup = _pct(settings.METAL_GOLD_TN_BULLION_MARKUP_PERCENT)
    else:
        markup = _pct(settings.METAL_SILVER_TN_BULLION_MARKUP_PERCENT)
    return _quantize(spot * (Decimal("1") + markup / Decimal("100")))


def _to_market_display_price(spot: Decimal, metal: str) -> Decimal:
    """Public live rate shown in the app (matches TN bullion boards like SLN)."""
    return _to_tn_bullion_rate(spot, metal)


def _apply_market_display_price(point: MetalPricePoint, metal: str) -> MetalPricePoint:
    return MetalPricePoint(
        label=point.label,
        price=_to_market_display_price(point.price, metal),
        date=point.date,
    )


def _to_tn_retail(spot: Decimal, metal: str) -> MetalRetailBreakdown:
    """Tamil Nadu market rate = international spot + import duty + GST + local premium."""
    if metal == "gold":
        duty_pct = _pct(settings.METAL_GOLD_IMPORT_DUTY_PERCENT)
        gst_pct = _pct(settings.METAL_GOLD_GST_PERCENT)
        purity = "24K"
    else:
        duty_pct = _pct(settings.METAL_SILVER_IMPORT_DUTY_PERCENT)
        gst_pct = _pct(settings.METAL_SILVER_GST_PERCENT)
        purity = "999"

    premium_pct = _pct(settings.METAL_TN_JEWELLER_PREMIUM_PERCENT)
    duty_amt = _quantize(spot * duty_pct / Decimal("100"))
    after_duty = spot + duty_amt
    gst_amt = _quantize(after_duty * gst_pct / Decimal("100"))
    after_gst = after_duty + gst_amt
    premium_amt = _quantize(after_gst * premium_pct / Decimal("100"))
    retail = _quantize(after_gst + premium_amt)

    return MetalRetailBreakdown(
        region="Tamil Nadu",
        purity=purity,
        international_spot=_quantize(spot),
        import_duty_percent=duty_pct,
        import_duty_amount=duty_amt,
        gst_percent=gst_pct,
        gst_amount=gst_amt,
        local_premium_percent=premium_pct,
        local_premium_amount=premium_amt,
        retail_price=retail,
    )


def _usd_per_troy_oz(rate: Decimal, usd_key: str | None, rates: dict) -> Decimal:
    if usd_key and usd_key in rates:
        return Decimal(str(rates[usd_key]))
    if rate <= 0:
        raise ValueError("Missing metal rate")
    if rate < Decimal("1"):
        return Decimal("1") / rate
    return rate


class MetalPriceService:
    """Live gold/silver via Gold Price API (api.gold-api.com) with commodity fallbacks."""

    async def get_prices(self) -> MetalPricesResponse:
        global _spot_cache
        now_mono = time.monotonic()
        if _spot_cache and (now_mono - _spot_cache[0]) < settings.METAL_PRICES_CACHE_TTL_SECONDS:
            return _spot_cache[1]

        now = datetime.now(timezone.utc)
        gold_price, silver_price, gold_change, silver_change, _ = (
            await self._fetch_live_spots()
        )
        gold_trend, silver_trend = await asyncio.gather(
            self._fetch_dashboard_trend("gold", gold_price),
            self._fetch_dashboard_trend("silver", silver_price),
        )

        payload = MetalPricesResponse(
            refreshed_at=now,
            gold=self._build_quote(
                "gold", gold_price, gold_change, gold_trend
            ),
            silver=self._build_quote(
                "silver", silver_price, silver_change, silver_trend
            ),
        )
        _spot_cache = (now_mono, payload)
        return payload

    async def get_history(self, metal: str, range_key: MetalRange) -> MetalHistoryResponse:
        cache_key = f"{metal}:{range_key}"
        now_mono = time.monotonic()
        cached = _history_cache.get(cache_key)
        if cached and (now_mono - cached[0]) < settings.METAL_HISTORY_CACHE_TTL_SECONDS:
            return cached[1]

        gold_spot, silver_spot, _, _, _ = await self._fetch_live_spots()
        anchor = gold_spot if metal == "gold" else silver_spot

        days = _range_days(range_key)
        end = date.today()
        start = end - timedelta(days=days)
        points, used_goldapi = await self._fetch_history_points(
            metal, start, end, range_key, anchor
        )

        if len(points) >= 2:
            first = points[0].price
            last = points[-1].price
            perf = _quantize(
                ((last - first) / first) * Decimal("100") if first > 0 else Decimal("0")
            )
        else:
            perf = Decimal("0")

        purity = "24K" if metal == "gold" else "999"
        basis = (
            "gold_api_inr_24k"
            if used_goldapi and _uses_new_gold_api()
            else ("goldapi_inr_24k" if used_goldapi else "india_buy_rate")
        )
        unit = (
            "INR/gm · 9999 CBE T+1"
            if metal == "gold"
            else "INR/gm · Chennai silver T+1"
        )
        payload = MetalHistoryResponse(
            metal=metal,
            range_key=range_key,
            unit=unit,
            price_basis=basis,
            performance_percent=perf,
            points=points,
            refreshed_at=datetime.now(timezone.utc),
        )
        _history_cache[cache_key] = (now_mono, payload)
        return payload

    async def _resolve_silver_spot(self, goldapi_silver: Decimal) -> Decimal:
        """Prefer the higher MCX-aligned commodity quote when it exceeds GoldAPI."""
        if not settings.COMMODITY_PRICE_API_KEY:
            return goldapi_silver
        try:
            _, commodity_silver, _, _ = await self._commodity_live()
            if commodity_silver > goldapi_silver:
                return commodity_silver
        except Exception as exc:
            logger.warning("silver_spot_commodity_blend_failed", error=str(exc))
        return goldapi_silver

    async def _fetch_live_spots(
        self,
    ) -> tuple[Decimal, Decimal, Decimal, Decimal, bool]:
        """Returns (gold_inr_gm, silver_inr_gm, gold_chg%, silver_chg%, from_goldapi)."""
        global _live_source_cache
        now_mono = time.monotonic()
        if _live_source_cache and (
            now_mono - _live_source_cache[0]
        ) < settings.METAL_PRICES_CACHE_TTL_SECONDS:
            cached = _spot_cache
            if cached:
                p = cached[1]
                return (
                    p.gold.spot_price,
                    p.silver.spot_price,
                    p.gold.change_percent,
                    p.silver.change_percent,
                    _live_source_cache[1],
                )

        if settings.GOLDAPI_KEY and _uses_new_gold_api():
            try:
                result = await self._gold_api_live()
                _live_source_cache = (now_mono, True)
                return (*result, True)
            except Exception as exc:
                logger.warning("gold_api_live_fetch_failed", error=str(exc))

        if settings.GOLDAPI_KEY and not _uses_new_gold_api():
            gold_result, silver_result = await asyncio.gather(
                self._goldapi_spot("XAU"),
                self._goldapi_spot("XAG"),
                return_exceptions=True,
            )
            gold_ok = not isinstance(gold_result, BaseException)
            silver_ok = not isinstance(silver_result, BaseException)
            if not gold_ok:
                logger.warning("goldapi_gold_fetch_failed", error=str(gold_result))
            if not silver_ok:
                logger.warning("goldapi_silver_fetch_failed", error=str(silver_result))
            gold_price = gold_result[0] if gold_ok else None
            gold_change = gold_result[1] if gold_ok else Decimal("0")
            silver_price = silver_result[0] if silver_ok else None
            silver_change = silver_result[1] if silver_ok else Decimal("0")

            if gold_price is not None and silver_price is not None:
                silver_price = await self._resolve_silver_spot(silver_price)
                _live_source_cache = (now_mono, True)
                return (
                    gold_price,
                    silver_price,
                    gold_change,
                    silver_change,
                    True,
                )

            if gold_price is not None or silver_price is not None:
                if gold_price is None or silver_price is None:
                    try:
                        if settings.COMMODITY_PRICE_API_KEY:
                            cg, cs, ccg, ccs = await self._commodity_live()
                            if gold_price is None:
                                gold_price, gold_change = cg, ccg
                            if silver_price is None:
                                silver_price, silver_change = cs, ccs
                    except Exception as exc:
                        logger.warning(
                            "commodity_fill_after_partial_goldapi_failed",
                            error=str(exc),
                        )
                now = datetime.now(timezone.utc)
                if gold_price is None:
                    gold_price = _spot_at(_GOLD_BASE, "gold", now)
                if silver_price is None:
                    silver_price = _spot_at(_SILVER_BASE, "silver", now)
                else:
                    silver_price = await self._resolve_silver_spot(silver_price)
                _live_source_cache = (now_mono, True)
                return (
                    gold_price,
                    silver_price,
                    gold_change,
                    silver_change,
                    True,
                )

        if settings.API_NINJAS_KEY:
            try:
                result = await self._apininjas_live()
                _live_source_cache = (now_mono, False)
                return (*result, False)
            except Exception as exc:
                logger.warning("apininjas_live_fetch_failed", error=str(exc))

        if settings.COMMODITY_PRICE_API_KEY:
            try:
                result = await self._commodity_live()
                _live_source_cache = (now_mono, False)
                return (*result, False)
            except Exception as exc:
                logger.warning("commodity_priceapi_live_failed", error=str(exc))

        if settings.METALPRICEAPI_KEY:
            try:
                result = await self._metalpriceapi_live()
                _live_source_cache = (now_mono, False)
                return (*result, False)
            except Exception as exc:
                logger.warning("metalpriceapi_live_fetch_failed", error=str(exc))

        logger.error("metal_prices_no_provider", message="All live price providers failed")
        now = datetime.now(timezone.utc)
        gold = _spot_at(_GOLD_BASE, "gold", now)
        silver = _spot_at(_SILVER_BASE, "silver", now)
        _live_source_cache = (now_mono, False)
        return gold, silver, Decimal("0"), Decimal("0"), False

    async def _apininjas_get(self, name: str) -> dict:
        """Fetch one commodity from API Ninjas in INR per gram."""
        base = settings.API_NINJAS_BASE_URL.rstrip("/")
        headers = {"X-Api-Key": settings.API_NINJAS_KEY}
        params = {"name": name, "currency": "INR", "unit": "g"}
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(
                f"{base}/commodityprice",
                params=params,
                headers=headers,
            )
            response.raise_for_status()
            data = response.json()
        if not isinstance(data, dict) or data.get("price") is None:
            raise ValueError(f"API Ninjas returned no price for {name}")
        return data

    async def _apininjas_live(self) -> tuple[Decimal, Decimal, Decimal, Decimal]:
        gold_data, silver_data = await asyncio.gather(
            self._apininjas_get("gold"),
            self._apininjas_get("silver"),
        )
        gold_price = _quantize(Decimal(str(gold_data["price"])))
        silver_price = _quantize(Decimal(str(silver_data["price"])))
        gold_change = _quantize(Decimal(str(gold_data.get("change_24h_percent", 0))))
        silver_change = _quantize(
            Decimal(str(silver_data.get("change_24h_percent", 0)))
        )
        return gold_price, silver_price, gold_change, silver_change

    def _commodity_url(self, path: str) -> str:
        base = settings.COMMODITY_PRICE_API_BASE_URL.rstrip("/")
        return f"{base}/{path.lstrip('/')}"

    async def _commodity_get(self, path: str, params: dict) -> dict:
        headers = {"x-api-key": settings.COMMODITY_PRICE_API_KEY}
        query = {**params, "apiKey": settings.COMMODITY_PRICE_API_KEY}
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                self._commodity_url(path), params=query, headers=headers
            )
            response.raise_for_status()
            data = response.json()
        if not data.get("success", True):
            raise ValueError(str(data.get("error", "CommodityPriceAPI error")))
        return data

    async def _fetch_usd_inr(self) -> Decimal:
        """Live USD/INR for commodity fallback conversion."""
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.get("https://open.er-api.com/v6/latest/USD")
                response.raise_for_status()
                rate = response.json().get("rates", {}).get("INR")
                if rate:
                    return _quantize(Decimal(str(rate)))
        except Exception as exc:
            logger.warning("usd_inr_fetch_failed", error=str(exc))
        return Decimal("86.50")

    def _usd_oz_to_inr_gram(self, usd_oz: Decimal, inr_per_usd: Decimal) -> Decimal:
        return _quantize((usd_oz / _TROY_OZ_GRAMS) * inr_per_usd)

    async def _commodity_change(self, symbol: str) -> Decimal:
        end = date.today()
        start = end - timedelta(days=1)
        data = await self._commodity_get(
            "rates/fluctuation",
            {
                "symbols": symbol,
                "startDate": start.isoformat(),
                "endDate": end.isoformat(),
            },
        )
        entry = data.get("rates", {}).get(symbol, {})
        return _quantize(Decimal(str(entry.get("changePercent", 0))))

    async def _commodity_live(self) -> tuple[Decimal, Decimal, Decimal, Decimal]:
        data = await self._commodity_get("rates/latest", {"symbols": "XAU,XAG"})
        rates = data.get("rates", {})
        gold_usd = Decimal(str(rates["XAU"]))
        silver_usd = Decimal(str(rates["XAG"]))
        inr_per_usd = await self._fetch_usd_inr()
        gold_gram = self._usd_oz_to_inr_gram(gold_usd, inr_per_usd)
        silver_gram = self._usd_oz_to_inr_gram(silver_usd, inr_per_usd)

        gold_chg, silver_chg = await asyncio.gather(
            self._commodity_change("XAU"),
            self._commodity_change("XAG"),
            return_exceptions=True,
        )
        gold_change = (
            gold_chg if not isinstance(gold_chg, BaseException) else Decimal("0")
        )
        silver_change = (
            silver_chg if not isinstance(silver_chg, BaseException) else Decimal("0")
        )
        return gold_gram, silver_gram, gold_change, silver_change

    def _gold_api_url(self, path: str) -> str:
        base = settings.GOLD_API_BASE_URL.rstrip("/")
        return f"{base}/{path.lstrip('/')}"

    async def _gold_api_get(
        self, path: str, params: dict | None = None, *, history: bool = False
    ):
        headers = {"Accept": "application/json"}
        if settings.GOLDAPI_KEY:
            if history:
                headers["x-api-key"] = settings.GOLDAPI_KEY
            else:
                headers["x-access-token"] = settings.GOLDAPI_KEY
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                self._gold_api_url(path),
                params=params or {},
                headers=headers,
            )
            if response.status_code >= 400:
                raise ValueError(response.text[:300])
            return response.json()

    async def _gold_api_spot_inr(self, symbol: str) -> tuple[Decimal, Decimal]:
        data = await self._gold_api_get(f"price/{symbol}/INR")
        oz_inr = Decimal(str(data["price"]))
        gram = _quantize(oz_inr / _TROY_OZ_GRAMS)
        exchange = Decimal(str(data.get("exchangeRate", 0)))
        return gram, exchange

    async def _gold_api_change_from_history(
        self, symbol: str, inr_per_usd: Decimal
    ) -> Decimal:
        end_ts = int(time.time())
        start_ts = end_ts - (3 * 86400)
        try:
            rows = await self._gold_api_get(
                "history",
                {
                    "symbol": symbol,
                    "groupBy": "day",
                    "startTimestamp": start_ts,
                    "endTimestamp": end_ts,
                    "orderBy": "asc",
                },
                history=True,
            )
        except Exception:
            return Decimal("0")
        if not isinstance(rows, list) or len(rows) < 2:
            return Decimal("0")
        parsed_rows: list[tuple[date, Decimal]] = []
        for row in rows:
            day = self._parse_gold_api_history_day(row, "day")
            if day is None:
                continue
            usd_oz = Decimal(str(row.get("max_price") or row.get("price") or 0))
            if usd_oz <= 0:
                continue
            parsed_rows.append((day, usd_oz))
        parsed_rows.sort(key=lambda item: item[0])
        if len(parsed_rows) < 2:
            return Decimal("0")
        parsed: list[Decimal] = []
        for _, usd_oz in parsed_rows[-2:]:
            parsed.append(self._usd_oz_to_inr_gram(usd_oz, inr_per_usd))
        if len(parsed) < 2 or parsed[0] <= 0:
            return Decimal("0")
        return _quantize(((parsed[-1] - parsed[0]) / parsed[0]) * Decimal("100"))

    async def _gold_api_live(self) -> tuple[Decimal, Decimal, Decimal, Decimal]:
        gold_result, silver_result = await asyncio.gather(
            self._gold_api_spot_inr("XAU"),
            self._gold_api_spot_inr("XAG"),
            return_exceptions=True,
        )
        if isinstance(gold_result, BaseException):
            raise gold_result
        if isinstance(silver_result, BaseException):
            raise silver_result
        gold_price, gold_exchange = gold_result
        silver_price, silver_exchange = silver_result
        gold_change, silver_change = await asyncio.gather(
            self._gold_api_change_from_history("XAU", gold_exchange),
            self._gold_api_change_from_history("XAG", silver_exchange),
        )
        if isinstance(gold_change, BaseException):
            gold_change = Decimal("0")
        if isinstance(silver_change, BaseException):
            silver_change = Decimal("0")
        return gold_price, silver_price, gold_change, silver_change

    def _gold_api_history_group(self, range_key: MetalRange) -> str:
        return "week" if range_key == "3Y" else "day"

    def _parse_gold_api_history_day(self, row: dict, group_by: str) -> date | None:
        if group_by == "week":
            raw = str(row.get("week", ""))[:10]
        elif group_by == "month":
            raw = str(row.get("year_month", ""))[:10]
            if len(raw) == 7:
                raw = f"{raw}-01"
        else:
            raw = str(row.get("day", ""))[:10]
        if not raw:
            return None
        try:
            return date.fromisoformat(raw)
        except ValueError:
            return None

    async def _gold_api_history(
        self, symbol: str, start: date, end: date, range_key: MetalRange
    ) -> list[MetalPricePoint]:
        end_ts = int(
            datetime.combine(end, datetime.max.time(), tzinfo=timezone.utc).timestamp()
        )
        start_ts = int(
            datetime.combine(start, datetime.min.time(), tzinfo=timezone.utc).timestamp()
        )
        group_by = self._gold_api_history_group(range_key)
        rows = await self._gold_api_get(
            "history",
            {
                "symbol": symbol,
                "groupBy": group_by,
                "startTimestamp": start_ts,
                "endTimestamp": end_ts,
                "orderBy": "asc",
            },
            history=True,
        )
        if not isinstance(rows, list) or len(rows) < 2:
            raise ValueError("Gold API returned insufficient history points")

        spot_data = await self._gold_api_get(f"price/{symbol}/INR")
        inr_per_usd = Decimal(str(spot_data.get("exchangeRate", 0)))
        live_inr_oz = Decimal(str(spot_data.get("price", 0)))
        live_inr_gram = _quantize(live_inr_oz / _TROY_OZ_GRAMS)
        if inr_per_usd <= 0:
            inr_per_usd = await self._fetch_usd_inr()
        live_usd_oz = (
            live_inr_oz / inr_per_usd if inr_per_usd > 0 and live_inr_oz > 0 else Decimal("0")
        )

        parsed: list[tuple[date, Decimal]] = []
        for row in rows:
            day = self._parse_gold_api_history_day(row, group_by)
            if day is None:
                continue
            usd_oz = Decimal(str(row.get("max_price") or row.get("price") or 0))
            if usd_oz <= 0:
                continue
            if live_usd_oz > 0 and live_inr_gram > 0:
                gram = _quantize((usd_oz / live_usd_oz) * live_inr_gram)
            else:
                gram = self._usd_oz_to_inr_gram(usd_oz, inr_per_usd)
            parsed.append((day, gram))

        parsed.sort(key=lambda item: item[0])

        points = self._downsample(parsed, range_key)
        if not points:
            raise ValueError("Gold API history produced no chart points")
        return points

    async def _goldapi_spot(self, symbol: str) -> tuple[Decimal, Decimal]:
        """India market price per gram from GoldAPI (price_gram_24k for gold)."""
        url = f"https://www.goldapi.io/api/{symbol}/INR"
        headers = {"x-access-token": settings.GOLDAPI_KEY}
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(url, headers=headers)
            if response.status_code == 403:
                logger.warning(
                    "goldapi_forbidden",
                    symbol=symbol,
                    detail=response.text[:200],
                )
            response.raise_for_status()
            data = response.json()

        gram_key = "price_gram_24k" if symbol == "XAU" else "price_gram"
        if gram_key in data and data[gram_key]:
            price = _quantize(Decimal(str(data[gram_key])))
        elif symbol == "XAG" and data.get("price_gram_24k"):
            price = _quantize(Decimal(str(data["price_gram_24k"])))
        else:
            price = _quantize(Decimal(str(data["price"])) / _TROY_OZ_GRAMS)

        change = _quantize(Decimal(str(data.get("chp", 0))))
        return price, change

    def _metalpriceapi_url(self, path: str) -> str:
        base = settings.METALPRICEAPI_BASE_URL.rstrip("/")
        return f"{base}/v1/{path.lstrip('/')}"

    async def _metalpriceapi_get(self, path: str, params: dict) -> dict:
        headers = {"X-API-KEY": settings.METALPRICEAPI_KEY}
        query = {**params, "api_key": settings.METALPRICEAPI_KEY}
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(
                self._metalpriceapi_url(path), params=query, headers=headers
            )
            response.raise_for_status()
            return response.json()

    async def _metalpriceapi_live(self) -> tuple[Decimal, Decimal, Decimal, Decimal]:
        data = await self._metalpriceapi_get(
            "latest",
            {"base": "USD", "currencies": "XAU,XAG,INR"},
        )

        if not data.get("success", True):
            raise ValueError(data.get("error", {}).get("message", "MetalpriceAPI error"))

        rates = data.get("rates", {})
        inr_per_usd = Decimal(str(rates.get("INR", 0)))
        gold_usd_oz = _usd_per_troy_oz(
            Decimal(str(rates.get("XAU", 0))), "USDXAU", rates
        )
        silver_usd_oz = _usd_per_troy_oz(
            Decimal(str(rates.get("XAG", 0))), "USDXAG", rates
        )
        gold = (
            _quantize((gold_usd_oz / _TROY_OZ_GRAMS) * inr_per_usd)
            if inr_per_usd
            else _GOLD_BASE
        )
        silver = (
            _quantize((silver_usd_oz / _TROY_OZ_GRAMS) * inr_per_usd)
            if inr_per_usd
            else _SILVER_BASE
        )
        return gold, silver, Decimal("0"), Decimal("0")

    async def _goldapi_price_on_date(self, symbol: str, day: date) -> Decimal | None:
        cache_key = f"{symbol}:{day.isoformat()}"
        now_mono = time.monotonic()
        cached = _goldapi_date_cache.get(cache_key)
        if cached and (now_mono - cached[0]) < _GOLDAPI_DATE_CACHE_TTL_SECONDS:
            return cached[1]

        gram_key = "price_gram_24k" if symbol == "XAU" else "price_gram"
        headers = {"x-access-token": settings.GOLDAPI_KEY}
        for offset in range(4):
            query_day = day - timedelta(days=offset)
            url = (
                f"https://www.goldapi.io/api/{symbol}/INR/"
                f"{query_day.strftime('%Y%m%d')}"
            )
            try:
                async with httpx.AsyncClient(timeout=20.0) as client:
                    response = await client.get(url, headers=headers)
                    if response.status_code in {401, 403, 429}:
                        logger.warning(
                            "goldapi_history_denied",
                            symbol=symbol,
                            day=query_day.isoformat(),
                            status=response.status_code,
                            detail=response.text[:200],
                        )
                        return None
                    if response.status_code != 200:
                        continue
                    data = response.json()
                if gram_key in data and data[gram_key]:
                    price = _quantize(Decimal(str(data[gram_key])))
                elif symbol == "XAG" and data.get("price_gram_24k"):
                    price = _quantize(Decimal(str(data["price_gram_24k"])))
                elif data.get("price"):
                    price = _quantize(Decimal(str(data["price"])) / _TROY_OZ_GRAMS)
                else:
                    continue
                _goldapi_date_cache[cache_key] = (now_mono, price)
                return price
            except Exception as exc:
                logger.warning(
                    "goldapi_history_date_failed",
                    symbol=symbol,
                    day=query_day.isoformat(),
                    error=str(exc),
                )
                continue
        return None

    def _history_sample_dates(
        self, start: date, end: date, range_key: MetalRange
    ) -> list[date]:
        target = {"1M": 22, "3M": 28, "6M": 32, "1Y": 36, "3Y": 40}[range_key]
        days = max(1, (end - start).days)
        step = max(1, days // target)
        dates: list[date] = []
        cursor = start
        while cursor <= end:
            dates.append(cursor)
            cursor += timedelta(days=step)
        if not dates or dates[-1] != end:
            dates.append(end)
        return dates

    async def _goldapi_history(
        self, symbol: str, start: date, end: date, range_key: MetalRange
    ) -> list[MetalPricePoint]:
        dates = self._history_sample_dates(start, end, range_key)
        semaphore = asyncio.Semaphore(3)

        async def fetch(day: date) -> tuple[date, Decimal | None]:
            async with semaphore:
                price = await self._goldapi_price_on_date(symbol, day)
                return day, price

        results = await asyncio.gather(*(fetch(d) for d in dates))
        parsed: list[tuple[date, Decimal]] = [
            (day, price) for day, price in results if price is not None and price > 0
        ]
        if len(parsed) < 2:
            raise ValueError("GoldAPI returned insufficient history points")

        points: list[MetalPricePoint] = []
        for day, price in parsed:
            label = (
                day.strftime("%d %b")
                if range_key in ("1M", "3M")
                else day.strftime("%b '%y")
            )
            points.append(MetalPricePoint(label=label, price=price, date=day.isoformat()))
        return points

    async def _fetch_history_points(
        self,
        metal: str,
        start: date,
        end: date,
        range_key: MetalRange,
        anchor: Decimal,
    ) -> tuple[list[MetalPricePoint], bool]:
        symbol = _metal_symbol(metal)
        points: list[MetalPricePoint] = []
        used_goldapi = False
        source = "simulated"

        if settings.GOLDAPI_KEY and _uses_new_gold_api() and not points:
            try:
                points = await self._gold_api_history(symbol, start, end, range_key)
                source = "gold_api"
                used_goldapi = len(points) >= 2
            except Exception as exc:
                logger.warning("gold_api_history_failed", error=str(exc))

        if settings.GOLDAPI_KEY and not _uses_new_gold_api() and not points:
            try:
                points = await self._goldapi_history(symbol, start, end, range_key)
                source = "goldapi"
                used_goldapi = len(points) >= 2
            except Exception as exc:
                logger.warning("goldapi_history_failed", error=str(exc))

        if settings.COMMODITY_PRICE_API_KEY and not points:
            try:
                points = await self._commodity_history(symbol, start, end, range_key)
                source = "commodity"
            except Exception as exc:
                logger.warning("commodity_priceapi_history_failed", error=str(exc))

        if settings.METALPRICEAPI_KEY and not points:
            try:
                points = await self._metalpriceapi_history(symbol, start, end, range_key)
                source = "metalpriceapi"
            except Exception as exc:
                logger.warning("metalpriceapi_history_failed", error=str(exc))

        if settings.GOLDAPI_KEY and points and source != "goldapi":
            # Dense daily history aligned to today's GoldAPI INR spot.
            points = self._calibrate_spot_series(points, anchor)
            used_goldapi = True

        if not points:
            logger.warning(
                "metal_history_using_simulated",
                metal=metal,
                range_key=range_key,
                goldapi_configured=bool(settings.GOLDAPI_KEY),
            )
            points = self._simulated_history(
                metal, _range_days(range_key), range_key, anchor
            )
        elif source in ("goldapi", "gold_api"):
            used_goldapi = True

        display_points = [_apply_market_display_price(p, metal) for p in points]
        live_display = _to_market_display_price(anchor, metal)
        if display_points:
            display_points[-1] = MetalPricePoint(
                label=display_points[-1].label,
                price=live_display,
                date=display_points[-1].date,
            )
        return display_points, used_goldapi

    async def _commodity_history(
        self, symbol: str, start: date, end: date, range_key: MetalRange
    ) -> list[MetalPricePoint]:
        data = await self._commodity_get(
            "rates/time-series",
            {
                "symbols": symbol,
                "startDate": start.isoformat(),
                "endDate": end.isoformat(),
            },
        )
        inr_per_usd = await self._fetch_usd_inr()

        parsed: list[tuple[date, Decimal]] = []
        for day_str, day_rates in sorted(data.get("rates", {}).items()):
            sym_data = day_rates.get(symbol, {})
            if isinstance(sym_data, dict):
                close = sym_data.get("close") or sym_data.get("open")
            else:
                close = sym_data
            if close is None:
                continue
            gram = self._usd_oz_to_inr_gram(Decimal(str(close)), inr_per_usd)
            parsed.append((date.fromisoformat(day_str), gram))

        points = self._downsample(parsed, range_key)
        if not points:
            raise ValueError("CommodityPriceAPI returned no history points")
        return points

    async def _metalpriceapi_history(
        self, symbol: str, start: date, end: date, range_key: MetalRange
    ) -> list[MetalPricePoint]:
        data = await self._metalpriceapi_get(
            "timeframe",
            {
                "start_date": start.isoformat(),
                "end_date": end.isoformat(),
                "base": "USD",
                "currencies": f"{symbol},INR",
            },
        )

        if not data.get("success", True):
            raise ValueError(data.get("error", {}).get("message", "MetalpriceAPI error"))

        rates_by_date = data.get("rates", {})
        parsed: list[tuple[date, Decimal]] = []
        for day_str, day_rates in sorted(rates_by_date.items()):
            usd_oz = _usd_per_troy_oz(
                Decimal(str(day_rates.get(symbol, 0))),
                f"USD{symbol}",
                day_rates,
            )
            inr_per_usd = Decimal(str(day_rates.get("INR", 0)))
            if usd_oz <= 0 or inr_per_usd <= 0:
                continue
            gram = _quantize((usd_oz / _TROY_OZ_GRAMS) * inr_per_usd)
            parsed.append((date.fromisoformat(day_str), gram))

        points = self._downsample(parsed, range_key)
        if not points:
            raise ValueError("MetalpriceAPI returned no history points")
        return points

    def _downsample(
        self, parsed: list[tuple[date, Decimal]], range_key: MetalRange
    ) -> list[MetalPricePoint]:
        if not parsed:
            return []

        # Keep enough points for a smooth Aura-style chart (daily for 1M).
        target = {"1M": 31, "3M": 42, "6M": 48, "1Y": 52, "3Y": 60}[range_key]
        step = 1 if range_key == "1M" else max(1, len(parsed) // target)
        points: list[MetalPricePoint] = []
        for i in range(0, len(parsed), step):
            day, price = parsed[i]
            label = day.strftime("%d %b") if range_key in ("1M", "3M") else day.strftime("%b '%y")
            points.append(MetalPricePoint(label=label, price=price, date=day.isoformat()))
        last_day, last_price = parsed[-1]
        last_label = (
            last_day.strftime("%d %b")
            if range_key in ("1M", "3M")
            else last_day.strftime("%b '%y")
        )
        if not points or points[-1].label != last_label:
            points.append(
                MetalPricePoint(
                    label=last_label,
                    price=last_price,
                    date=last_day.isoformat(),
                )
            )
        return points

    @staticmethod
    def _calibrate_spot_series(
        points: list[MetalPricePoint], anchor_spot: Decimal
    ) -> list[MetalPricePoint]:
        """Align historical spot levels with the live GoldAPI INR rate."""
        if len(points) < 2 or anchor_spot <= 0:
            return points
        last = points[-1].price
        if last <= 0:
            return points
        factor = anchor_spot / last
        if abs(factor - Decimal("1")) < Decimal("0.0001"):
            return points
        return [
            MetalPricePoint(
                label=p.label,
                price=_quantize(p.price * factor),
                date=p.date,
            )
            for p in points
        ]

    def _simulated_history(
        self, metal: str, days: int, range_key: MetalRange, anchor: Decimal
    ) -> list[MetalPricePoint]:
        now = datetime.now(timezone.utc)
        step = max(1, days // {"1M": 15, "3M": 20, "6M": 24, "1Y": 30, "3Y": 36}[range_key])
        amplitude = {
            "1M": Decimal("0.03"),
            "3M": Decimal("0.05"),
            "6M": Decimal("0.07"),
            "1Y": Decimal("0.10"),
            "3Y": Decimal("0.15"),
        }[range_key]
        points: list[MetalPricePoint] = []
        for offset in range(days, -1, -step):
            progress = Decimal(str((days - offset) / max(days, 1)))
            wave = Decimal(
                str(math.sin(float(progress) * 9.5 + (1.7 if metal == "gold" else 4.3)))
            )
            drift = Decimal("1") + wave * amplitude
            price = _quantize(anchor * drift)
            moment = now - timedelta(days=offset)
            label = (
                moment.strftime("%d %b")
                if range_key in ("1M", "3M")
                else moment.strftime("%b '%y")
            )
            points.append(
                MetalPricePoint(
                    label=label,
                    price=price,
                    date=moment.date().isoformat(),
                )
            )
        return points

    async def _fetch_dashboard_trend(
        self, metal: str, anchor: Decimal
    ) -> list[MetalPricePoint]:
        end = date.today()
        start = end - timedelta(days=30)
        try:
            spot_points, _ = await self._fetch_history_points(
                metal, start, end, "1M", anchor
            )
            if spot_points:
                return spot_points[-12:]
        except Exception as exc:
            logger.warning("dashboard_trend_fetch_failed", metal=metal, error=str(exc))

        buy = _to_market_display_price(anchor, metal)
        return [
            MetalPricePoint(
                label=end.strftime("%d %b"),
                price=buy,
                date=end.isoformat(),
            )
        ]

    def _build_quote(
        self,
        metal: str,
        market_price: Decimal,
        change_percent: Decimal,
        trend: list[MetalPricePoint],
    ) -> MetalQuote:
        retail_price = _to_market_display_price(market_price, metal)
        spot_price = _quantize(market_price)
        unit = (
            "INR/gm · 9999 CBE T+1"
            if metal == "gold"
            else "INR/gm · Chennai silver T+1"
        )
        return MetalQuote(
            metal=metal,
            unit=unit,
            spot_price=spot_price,
            change_percent=_quantize(change_percent),
            retail_price=retail_price,
            retail=_to_tn_retail(market_price, metal),
            trend=list(trend),
        )


def _spot_at(base: Decimal, metal: str, moment: datetime) -> Decimal:
    hours = moment.timestamp() / 3600.0
    seed = 1.7 if metal == "gold" else 4.3
    wave = math.sin(hours * 0.18 + seed) * 0.012
    drift = math.cos(hours * 0.06 + seed) * 0.006
    factor = Decimal(str(1.0 + wave + drift))
    return _quantize(base * factor)
