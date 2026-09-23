(function () {
  var canvas = document.getElementById("view");
  var ctx = canvas.getContext("2d");
  var colors = [
    "#8ce8be", "#ffb086", "#f2d16b", "#9ec1ff", "#f2a0c2", "#d7c4ff",
    "#7ed0ff", "#f0f2f5", "#ff8f8f", "#b6e37a", "#ffd1a1", "#8ee0d0",
    "#e7b2ff", "#ffe38a", "#a8c0d8", "#ff9ec4"
  ];
  var blobs = new Map();
  var last = performance.now();

  function resize() {
    var scale = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.floor(window.innerWidth * scale);
    canvas.height = Math.floor(window.innerHeight * scale);
    ctx.setTransform(scale, 0, 0, scale, 0, 0);
  }

  window.addEventListener("resize", resize);
  resize();

  function view() {
    return { w: window.innerWidth, h: window.innerHeight };
  }

  function island() {
    var size = view();
    return {
      x: size.w * 0.5,
      y: size.h * 0.46,
      rx: Math.min(size.w, size.h) * 0.34,
      ry: Math.min(size.w, size.h) * 0.24,
    };
  }

  function ensure(player, index) {
    if (blobs.has(player.id)) {
      return blobs.get(player.id);
    }
    var land = island();
    var angle = (index / 16) * Math.PI * 2;
    var blob = {
      id: player.id,
      name: player.name,
      x: land.x + Math.cos(angle) * land.rx * 0.25,
      y: land.y + Math.sin(angle) * land.ry * 0.25,
      hop: 0,
      vy: 0,
      color: colors[(player.id - 1) % colors.length],
    };
    blobs.set(player.id, blob);
    return blob;
  }

  function frame(now) {
    var dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    var size = view();
    var land = island();
    var api = window.GigaCouch;
    var players = api ? api.players.list() : [];
    var live = new Set();
    players.forEach(function (player, index) {
      live.add(player.id);
      var blob = ensure(player, index);
      blob.name = player.name;
      var move = api.input.axis(player.id, "move");
      if (api.input.action(player.id, "jump") && blob.hop === 0) {
        blob.vy = -520;
      }
      blob.x += move.x * 280 * dt;
      blob.y += move.y * 280 * dt;
      blob.vy += 1600 * dt;
      blob.hop += blob.vy * dt;
      if (blob.hop > 0) {
        blob.hop = 0;
        blob.vy = 0;
      }
      var nx = (blob.x - land.x) / land.rx;
      var ny = (blob.y - land.y) / land.ry;
      if (nx * nx + ny * ny > 1) {
        blob.x = land.x;
        blob.y = land.y;
        blob.hop = 0;
        blob.vy = 0;
      }
    });
    Array.from(blobs.keys()).forEach(function (id) {
      if (!live.has(id)) {
        blobs.delete(id);
      }
    });
    var list = Array.from(blobs.values());
    for (var i = 0; i < list.length; i += 1) {
      for (var j = i + 1; j < list.length; j += 1) {
        var a = list[i];
        var b = list[j];
        var dx = b.x - a.x;
        var dy = b.y - a.y;
        var dist = Math.hypot(dx, dy) || 1;
        if (dist < 64) {
          var push = (64 - dist) / 2;
          a.x -= (dx / dist) * push;
          a.y -= (dy / dist) * push;
          b.x += (dx / dist) * push;
          b.y += (dy / dist) * push;
        }
      }
    }
    draw(size, land, players, api);
    window.requestAnimationFrame(frame);
  }

  function draw(size, land, players, api) {
    ctx.clearRect(0, 0, size.w, size.h);
    var water = ctx.createLinearGradient(0, 0, 0, size.h);
    water.addColorStop(0, "#17324a");
    water.addColorStop(1, "#101722");
    ctx.fillStyle = water;
    ctx.fillRect(0, 0, size.w, size.h);
    ctx.fillStyle = "#1f6b58";
    ctx.beginPath();
    ctx.ellipse(land.x, land.y + 18, land.rx, land.ry, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#8ce8be";
    ctx.beginPath();
    ctx.ellipse(land.x, land.y, land.rx, land.ry, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#d9fff0";
    ctx.beginPath();
    ctx.ellipse(land.x - land.rx * 0.15, land.y - land.ry * 0.2, land.rx * 0.45, land.ry * 0.28, -0.4, 0, Math.PI * 2);
    ctx.fill();
    blobs.forEach(function (blob) {
      ctx.fillStyle = "rgba(16, 23, 34, 0.28)";
      ctx.beginPath();
      ctx.ellipse(blob.x, blob.y + 8, 26, 12, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = blob.color;
      ctx.beginPath();
      ctx.arc(blob.x, blob.y + blob.hop, 28, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#10221c";
      ctx.font = "700 22px ui-sans-serif, sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(String(blob.id), blob.x, blob.y + blob.hop + 1);
    });
    ctx.fillStyle = "rgba(16, 23, 34, 0.72)";
    ctx.fillRect(size.w * 0.08, size.h * 0.86, size.w * 0.84, 64);
    ctx.fillStyle = "#f2f5f8";
    ctx.font = "600 22px ui-sans-serif, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    var hint = "Enter or the south button joins. Space or south jumps. Backspace leaves, or hold east.";
    if (api && players[0]) {
      hint = players.length + " playing. " + api.input.glyph(players[0].id, "jump") + " jumps. " + api.input.glyph(players[0].id, "leave") + " leaves.";
    } else if (!api) {
      hint = "Open Blob Island from Giga Couch.";
    }
    ctx.fillText(hint, size.w * 0.5, size.h * 0.86 + 32);
  }

  window.requestAnimationFrame(frame);
})();
