import { normalizeListing, normalizeSearchResponse } from "./normalize.js";

const API_BASE = process.env.REPLIERS_API_BASE || "https://api.repliers.io";

function apiKey() {
  const key = process.env.REPLIERS_API_KEY;
  if (!key) {
    throw new Error("Server misconfigured: REPLIERS_API_KEY is not set.");
  }
  return key;
}

export class RepliersError extends Error {
  constructor(message, status, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

async function repliersRequest(path, { method = "GET", query = {}, body } = {}) {
  const url = new URL(path, API_BASE);
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null || value === "") continue;
    for (const v of Array.isArray(value) ? value : [value]) {
      url.searchParams.append(key, String(v));
    }
  }

  const res = await fetch(url, {
    method,
    headers: {
      "REPLIERS-API-KEY": apiKey(),
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { message: text.slice(0, 200) };
  }

  if (!res.ok) {
    const message =
      (Array.isArray(data) && data.map((e) => e.msg).filter(Boolean).join("; ")) ||
      data?.message ||
      data?.error ||
      `Repliers request failed (HTTP ${res.status})`;
    const status = res.status === 401 || res.status === 403 ? 502 : res.status;
    throw new RepliersError(`Repliers: ${message}`, status, data);
  }
  return data;
}

/**
 * Query params are forwarded to POST /listings as-is, so every filter in
 * https://docs.repliers.io/reference/getting-started-with-your-api works
 * (city, minPrice, maxPrice, minBedrooms, type, class, lat/long/radius, ...).
 */
export async function searchListings({ raw = false, body, ...query } = {}) {
  const data = await repliersRequest("/listings", { method: "POST", query, body: body ?? {} });
  return raw ? data : normalizeSearchResponse(data);
}

export async function getListing(mlsNumber, { raw = false, ...query } = {}) {
  if (!mlsNumber) throw new RepliersError("mlsNumber is required.", 400);
  const data = await repliersRequest(`/listings/${encodeURIComponent(mlsNumber)}`, { query });
  return raw ? data : { ...normalizeListing(data), raw: data };
}

export async function getSimilarListings(mlsNumber, { raw = false, ...query } = {}) {
  if (!mlsNumber) throw new RepliersError("mlsNumber is required.", 400);
  const data = await repliersRequest(`/listings/${encodeURIComponent(mlsNumber)}/similar`, { query });
  return raw ? data : normalizeSearchResponse(data);
}

export async function autocompleteLocations(query) {
  return repliersRequest("/locations/autocomplete", { query });
}
