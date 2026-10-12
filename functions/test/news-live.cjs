// Opt-in external smoke test. Reports actual metadata, never logs tokens or keys.
const { test } = require("node:test"),
  assert = require("node:assert/strict");
test("live scholarly sources through authenticated callable (no fixtures)", async () => {
  const login = await fetch(
    "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: "lecturer.a@example.test",
        password: process.env.DEMO_PASSWORD || "EmulatorOnly123!",
        returnSecureToken: true,
      }),
    },
  );
  const { idToken } = await login.json();
  assert.ok(idToken);
  for (const source of ["Crossref", "OpenAlex"]) {
    const response = await fetch(
      "http://127.0.0.1:5001/demo-fap-lab2/asia-southeast1/discoverArticles",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${idToken}`,
        },
        body: JSON.stringify({
          data: {
            subjectId: "PRM393",
            source,
            page: 1,
            sort: "relevance",
            query: "mobile development",
          },
        }),
      },
    );
    const result = await response.json();
    assert.ok(result.result, JSON.stringify(result.error));
    assert.ok(result.result.articles.length > 0);
    for (const a of result.result.articles) {
      assert.ok(a.title);
      assert.match(a.url, /^https:\/\//);
      assert.equal(a.source, source);
    }
    console.log(
      JSON.stringify({
        source,
        count: result.result.articles.length,
        cached: result.result.cached,
        sampleTitle: result.result.articles[0].title,
        sampleUrl: result.result.articles[0].url,
      }),
    );
  }
});
