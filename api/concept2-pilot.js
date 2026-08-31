module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Método no permitido" });
  }

  const CLIENT_ID = "bx8m9j1Qj8GZnN3ni8Wz5QEb15SHB9amysaSgelu";
  const CLIENT_SECRET = process.env.CONCEPT2_CLIENT_SECRET;
  const SCOPE = "user:read,results:read";
  const ALLOWED_REDIRECT = "https://rowtraining.vercel.app/concept2-callback.html";

  if (!CLIENT_SECRET) {
    return res.status(500).json({ error: "Falta configurar CONCEPT2_CLIENT_SECRET en Vercel." });
  }

  const { code, redirect_uri } = req.body || {};
  if (!code) return res.status(400).json({ error: "Falta el código OAuth." });
  if (redirect_uri !== ALLOWED_REDIRECT) {
    return res.status(400).json({ error: "Callback no permitido." });
  }

  try {
    const body = new URLSearchParams({
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      grant_type: "authorization_code",
      redirect_uri: ALLOWED_REDIRECT,
      code,
      scope: SCOPE
    });

    const tokenRes = await fetch("https://log.concept2.com/oauth/access_token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json"
      },
      body
    });

    const tokenJson = await tokenRes.json().catch(() => ({}));
    if (!tokenRes.ok) {
      return res.status(tokenRes.status).json({
        error: tokenJson?.message || tokenJson?.error_description || tokenJson?.error || "Concept2 rechazó el intercambio OAuth."
      });
    }

    const accessToken = tokenJson.access_token || tokenJson?.data?.access_token;
    if (!accessToken) {
      return res.status(502).json({ error: "Concept2 no devolvió access_token." });
    }

    const headers = {
      "Authorization": `Bearer ${accessToken}`,
      "Accept": "application/vnd.c2logbook.v1+json"
    };

    const [userRes, resultsRes] = await Promise.all([
      fetch("https://log.concept2.com/api/users/me", { headers }),
      fetch("https://log.concept2.com/api/users/me/results?type=rower&number=10", { headers })
    ]);

    const userJson = await userRes.json().catch(() => ({}));
    const resultsJson = await resultsRes.json().catch(() => ({}));

    if (!userRes.ok) {
      return res.status(userRes.status).json({ error: userJson?.message || "No se pudo leer el perfil de Concept2." });
    }
    if (!resultsRes.ok) {
      return res.status(resultsRes.status).json({ error: resultsJson?.message || "No se pudieron leer los resultados de Concept2." });
    }

    const user = userJson?.data || userJson;
    const results = Array.isArray(resultsJson) ? resultsJson : (resultsJson?.data || []);

    // Security: never return access_token or refresh_token to the browser.
    return res.status(200).json({ ok: true, user, results });
  } catch (e) {
    console.error("Concept2 pilot error", e);
    return res.status(500).json({ error: "Error interno al conectar con Concept2." });
  }
};
