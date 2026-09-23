(function () {
  var latches = new Map();
  var players = [];
  var axes = new Map();
  var glyphs = new Map();
  var menu = { move: { x: 0, y: 0 }, confirm: false, back: false };

  function remember(data) {
    var seen = new Set();
    players = data.players || [];
    players.forEach(function (player) {
      seen.add(player.id);
      var latch = latches.get(player.id) || { jump: false };
      if (player.edges && player.edges.jump) {
        latch.jump = true;
      }
      latches.set(player.id, latch);
      axes.set(player.id, player.move || { x: 0, y: 0 });
      glyphs.set(player.id, player.glyphs || {});
    });
    if (data.menu) {
      menu.move = data.menu.move || { x: 0, y: 0 };
      if (data.menu.confirm) {
        menu.confirm = true;
      }
      if (data.menu.back) {
        menu.back = true;
      }
    }
    Array.from(latches.keys()).forEach(function (id) {
      if (!seen.has(id)) {
        latches.delete(id);
        axes.delete(id);
        glyphs.delete(id);
      }
    });
  }

  function poll() {
    fetch("/__gigacouch/v1/snapshot", { cache: "no-store" })
      .then(function (response) {
        if (!response.ok) {
          return null;
        }
        return response.json();
      })
      .then(function (data) {
        if (data) {
          remember(data);
        }
      })
      .catch(function () {});
  }

  setInterval(poll, 16);
  poll();

  function consumeJump(playerId) {
    var latch = latches.get(playerId);
    if (!latch || !latch.jump) {
      return false;
    }
    latch.jump = false;
    return true;
  }

  window.GigaCouch = {
    api: "1",
    players: {
      list: function () {
        return players.map(function (player) {
          return { id: player.id, name: player.name };
        });
      },
    },
    input: {
      action: function (playerId, name) {
        if (name !== "jump" && name !== "primary_action") {
          return false;
        }
        return consumeJump(playerId);
      },
      axis: function (playerId, name) {
        if (name !== "move") {
          return { x: 0, y: 0 };
        }
        var value = axes.get(playerId) || { x: 0, y: 0 };
        return { x: value.x, y: value.y };
      },
      glyph: function (playerId, name) {
        var table = glyphs.get(playerId) || {};
        return table[name] || "";
      },
    },
    save: {
      read: function (slot) {
        return fetch("/__gigacouch/v1/save/read", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ slot: slot }),
        }).then(function (response) {
          return response.json().then(function (body) {
            if (!response.ok) {
              throw new Error((body && body.error) || "save read failed");
            }
            return body.data;
          });
        });
      },
      write: function (slot, data) {
        return fetch("/__gigacouch/v1/save/write", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ slot: slot, data: data }),
        }).then(function (response) {
          return response.json().then(function (body) {
            if (!response.ok) {
              throw new Error((body && body.error) || "save write failed");
            }
          });
        });
      },
    },
    menu: {
      move: function () {
        return { x: menu.move.x || 0, y: menu.move.y || 0 };
      },
      confirm: function () {
        var value = menu.confirm;
        menu.confirm = false;
        return value;
      },
      back: function () {
        var value = menu.back;
        menu.back = false;
        return value;
      },
    },
    lifecycle: {
      quit: function () {
        fetch("/__gigacouch/v1/quit", { method: "POST" }).catch(function () {});
      },
    },
  };
})();
