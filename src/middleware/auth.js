export function requireApiKey(req, res, next) {
  const expected = process.env.API_KEY;
  if (!expected) {
    return res.status(500).json({
      error: "Server misconfigured: API_KEY is not set.",
    });
  }

  const headerKey = req.get("x-api-key");
  const auth = req.get("authorization");
  const bearer =
    auth && auth.toLowerCase().startsWith("bearer ")
      ? auth.slice(7).trim()
      : null;

  const provided = headerKey || bearer;
  if (!provided || provided !== expected) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  next();
}
