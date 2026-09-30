import "dotenv/config";
import express from "express";
import { requireApiKey } from "./middleware/auth.js";
import {
  searchListings,
  getListing,
  getSimilarListings,
  autocompleteLocations,
} from "./repliers/client.js";

const app = express();
const port = Number(process.env.PORT) || 3000;

app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "realtor-app-api" });
});

app.use("/api/v1", requireApiKey);

const isTrue = (v) => v === "true" || v === "1" || v === true;

function splitRaw(query) {
  const { raw, ...rest } = query;
  return { ...rest, raw: isTrue(raw) };
}

app.get("/api/v1/search", async (req, res, next) => {
  try {
    res.json(await searchListings(splitRaw(req.query)));
  } catch (err) {
    next(err);
  }
});

app.post("/api/v1/search", async (req, res, next) => {
  try {
    const { query = {}, body, raw } = req.body ?? {};
    res.json(await searchListings({ ...query, body, raw: isTrue(raw) }));
  } catch (err) {
    next(err);
  }
});

app.get("/api/v1/listings/:mlsNumber", async (req, res, next) => {
  try {
    res.json(await getListing(req.params.mlsNumber, splitRaw(req.query)));
  } catch (err) {
    next(err);
  }
});

app.get("/api/v1/listings/:mlsNumber/similar", async (req, res, next) => {
  try {
    res.json(await getSimilarListings(req.params.mlsNumber, splitRaw(req.query)));
  } catch (err) {
    next(err);
  }
});

app.get("/api/v1/locations/autocomplete", async (req, res, next) => {
  try {
    res.json(await autocompleteLocations(req.query));
  } catch (err) {
    next(err);
  }
});

app.use((err, _req, res, _next) => {
  const status = err.status && err.status >= 400 && err.status < 600 ? err.status : 500;
  if (status >= 500) console.error(err);
  res.status(status).json({
    error: err.message ?? "Request failed",
    ...(err.details ? { details: err.details } : {}),
  });
});

app.listen(port, () => {
  console.log(`Realtor private API listening on http://localhost:${port}`);
});
