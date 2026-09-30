# Realtor App: Private Listings API

A small private HTTP API for Canadian MLS® listings, backed by [Repliers](https://docs.repliers.io/reference/why-use-this-api). Your apps call this server with your own `API_KEY`, and the server calls Repliers with your `REPLIERS_API_KEY`, which never reaches clients.

## Setup

1. Create a free account at [repliers.com](https://repliers.com/) and copy your API key from the developer portal. A free key returns simulated sample listings; real MLS® data needs a paid plan and MLS® approval.
2. Install and configure:

```powershell
npm install
copy .env.example .env
# edit .env: set API_KEY (any long secret) and REPLIERS_API_KEY
npm run smoke   # quick check that the Repliers key works
npm start
```

## Authentication

Every `/api/v1/*` request needs your `API_KEY`:

- Header `X-API-Key: your-secret`, or
- Header `Authorization: Bearer your-secret`

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Liveness check (no auth) |
| GET | `/api/v1/search` | Search listings; query params go straight to Repliers |
| POST | `/api/v1/search` | Same, with JSON `{ "query": {...}, "body": {...} }` (body is for map polygons etc.) |
| GET | `/api/v1/listings/:mlsNumber` | Single listing (add `boardId` if your account has multiple boards) |
| GET | `/api/v1/listings/:mlsNumber/similar` | Similar active listings |
| GET | `/api/v1/locations/autocomplete?search=tor` | City/neighbourhood autocomplete |

Add `raw=true` to any listing endpoint to get the unmodified Repliers response.

### Examples

```powershell
$h = @{ "X-API-Key" = "your-secret" }

# Active Toronto listings for sale, $500k-$900k, 2+ bedrooms
Invoke-RestMethod "http://localhost:3000/api/v1/search?city=Toronto&type=sale&status=A&minPrice=500000&maxPrice=900000&minBedrooms=2&resultsPerPage=10" -Headers $h

# Within 5 km of a point
Invoke-RestMethod "http://localhost:3000/api/v1/search?lat=43.65&long=-79.38&radius=5&resultsPerPage=10" -Headers $h

# One listing
Invoke-RestMethod "http://localhost:3000/api/v1/listings/W10440893" -Headers $h
```

Common search params (full list in the [Repliers listings docs](https://docs.repliers.io/reference/getting-started-with-your-api)): `city`, `area`, `neighborhood`, `zip`, `type` (`sale`/`lease`), `status` (`A` active, `U` unavailable/sold), `class` (`residential`, `condo`, `commercial`), `propertyType`, `minPrice`, `maxPrice`, `minBedrooms`, `minBaths`, `minSqft`, `lat`/`long`/`radius`, `sortBy`, `pageNum`, `resultsPerPage`.

### Normalized listing shape

`mls_number`, `board_id`, `status`, `transaction_type`, `price`, `list_date`, `address_full`, `city`, `neighborhood`, `postal_code`, `province`, `lat`, `lon`, `property_type`, `style`, `beds`, `beds_plus`, `baths`, `sqft`, `description`, `photo_url`, `photo_urls`, `agent_name`, `agent_brokerage`.

## iOS app (HomeFinder)

`iOSApp/` is a SwiftUI app (iOS 15+) with a map of price pins that reloads as you pan and zoom, a list view, filters, location search, and listing details with directions.

- Every push to `iOSApp/**` builds an unsigned `.ipa` on GitHub Actions (`.github/workflows/app.yml`). Download it with `gh run download <run-id> -D ipa_build`.
- The repo secrets `APP_SERVER_URL` and `APP_API_KEY` become the app's default server settings; you can change both in the app's Settings screen.
- The phone reaches this server over your Wi-Fi at `http://<PC LAN IP>:3000`, so inbound TCP 3000 must be allowed in Windows Firewall.

## Environment

| Variable | Required | Description |
|----------|----------|-------------|
| `API_KEY` | yes | Secret your clients send to this API |
| `REPLIERS_API_KEY` | yes | Repliers key (test or production) |
| `PORT` | no | HTTP port, default `3000` |
