const { app, BrowserWindow } = require("electron");
const fs = require("fs");
const path = require("path");

const origin = process.env.GIGACOUCH_ORIGIN || "";
if (!/^http:\/\/127\.0\.0\.1:\d+$/.test(origin)) {
  console.error("GIGACOUCH_ORIGIN must be http://127.0.0.1:<port>");
  process.exit(1);
}

app.commandLine.appendSwitch("autoplay-policy", "no-user-gesture-required");

function sameOrigin(url) {
  return url === origin || url.startsWith(`${origin}/`);
}

function createWindow() {
  const windowed = process.env.GIGACOUCH_WINDOWED === "1";
  const win = new BrowserWindow({
    width: 1280,
    height: 720,
    fullscreen: !windowed,
    kiosk: !windowed,
    autoHideMenuBar: true,
    backgroundColor: "#101722",
    title: process.env.GIGACOUCH_TITLE || "Giga Couch",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      devTools: process.env.GIGACOUCH_DEVTOOLS === "1",
    },
  });

  win.webContents.on("before-input-event", (event, input) => {
    if (input.type !== "keyDown" || input.key !== "Escape") {
      return;
    }
    const current = win.webContents.getURL();
    if (current.includes("/play/")) {
      event.preventDefault();
      win.loadURL(`${origin}/`);
    }
  });
  win.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  win.webContents.on("will-navigate", (event, url) => {
    if (!sameOrigin(url)) {
      event.preventDefault();
    }
  });
  win.webContents.on("will-redirect", (event, url) => {
    if (!sameOrigin(url)) {
      event.preventDefault();
    }
  });
  win.webContents.on("will-attach-webview", (event) => event.preventDefault());
  win.webContents.session.setPermissionRequestHandler((_contents, _permission, callback) => {
    callback(false);
  });

  const quitPoll = setInterval(async () => {
    try {
      const response = await fetch(`${origin}/__gigacouch/v1/control`);
      const body = await response.json();
      if (body.quit) {
        clearInterval(quitPoll);
        app.quit();
      }
    } catch (_error) {
      /* The origin is local; a refused connection means it is already gone. */
    }
  }, 400);

  win.webContents.on("did-finish-load", async () => {
    win.focus();
    win.webContents.focus();
    if (process.env.GIGACOUCH_DEMO_JOIN === "1" || process.env.GIGACOUCH_DEMO_RIGHT === "1") {
      await new Promise((resolve) => setTimeout(resolve, 800));
    }
    if (process.env.GIGACOUCH_DEMO_JOIN === "1") {
      win.webContents.sendInputEvent({ type: "keyDown", keyCode: "Return" });
      await new Promise((resolve) => setTimeout(resolve, 250));
      win.webContents.sendInputEvent({ type: "keyUp", keyCode: "Return" });
    }
    if (process.env.GIGACOUCH_DEMO_RIGHT === "1") {
      await new Promise((resolve) => setTimeout(resolve, 400));
      win.webContents.sendInputEvent({ type: "keyDown", keyCode: "Right" });
      await new Promise((resolve) => setTimeout(resolve, 120));
      win.webContents.sendInputEvent({ type: "keyUp", keyCode: "Right" });
    }
    if (process.env.GIGACOUCH_SCREENSHOT) {
      await new Promise((resolve) => setTimeout(resolve, 700));
      const image = await win.webContents.capturePage();
      fs.writeFileSync(process.env.GIGACOUCH_SCREENSHOT, image.toPNG());
      if (process.env.GIGACOUCH_SCREENSHOT_QUIT === "1") {
        app.quit();
      }
    }
  });

  win.loadURL(`${origin}/`);
}

app.whenReady().then(createWindow);
app.on("window-all-closed", () => app.quit());
