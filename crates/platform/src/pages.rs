pub const LANDING_PAGE: &str = include_str!("../site/landing.html");
pub const LANDING_CSS: &str = include_str!("../site/landing.css");
pub const LANDING_JS: &str = include_str!("../site/landing.js");

pub const ACCOUNT_PAGE: &str = r#"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Account · Giga Couch</title>
  <link rel="stylesheet" href="/site.css">
</head>
<body>
  <aside class="rail">
    <a href="/"><img class="mark" src="/brand/mark.png" alt="Giga Couch"></a>
    <p class="wordmark"><span>GIGA</span><span>COUCH</span></p>
    <p class="eyebrow">Your account</p>
    <div class="worlds" aria-hidden="true"></div>
    <p class="rail-foot"><span>Your ideas. Your games.</span>Built for playing together.</p>
  </aside>
  <main>
    <section id="form">
      <p class="eyebrow">Sign up</p>
      <h1>Make a name for this library.</h1>
      <p class="lede">Use the same name on the TV. If a code is on the screen, enter it and that couch signs in too.</p>
      <form id="account" class="panel">
        <label>Name<input name="name" autocomplete="username" required></label>
        <label>Passphrase<input name="passphrase" type="password" autocomplete="current-password" minlength="8" required></label>
        <label>Code from the TV<input name="user_code" autocomplete="one-time-code" placeholder="Optional"></label>
        <div class="actions">
          <button type="submit">Create account</button>
          <button type="button" id="signin" class="quiet">Sign in</button>
        </div>
      </form>
      <p id="result"></p>
    </section>
    <section id="library" hidden>
      <p class="eyebrow">Signed in</p>
      <h1 id="hello">Library</h1>
      <p class="lede">These are the games this account can see.</p>
      <ul id="games" class="panel"></ul>
      <button type="button" id="signout" class="quiet">Sign out</button>
    </section>
  </main>
  <script>
    var form = document.getElementById("account");
    var result = document.getElementById("result");
    var library = document.getElementById("library");
    var token = localStorage.getItem("gigacouch_token");

    function showLibrary() {
      document.getElementById("form").hidden = true;
      library.hidden = false;
      fetch("/v1/library", { headers: { Authorization: "Bearer " + token } })
        .then(function (response) { return response.json().then(function (body) { return { ok: response.ok, body: body }; }); })
        .then(function (payload) {
          if (!payload.ok) {
            localStorage.removeItem("gigacouch_token");
            document.getElementById("form").hidden = false;
            library.hidden = true;
            result.textContent = payload.body.error || "Sign in again.";
            return;
          }
          document.getElementById("hello").textContent = localStorage.getItem("gigacouch_name") || "Library";
          document.getElementById("games").innerHTML = (payload.body.games || []).map(function (game) {
            var note = game.downloadable ? "Download from the Home app" : "Already on the couch";
            return "<li><strong>" + game.title + "</strong><span>" + note + "</span></li>";
          }).join("");
        });
    }

    function submit(mode) {
      var data = Object.fromEntries(new FormData(form).entries());
      var path = data.user_code ? "/v1/link" : (mode === "login" ? "/v1/login" : "/v1/signup");
      fetch(path, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(data) })
        .then(function (response) { return response.json().then(function (body) { return { ok: response.ok, body: body }; }); })
        .then(function (payload) {
          if (!payload.ok) {
            result.textContent = payload.body.error || "That did not work.";
            return;
          }
          token = payload.body.token;
          localStorage.setItem("gigacouch_token", token);
          localStorage.setItem("gigacouch_name", payload.body.name);
          result.textContent = "";
          showLibrary();
        });
    }

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      submit("signup");
    });
    document.getElementById("signin").addEventListener("click", function () { submit("login"); });
    document.getElementById("signout").addEventListener("click", function () {
      localStorage.removeItem("gigacouch_token");
      localStorage.removeItem("gigacouch_name");
      token = "";
      library.hidden = true;
      document.getElementById("form").hidden = false;
    });
    if (token) showLibrary();
  </script>
</body>
</html>
"#;

pub const SITE_CSS: &str = r#"
:root { color-scheme: dark; }
* { box-sizing: border-box; }
body { margin: 0; min-height: 100vh; display: grid; grid-template-columns: 280px 1fr; background: #101722; color: #f2f5f8; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
a { color: inherit; text-decoration: none; }
.rail { position: relative; padding: 28px 28px 36px; background: linear-gradient(180deg, #213d3c 0%, #16272d 42%, #111d2a 100%); display: flex; flex-direction: column; }
.mark { width: 72px; height: 72px; object-fit: contain; }
.wordmark { margin: 14px 0 0; font-weight: 800; letter-spacing: 0.04em; line-height: 1; font-size: 22px; }
.wordmark span { display: block; }
.eyebrow { margin: 18px 0 0; color: #8ce8be; font-size: 11px; font-weight: 600; letter-spacing: 0.14em; text-transform: uppercase; }
.worlds { margin: 28px auto 8px; width: 170px; height: 120px; background:
  linear-gradient(180deg, transparent 0 46%, #8ce8be 46% 48%, transparent 48%),
  linear-gradient(135deg, transparent 49%, rgba(154,190,247,0.35) 50%, transparent 51%),
  linear-gradient(45deg, transparent 49%, rgba(140,232,190,0.9) 50%, transparent 51%);
}
.steps { list-style: none; padding: 0; margin: 28px 0 0; }
.steps li { display: flex; gap: 12px; margin: 0 0 16px; font-size: 14px; }
.steps span { color: #8ce8be; font-weight: 600; font-variant-numeric: tabular-nums; }
.rail-foot { margin-top: auto; }
.rail-foot span { display: block; color: #8ce8be; font-size: 11px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; }
main { padding: 64px 7vw 72px; }
h1 { margin: 10px 0 0; max-width: 16ch; font-size: clamp(36px, 4vw, 56px); font-weight: 600; letter-spacing: -0.03em; line-height: 1.02; }
.lede { max-width: 38rem; color: #a0afbf; font-size: 16px; line-height: 1.5; }
.actions { display: flex; gap: 12px; align-items: center; margin-top: 22px; }
.button, button { display: inline-block; background: #8ce8be; color: #101722; border: 0; border-radius: 9px; padding: 12px 18px; font: inherit; font-size: 14px; font-weight: 600; }
.quiet, button.quiet { background: transparent; color: #f2f5f8; border: 1px solid #2d3b4b; border-radius: 9px; padding: 10px 14px; }
.cards { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; max-width: 44rem; margin-top: 36px; }
.cards article, form.panel, ul.panel, form, #games { background: #192331; border: 1px solid #2d3b4b; border-radius: 12px; }
.cards article { padding: 16px 18px; }
.cards h2 { margin: 0; font-size: 16px; }
.cards p, #result, label { color: #a0afbf; }
form, #games { max-width: 32rem; padding: 8px 18px 18px; margin-top: 18px; }
label { display: block; margin-top: 14px; font-size: 13px; }
input { width: 100%; margin-top: 6px; padding: 10px 12px; border-radius: 9px; border: 1px solid #2d3b4b; background: #101722; color: #f2f5f8; font: inherit; }
ul { list-style: none; padding: 0 18px; }
li { display: flex; justify-content: space-between; gap: 16px; padding: 14px 0; border-bottom: 1px solid #2d3b4b; }
li span { color: #a0afbf; }
#signout { margin-top: 16px; }
@media (max-width: 800px) {
  body { grid-template-columns: 1fr; }
  .rail { min-height: auto; }
  .worlds, .steps { display: none; }
  .cards { grid-template-columns: 1fr; }
}
"#;

pub const MARK_PNG: &[u8] = include_bytes!("../../../brand/mark.png");
pub const SPACE_GROTESK_WOFF2: &[u8] = include_bytes!("../../../brand/fonts/SpaceGrotesk.woff2");
pub const INTER_WOFF2: &[u8] = include_bytes!("../../../brand/fonts/Inter.woff2");
