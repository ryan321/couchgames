# GigaCouch Creator Vocabulary

You do **not** need to know game-development terminology to create a game with AI.

You can say:

> “When the sword gets close enough to the monster, make the monster take damage.”

And an AI agent can probably figure out what you mean.

But knowing a few terms lets you say:

> “Make the sword's **hitbox** damage the enemy's **hurtbox**.”

That is shorter, clearer, and much less likely to be misunderstood.

This guide covers the game-development words that are most useful when working with an AI agent.

---

# The Essential Vocabulary

## Hitbox

An invisible shape that determines where an attack can hit something.

**Instead of:**

> Make it so when the sword gets close enough to the enemy it hurts him.

**Say:**

> Add a hitbox to the sword.

---

## Hurtbox

The area of a character or object that can receive damage.

A sword might have a **hitbox**.  
A player might have a **hurtbox**.

**Example:**

> Make the enemy's hurtbox slightly smaller than its visible body.

---

## Collider / Collision Shape

An invisible shape used to determine whether objects physically touch or block one another.

Examples:

- the floor stopping the player from falling
- a wall stopping the player
- a car hitting another car

**Example:**

> Add a collider to the wall so the player can't walk through it.

A collider is not necessarily the same thing as a hitbox.

---

## Trigger / Area

An invisible region that detects something entering or leaving it without necessarily physically blocking it.

Examples:

- entering a room starts music
- walking near a chest displays “Open”
- crossing a finish line ends the race

**Example:**

> Put a trigger at the doorway that starts the boss fight.

In Godot, you will often encounter an **Area2D** or **Area3D** for this.

---

# Characters

## Player Character

The character controlled by the player.

Often shortened to **player**.

---

## NPC

**Non-Player Character.**

Any character that isn't directly controlled by a human player.

An NPC could be:

- an enemy
- a shopkeeper
- a civilian
- an ally
- a quest giver

When talking to an AI, being more specific is usually better.

Instead of:

> Make the NPC follow me.

Say:

> Make the enemy follow the player.

or:

> Make the friendly NPC follow the player.

---

## Enemy / Hostile NPC

A character that opposes or attacks the player.

“Enemy” is usually clearer than simply saying “NPC” when that's what you mean.

---

## Boss

A particularly important or powerful enemy, usually associated with a special encounter.

---

## Mob

A generic enemy or group of ordinary enemies.

Common in RPGs and survival games.

---

# Creating Things in the World

## Spawn

To create something in the game world while the game is running.

**Example:**

> Spawn three enemies when the player enters the room.

---

## Spawn Point

The location where something appears.

**Example:**

> Put enemy spawn points around the edge of the arena.

---

## Respawn

Bring something back after it has died or disappeared.

**Example:**

> Respawn the player at the last checkpoint.

---

## Despawn

Remove something from the game world.

**Example:**

> Despawn enemies when they're more than 500 meters from every player.

---

## Instance

A particular copy of something used in the game.

You might create one enemy design and then create 30 **instances** of that enemy.

**Example:**

> Create an instance of the goblin scene at each spawn point.

---

# Godot Terms

GigaCouch is initially built around Godot, so these terms are especially useful. GigaCouch games are ordinary Godot projects using the platform SDK rather than a proprietary game editor.

## Scene

A reusable collection of game objects.

A scene might represent:

- a character
- a car
- a menu
- a level
- a treasure chest
- an entire game screen

**Example:**

> Create an Enemy scene that I can reuse throughout the level.

---

## Node

The basic building block of a Godot scene.

A character scene might contain nodes for:

```text
Player
├── CharacterBody3D
├── Camera
├── CollisionShape
├── AnimationPlayer
├── AudioPlayer
└── Hitbox

```

Knowing the word **node** makes conversations with Godot-focused AI agents much easier.

---

## Parent / Child

Nodes can contain other nodes.

The containing node is the **parent**.

The contained node is the **child**.

**Example:**

> Make the sword a child of the player's hand node.

---

## Scene Tree

The hierarchy of nodes currently making up the game.

If an AI says:

> “Add this node to the scene tree”

it basically means:

> “Put this object into the hierarchy of objects in the game.”

---

## Script

Code attached to something in the game.

GigaCouch's initial Godot games use GDScript.

**Example:**

> Attach a script to the enemy that makes it chase the nearest player.

---

## Signal

Godot's system for announcing that something happened.

Examples:

```text
button_pressed
player_died
enemy_defeated
race_finished
door_opened

```

One object can emit a signal, and another can respond.

**Example:**

> Emit a signal when the boss dies and have the exit door listen for it.

---

# Movement and Position

## Transform

An object's:

- position
- rotation
- scale

Collectively these are often called its **transform**.

---

## Position

Where something is.

---

## Rotation

Which direction something is turned.

---

## Scale

How large or small something is relative to its normal size.

---

## Velocity

How fast something is moving and in what direction.

**Example:**

> Increase the player's forward velocity while sprinting.

---

## Acceleration

How quickly velocity changes.

Acceleration often makes movement feel smoother than instantly changing speed.

---

## Vector

A set of numbers representing a direction, position, or movement.

You don't usually need to calculate vectors yourself, but the term appears constantly in game-development conversations.

---

# Physics

## Rigid Body

An object whose movement is largely controlled by the physics simulation.

Examples:

- falling boxes
- bouncing balls
- loose debris

---

## Character Body

A physics object designed for characters whose movement is intentionally controlled.

Godot uses types such as:

- `CharacterBody2D`
- `CharacterBody3D`

---

## Gravity

Acceleration pulling objects downward—or whatever direction your game defines as down.

---

## Friction

Resistance that slows objects sliding across surfaces.

---

## Bounce / Restitution

How much an object bounces after a collision.

---

## Physics Tick

One update of the game's physics simulation.

Physics often runs at a consistent rate even when visual frame rate changes.

---

# Combat

## Damage

How much health an attack removes.

---

## Health / HP

How much damage something can receive before dying or being destroyed.

HP means **Hit Points** or **Health Points**.

---

## Cooldown

The period before an action can be used again.

**Example:**

> Give the dash a 1.5-second cooldown.

---

## Invulnerability Frames / I-Frames

A brief period in which a character cannot be damaged.

**Example:**

> Give the player 0.75 seconds of invulnerability after taking damage.

---

## Knockback

Force applied to a character when hit.

---

## Projectile

An object launched through the game world.

Examples:

- bullet
- arrow
- fireball
- snowball

---

## Melee

Close-range combat.

---

## Ranged

Combat from a distance.

---

## AoE

**Area of Effect.**

An attack or ability affecting an area rather than one exact target.

**Example:**

> Make the explosion an AoE attack with a five-meter radius.

---

# Enemy AI

## Aggro

When an enemy notices a player and becomes hostile toward them.

---

## Aggro Range

How close a player must get before an enemy reacts.

**Example:**

> Give the wolf a 15-meter aggro range.

---

## Target

The character an enemy is currently trying to attack, follow, protect, or otherwise interact with.

---

## Line of Sight

Whether one object can actually “see” another without something blocking the view.

**Example:**

> Enemies should only aggro if the player is inside their detection range and they have line of sight.

---

## Raycast

An invisible line projected through the world to detect what it hits.

Useful for:

- shooting
- checking line of sight
- detecting the floor
- selecting objects
- determining what the player is looking at

---

## Pathfinding

Finding a route from one point to another while avoiding obstacles.

---

## Navigation Mesh / Navmesh

An invisible map describing where characters are allowed to walk.

**Example:**

> Bake a navmesh so enemies can pathfind around the furniture.

---

## Waypoint

A location that an AI character can travel toward.

---

## Patrol

Movement between predefined areas or waypoints.

**Example:**

> Have the guard patrol between these four waypoints until he sees the player.

---

## State

The current behavior or condition of something.

An enemy might have states such as:

```text
IDLE
PATROL
CHASE
ATTACK
STUNNED
DEAD

```

---

## State Machine

A system for controlling which **state** something is currently in and how it switches between states.

This is an extremely useful term when describing behavior to AI.

**Example:**

> Give the enemy a state machine with idle, patrol, chase, attack, stunned, and dead states.

---

# Camera Terms

## First Person

The camera sees approximately through the character's eyes.

---

## Third Person

The camera follows the player's character from outside the character.

---

## Top-Down

The camera looks down onto the game world.

---

## Isometric

An angled overhead perspective commonly used in strategy and RPG games.

---

## FOV

**Field of View.**

How wide the camera can see.

---

## Camera Shake

Small camera movement used to emphasize:

- explosions
- impacts
- crashes
- powerful attacks

---

## Camera Follow

A system that keeps the camera following a character or object.

---

## Camera Smoothing

Gradual movement that prevents the camera from snapping instantly to its target.

---

# Animation

## Animation

Changes to something over time.

Not just character motion—animations can also control:

- doors
- UI
- cameras
- lights
- colors
- scale

---

## Animation State

A particular animation currently being used.

Examples:

```text
idle
walk
run
jump
attack
die

```

---

## Animation Blend

Smoothly transitioning between animations.

---

## Rig / Skeleton

The internal bone structure used to animate a 3D model.

---

## Bone

An individual part of a skeleton controlling part of a model.

---

## IK

**Inverse Kinematics.**

A system that automatically positions parts of a character to reach a target.

Examples:

- feet staying on uneven ground
- a hand gripping a sword
- a character reaching toward an object

---

# Graphics

## Sprite

A 2D image displayed inside the game.

---

## Texture

An image applied to something.

A 3D wall might use a brick texture.

---

## Material

Settings controlling how a surface looks.

Materials may determine:

- texture
- shininess
- roughness
- transparency
- glow

---

## Shader

Code that controls how graphics are rendered.

Shaders can create effects such as:

- water
- outlines
- invisibility
- holograms
- glowing objects
- distortion

---

## Particle System

A system that produces many small visual elements.

Examples:

- smoke
- sparks
- snow
- fire
- magic
- dust

---

## Mesh

The geometric shape of a 3D object.

---

## Model

A complete 3D object, often including a mesh and possibly textures, materials, skeletons, and animations.

---

# Level Design

## Level

A playable area or section of the game.

---

## Map

Often used similarly to **level**, especially in multiplayer games.

---

## Environment

The surrounding world:

- buildings
- terrain
- trees
- furniture
- props
- sky

---

## Prop

A smaller object placed in the environment.

Examples:

- barrel
- chair
- lamp
- crate

---

## Checkpoint

A saved location or state the player can return to.

---

## Objective

Something the player is supposed to accomplish.

---

## Encounter

A designed gameplay event.

Examples:

- enemy ambush
- puzzle
- boss battle
- chase scene

---

## Procedural Generation

Creating content automatically according to rules rather than designing every part manually.

Examples:

- random caves
- random loot
- random maps
- random enemy placement

---

## Seed

A number used to reproduce the same “random” procedural result.

**Example:**

> Allow players to enter a world seed so they can recreate the same map.

---

# Game Rules

## Mechanic

A rule or interaction that contributes to gameplay.

Examples:

- jumping
- crafting
- blocking
- hiding
- drifting
- fishing

---

## Gameplay Loop

The sequence of actions players repeat throughout the game.

Example:

```text
Explore
↓
Find resources
↓
Build equipment
↓
Fight enemies
↓
Explore farther

```

---

## Win Condition

What causes the player to win.

---

## Lose Condition

What causes the player to lose.

---

## Difficulty Scaling

Changing difficulty according to factors such as:

- level
- player count
- elapsed time
- player performance

---

## RNG

**Random Number Generation.**

Used as shorthand for randomness.

**Example:**

> Use RNG to choose which treasure appears.

---

# Input and Controllers

Input is especially important for GigaCouch because controllers and local multiplayer are platform-level capabilities rather than something every creator should have to reinvent.

## Input

Anything the player does to control the game.

---

## Input Action

A meaningful action rather than one particular physical button.

Examples:

```text
jump
attack
interact
pause
move

```

GigaCouch deliberately uses semantic actions like these rather than requiring games to care whether the player pressed Xbox A or PlayStation Cross.

**Better:**

> Make `jump` trigger the character's jump.

**Less useful:**

> Make Xbox A make the character jump.

---

## Input Mapping

Connecting physical buttons or keys to game actions.

---

## Remapping

Allowing the player to change those mappings.

---

## Analog Input

Input with a range rather than simply on/off.

Examples:

- joystick
- trigger

---

## Dead Zone

A small region around the center of an analog stick that the game ignores.

This prevents tiny stick movements or controller drift from moving the player.

---

## Rumble / Haptics

Controller vibration or other tactile feedback.

---

## Button Glyph

The picture representing a controller button.

Example:

```text
Press [A]

```

or:

```text
Press [Cross]

```

GigaCouch's SDK is designed to provide the appropriate glyph based on the player's controller.

---

# Local Multiplayer

## Local Multiplayer

Multiple players using the same computer or console.

For GigaCouch, this is a core concept.

---

## Couch Co-op

Players physically together playing cooperatively on one system.

---

## Local Versus

Players physically together competing against each other.

---

## Player Slot

A logical player position such as:

```text
Player 1
Player 2
Player 3
Player 4

```

---

## Device

The actual controller being used.

A **player** and a **controller device** are not necessarily the same concept.

GigaCouch's SDK handles controller ownership so games can think primarily in terms of Player 1, Player 2, and so forth rather than raw hardware IDs.

---

## Join

Assign a controller to a player.

Example:

> Use “Press any button to join” for Players 2–4.

---

## Drop-In / Drop-Out

Allowing players to join or leave while a game is already underway.

---

## Split Screen

Displaying multiple players' viewpoints simultaneously by dividing the screen.

---

## Shared Screen

Multiple players play together while using the same camera/view.

---

# User Interface

## UI

**User Interface.**

Menus, buttons, health bars, inventory screens, prompts, and other information displayed to the player.

---

## HUD

**Heads-Up Display.**

Gameplay information displayed while playing.

Examples:

- health
- score
- ammunition
- mini-map
- timer

---

## Menu

A UI containing choices.

---

## Focus

Which UI element currently receives controller input.

Focus is particularly important in controller-driven TV interfaces.

---

## Modal / Dialog

A temporary interface that appears over another screen and expects the user to respond.

Examples:

```text
Are you sure you want to quit?

YES    NO

```

---

## Tooltip

Small explanatory text shown when highlighting or hovering over something.

---

## Prompt

A message telling the player what action is available.

Example:

```text
Press A to Open

```

---

## Safe Area / Safe Margin

Space kept around screen edges so important UI is easy to see on televisions.

GigaCouch specifically includes TV-safe UI and controller navigation as platform concerns.

---

# Audio

## SFX

**Sound Effects.**

Examples:

- footsteps
- sword hits
- explosions
- button clicks

---

## BGM

**Background Music.**

---

## Ambient Audio

Sounds establishing the environment.

Examples:

- wind
- rain
- distant traffic
- forest sounds

---

## Audio Loop

A sound that repeats continuously.

---

## Spatial Audio / 3D Audio

Audio whose apparent location changes based on where the sound is in relation to the player.

---

# Saving

## Save Game

Stored information allowing players to continue later.

---

## Save State

The specific collection of information being saved.

Examples:

```text
player position
inventory
level
health
completed quests

```

---

## Persistent

Information that survives after the game closes.

---

## Session

Information that only needs to exist during the current play session.

---

## Serialization

Converting game state into data that can be stored and loaded later.

You usually won't need to do this manually, but it is a useful term when talking to an AI agent.

GigaCouch provides a standardized save interface so individual games do not need to reinvent storage.

---

# Performance

## FPS

**Frames Per Second.**

How many images the game renders each second.

Common targets include:

```text
30 FPS
60 FPS
120 FPS

```

---

## Frame

One rendered image of the game.

---

## Frame Rate

How quickly frames are being rendered.

---

## Lag

A broad informal term for noticeable delay or poor responsiveness.

It is better to specify the actual problem when possible.

Instead of:

> The game is laggy.

Try:

> The frame rate drops when 50 enemies are on screen.

or:

> Controller input feels delayed.

---

## Latency

Delay between something happening and its result being received or displayed.

Especially important in online games.

---

## LOD

**Level of Detail.**

Using simpler versions of distant objects to improve performance.

---

## Draw Call

A request for the graphics system to draw something.

Too many draw calls can hurt performance.

This is more advanced and usually doesn't matter until optimization becomes necessary.

---

## Optimization

Changing how something works so it requires fewer computing resources without unnecessarily changing the gameplay.

---

# Bugs and Testing

## Bug

Something in the game that behaves incorrectly.

---

## Reproduce

Find a reliable sequence of actions that causes a bug.

**Example:**

> I can reproduce the bug by pausing while Player 2 disconnects their controller.

This is extremely useful information for an AI debugging agent.

---

## Regression

Something that previously worked but broke after another change.

---

## Edge Case

An unusual situation the game still needs to handle.

Examples:

- player disconnects controller during a menu
- two players die simultaneously
- save file doesn't exist yet
- player quits during a loading screen

---

## Debug

Investigate and fix a problem.

---

## Log

Recorded information about what the game was doing.

Logs are extremely helpful when an AI agent is trying to diagnose a problem.

---

# Online Multiplayer Terms

These aren't necessary for every GigaCouch creator, but they become valuable when creating networked games.

## Client

A player's copy of the game connected to a multiplayer session.

---

## Server

The system responsible for coordinating a multiplayer game.

---

## Host

The machine or player acting as the multiplayer server.

---

## Authority

Which machine is allowed to decide the official version of some game state.

---

## Replication

Sending game state between machines.

Examples:

- player position
- enemy health
- opened doors

---

## RPC

**Remote Procedure Call.**

A message telling another machine to execute some game action.

---

## Ping

A rough measurement of network communication delay.

Usually measured in milliseconds.

---

## Desync

When two players' games disagree about what is happening.

---

## Lobby

The place where players gather before entering a multiplayer match.

---

## Matchmaking

Finding other players to play with.

---

# Asset Terms

## Asset

Any reusable piece of game content.

Examples:

- image
- model
- texture
- sound
- animation
- font
- music
- level

---

## Asset Pack

A collection of related assets.

---

## Placeholder

Temporary content used while developing the game.

**Example:**

> Use a placeholder cube for the enemy until we have the final model.

This term is particularly useful when working rapidly with AI.

---

## Prototype

An early version built to test whether an idea works.

A prototype does not need final art or polish.

---

# Some Extremely Useful Design Words

These aren't technical programming terms, but they greatly improve prompts.

## Feedback

The game's response showing that something happened.

Examples:

When the player hits an enemy:

```text
sound
flash
animation
particles
knockback
controller rumble

```

Together these provide **feedback**.

---

## Game Feel

How satisfying and responsive the game feels to control.

It includes things such as:

- acceleration
- animation timing
- sound
- camera movement
- particles
- impact effects

---

## Juice

An informal game-development term for extra feedback and polish that makes actions feel satisfying.

**Example:**

> Add more juice to the attack: hit flash, particles, camera shake, sound, and a tiny freeze-frame.

---

## Telegraph

A visual or audio warning before something happens.

**Example:**

> Telegraph the boss's slam attack for one second before it hits.

---

## Wind-Up

The preparation time before an action happens.

---

## Recovery

The time after an action before the character can act normally again.

---

## Hit Stop / Hit Pause

A very short freeze when an attack connects, often used to make impacts feel powerful.

---

## Screen Shake

Another common term for camera shake.

---

# A Creator Doesn't Need to Memorize All of This

The important idea is not:

> Learn game development before making games.

It is:

> Learn useful words as you encounter them.

A creator could begin with only these:

```text
scene
node
player
enemy
NPC
spawn
hitbox
hurtbox
collider
trigger
state
state machine
raycast
pathfinding
checkpoint
UI
HUD
input action
player slot
animation
asset
placeholder
prototype
FPS
bug

```

Knowing even those terms makes AI instructions dramatically more precise.

---

# Example: Ordinary Description vs Game-Development Vocabulary

### Ordinary description

> Have the monster walk around until the player gets kind of close. Then if it can see the player it should come after him. When it gets close enough it should attack, but don't let it attack constantly. If the player runs away it should eventually stop following.

### Using game-development terminology

> Give the enemy a state machine with **Patrol, Chase, Attack, and Return** states. Give it a 15-meter **aggro range**, but require **line of sight** before entering Chase. Use **pathfinding** to pursue the nearest player. Enter Attack when the player is within melee range, with a 1.5-second **attack cooldown**. If the player leaves the leash radius, return to the patrol area.

Both descriptions can work.

The second simply gives the AI much less room to misunderstand what you want.

---

# The Rule

Use normal language whenever normal language is easier.

Use game-development terminology when you know it.

You are not trying to become a professional programmer.

You are building a shared vocabulary between:

```text
YOUR IDEA
     ↓
YOUR WORDS
     ↓
AI AGENT
     ↓
GAME ENGINE
     ↓
GAME

```

The better the shared vocabulary becomes, the faster that conversation becomes.