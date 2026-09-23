use serde::{Deserialize, Serialize};
use std::time::{Duration, Instant};

pub const MAX_REQUEST_BYTES: u64 = 300 * 1024;
pub const MAX_SAVE_BYTES: usize = 256 * 1024;
const EAST_HOLD: Duration = Duration::from_millis(1250);
const DEAD_ZONE: f32 = 0.2;
const MAX_DEVICES: usize = 17;

#[derive(Debug, Deserialize)]
pub struct DevicePost {
    #[serde(default)]
    pub devices: Vec<RawDevice>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RawDevice {
    pub id: String,
    #[serde(default)]
    pub kind: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub family: String,
    #[serde(default)]
    pub south: bool,
    #[serde(default)]
    pub east: bool,
    #[serde(default)]
    pub jump: bool,
    #[serde(default)]
    pub leave: bool,
    #[serde(default)]
    pub analog: bool,
    #[serde(default, rename = "move")]
    pub movement: Axis,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct Axis {
    #[serde(default)]
    pub x: f32,
    #[serde(default)]
    pub y: f32,
}

#[derive(Debug, Clone, Serialize)]
pub struct Snapshot {
    pub players: Vec<SnapshotPlayer>,
    pub menu: MenuSnapshot,
}

#[derive(Debug, Clone, Serialize)]
pub struct MenuSnapshot {
    #[serde(rename = "move")]
    pub movement: Move,
    pub confirm: bool,
    pub back: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct SnapshotPlayer {
    pub id: u8,
    pub name: String,
    #[serde(rename = "move")]
    pub movement: Move,
    pub edges: Edges,
    pub glyphs: Glyphs,
}

#[derive(Debug, Clone, Serialize)]
pub struct Move {
    pub x: f32,
    pub y: f32,
}

#[derive(Debug, Clone, Serialize)]
pub struct Edges {
    pub jump: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct Glyphs {
    pub jump: String,
    pub leave: String,
    pub r#move: String,
}

struct Tracked {
    id: String,
    south: bool,
    east: bool,
    jump: bool,
    leave: bool,
    east_since: Option<Instant>,
    slot: Option<u8>,
}

struct Slot {
    device_id: String,
    name: String,
    family: String,
    move_x: f32,
    move_y: f32,
    jump: bool,
}

pub struct Session {
    tracked: Vec<Tracked>,
    slots: Vec<Option<Slot>>,
    menu_x: f32,
    menu_y: f32,
    menu_confirm: bool,
    menu_back: bool,
}

impl Session {
    pub fn new(max_players: u8) -> Self {
        Self {
            tracked: Vec::new(),
            slots: (0..max_players).map(|_| None).collect(),
            menu_x: 0.0,
            menu_y: 0.0,
            menu_confirm: false,
            menu_back: false,
        }
    }

    pub fn apply(&mut self, post: DevicePost, now: Instant) {
        let mut devices = Vec::new();
        for device in post.devices {
            if devices.len() == MAX_DEVICES {
                break;
            }
            if !valid_device_id(&device.id)
                || devices.iter().any(|seen: &RawDevice| seen.id == device.id)
            {
                continue;
            }
            devices.push(device);
        }
        let live: Vec<String> = devices.iter().map(|device| device.id.clone()).collect();
        let gone: Vec<String> = self
            .tracked
            .iter()
            .filter(|tracked| !live.iter().any(|id| id == &tracked.id))
            .map(|tracked| tracked.id.clone())
            .collect();
        for id in gone {
            self.release_device(&id);
            self.tracked.retain(|tracked| tracked.id != id);
        }
        self.menu_x = 0.0;
        self.menu_y = 0.0;
        for device in devices {
            self.apply_one(device, now);
        }
    }

    pub fn snapshot(&mut self) -> Snapshot {
        let mut players = Vec::new();
        for (index, slot) in self.slots.iter_mut().enumerate() {
            let Some(slot) = slot else {
                continue;
            };
            let jump = slot.jump;
            slot.jump = false;
            players.push(SnapshotPlayer {
                id: (index as u8) + 1,
                name: slot.name.clone(),
                movement: Move {
                    x: slot.move_x,
                    y: slot.move_y,
                },
                edges: Edges { jump },
                glyphs: glyphs(&slot.family),
            });
        }
        let menu = MenuSnapshot {
            movement: Move {
                x: self.menu_x,
                y: self.menu_y,
            },
            confirm: self.menu_confirm,
            back: self.menu_back,
        };
        self.menu_confirm = false;
        self.menu_back = false;
        Snapshot { players, menu }
    }

    fn apply_one(&mut self, device: RawDevice, now: Instant) {
        let keyboard = device.kind == "keyboard";
        let family = if keyboard {
            "keyboard".to_string()
        } else if matches!(device.family.as_str(), "xbox" | "playstation" | "generic") {
            device.family.clone()
        } else {
            "generic".to_string()
        };
        let name = clean_name(if device.name.trim().is_empty() {
            if keyboard { "Keyboard" } else { "Controller" }
        } else {
            device.name.trim()
        });
        let (move_x, move_y) = if device.analog {
            analog_move(device.movement.x, device.movement.y)
        } else {
            digital_move(device.movement.x, device.movement.y)
        };
        let position = self
            .tracked
            .iter()
            .position(|tracked| tracked.id == device.id);
        if position.is_none() {
            self.tracked.push(Tracked {
                id: device.id.clone(),
                south: false,
                east: false,
                jump: false,
                leave: false,
                east_since: None,
                slot: None,
            });
        }
        let position = self
            .tracked
            .iter()
            .position(|tracked| tracked.id == device.id)
            .expect("tracked");
        let south_rise = device.south && !self.tracked[position].south;
        let east_rise = device.east && !self.tracked[position].east;
        let jump_rise = device.jump && !self.tracked[position].jump;
        let leave_rise = device.leave && !self.tracked[position].leave;
        if south_rise || jump_rise {
            self.menu_confirm = true;
        }
        if leave_rise || (!keyboard && east_rise) {
            self.menu_back = true;
        }
        if move_x != 0.0 || move_y != 0.0 {
            self.menu_x = move_x;
            self.menu_y = move_y;
        }
        let mut slot = self.tracked[position].slot;
        if slot.is_none() {
            let join = if keyboard {
                south_rise || jump_rise
            } else {
                south_rise
            };
            if join {
                slot = self.allocate(&device.id, &name, &family);
            }
        } else if let Some(slot_index) = slot {
            let state = self.slots[slot_index as usize].as_mut().expect("slot");
            state.name = name.clone();
            state.family = family.clone();
            state.move_x = move_x;
            state.move_y = move_y;
            if keyboard {
                if jump_rise {
                    state.jump = true;
                }
                if leave_rise {
                    slot = None;
                }
            } else {
                if south_rise {
                    state.jump = true;
                }
                if device.east {
                    let started = self.tracked[position].east_since.get_or_insert(now);
                    if now.saturating_duration_since(*started) >= EAST_HOLD {
                        slot = None;
                    }
                }
            }
        }
        if !device.east {
            self.tracked[position].east_since = None;
        }
        if slot.is_none() {
            if self.tracked[position].slot.is_some() {
                self.release_device(&device.id);
            }
        } else if let Some(slot_index) = slot {
            if let Some(state) = self.slots[slot_index as usize].as_mut() {
                state.move_x = move_x;
                state.move_y = move_y;
            }
            self.tracked[position].slot = Some(slot_index);
        }
        self.tracked[position].south = device.south;
        self.tracked[position].east = device.east;
        self.tracked[position].jump = device.jump;
        self.tracked[position].leave = device.leave;
        if slot.is_none() {
            self.tracked[position].slot = None;
            self.tracked[position].east_since = None;
        }
    }

    fn allocate(&mut self, device_id: &str, name: &str, family: &str) -> Option<u8> {
        let index = self.slots.iter().position(|slot| slot.is_none())?;
        self.slots[index] = Some(Slot {
            device_id: device_id.to_string(),
            name: name.to_string(),
            family: family.to_string(),
            move_x: 0.0,
            move_y: 0.0,
            jump: false,
        });
        let slot = index as u8;
        if let Some(tracked) = self
            .tracked
            .iter_mut()
            .find(|tracked| tracked.id == device_id)
        {
            tracked.slot = Some(slot);
        }
        Some(slot)
    }

    fn release_device(&mut self, device_id: &str) {
        for slot in &mut self.slots {
            if slot
                .as_ref()
                .is_some_and(|state| state.device_id == device_id)
            {
                *slot = None;
            }
        }
        if let Some(tracked) = self
            .tracked
            .iter_mut()
            .find(|tracked| tracked.id == device_id)
        {
            tracked.slot = None;
            tracked.east_since = None;
        }
    }
}

pub fn valid_slot(slot: &str) -> bool {
    (1..=32).contains(&slot.len())
        && slot
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'_' || byte == b'-')
}

fn valid_device_id(id: &str) -> bool {
    !id.is_empty() && id.len() <= 160 && !id.chars().any(char::is_control)
}

fn clean_name(name: &str) -> String {
    name.chars()
        .filter(|ch| !ch.is_control())
        .take(48)
        .collect()
}

fn glyphs(family: &str) -> Glyphs {
    match family {
        "keyboard" => Glyphs {
            jump: "Space".into(),
            leave: "Backspace".into(),
            r#move: "WASD".into(),
        },
        "playstation" => Glyphs {
            jump: "Cross".into(),
            leave: "Circle".into(),
            r#move: "Stick".into(),
        },
        "xbox" => Glyphs {
            jump: "A".into(),
            leave: "B".into(),
            r#move: "Stick".into(),
        },
        _ => Glyphs {
            jump: "South".into(),
            leave: "East".into(),
            r#move: "Stick".into(),
        },
    }
}

fn analog_move(x: f32, y: f32) -> (f32, f32) {
    if !x.is_finite() || !y.is_finite() {
        return (0.0, 0.0);
    }
    let x = x.clamp(-1.0, 1.0);
    let y = y.clamp(-1.0, 1.0);
    let strength = x.hypot(y);
    if strength <= DEAD_ZONE {
        return (0.0, 0.0);
    }
    let scaled = ((strength - DEAD_ZONE) / (1.0 - DEAD_ZONE)).clamp(0.0, 1.0);
    let unit = scaled / strength;
    (x * unit, y * unit)
}

fn digital_move(x: f32, y: f32) -> (f32, f32) {
    if !x.is_finite() || !y.is_finite() {
        return (0.0, 0.0);
    }
    let x = x.clamp(-1.0, 1.0);
    let y = y.clamp(-1.0, 1.0);
    let strength = x.hypot(y);
    if strength <= f32::EPSILON {
        return (0.0, 0.0);
    }
    if strength > 1.0 {
        return (x / strength, y / strength);
    }
    (x, y)
}
