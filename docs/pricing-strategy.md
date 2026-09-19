# Pricing strategy options

Status: brainstorming and working hypotheses, September 16, 2026. No launch price, subscription requirement, marketplace percentage, or source license is selected. Dollar examples are USD and illustrative unless identified as historical figures.

Related: [Product vision](../PRODUCT.md), [technical architecture](../TECH_STACK.md), [implementation plan](../IMPLEMENTATION_PLAN.md), and [multiplayer design](multiplayer.md).

## 1. Current direction: sell the play-and-create experience

The latest direction is to sell Giga Couch as a product people enjoy in its own right:

> Play a collection of multiplayer games. Modify them or make your own. Bring your people together, with up to 16 players as a target. Share or sell your creations when you want to.

The base purchase could include a substantial collection of games, approachable creation tools, and multiplayer support. Community sharing and a creator marketplace would add value on top, with Giga Couch taking a percentage of marketplace sales.

**Making a game for your own party is valuable even if you never publish it.** The product should justify its price for someone who only plays, personalizes games for friends, or creates privately. Revenue should not depend entirely on customers becoming successful sellers.

The two leading price ideas discussed are **$20 once** and **$5/month**. The subscription proposal explicitly included **everyone: players and creators**. Charging only creators for hosting was an earlier, separate option. Neither is a final decision.

### The experience worth paying for

1. **Play:** start with enjoyable included games.
2. **Customize:** change questions, names, rules, teams, difficulty, or appearance.
3. **Remix:** use an editable game as the starting point for something different.
4. **Create:** build a new game using Godot, the SDK, templates, and guidance.
5. **Share:** optionally distribute it privately or publicly.
6. **Sell:** optionally charge through the marketplace.

This makes creation approachable without requiring every customer to become a professional developer. It also gives non-creators immediate value from the included games.

These are product goals, not a statement that the full experience is implemented. In particular, 16 software player slots do not establish that every combination of 16 controllers, phones, computers, and network connections works. Network multiplayer and phone remotes require their own implementation and testing. An approachable creation workflow also needs more than access to an SDK.

## 2. All the business models discussed

These options can be combined, but a launch offering should be simple enough to explain in a few sentences.

| Option | What customers pay for | Main advantage | Main difficulty |
| --- | --- | --- | --- |
| Free platform, marketplace commission | Paid games; Giga Couch keeps a percentage | Easy adoption and broad creator participation | Free users and free games generate costs without direct revenue |
| Creator service subscription | Managed distribution, storage, multiplayer connectivity, and tools | Developers avoid operating their own backend | Charges creators before they necessarily earn anything; players may produce most usage |
| Universal membership: $5/month | Playing and creating, included games, and defined online services | Recurring funding for development and operations | Subscription friction, especially if every guest must subscribe |
| One-time platform purchase: $20 | Included games and the local play-and-create product | Familiar game purchase; immediate development funding | Each sale must support a long-lived customer without recurring base revenue |
| One-time purchase plus optional services | Permanent local product; recurring cloud features separately | Connects recurring charges to recurring usage | More complicated packaging; base offer must still feel complete |
| Catalog subscription | Access to a paid game collection | A simple discovery and entertainment offer | Requires creator compensation and a valuable continuing catalog |
| Open-source platform with paid services | Official hosting, convenience, content, support, or membership | Broad technical adoption and potential contributions | Software access alone becomes a weaker reason to pay |

Marketplace commission can supplement any of these. Open source is also a licensing decision that intersects with several pricing models, rather than a mutually exclusive price plan.

### A. Free tools, free storefront, free games; commission on paid sales

The original adoption-first proposal:

- Free creation tools and storefront access.
- Games marked free cost the player nothing.
- Creators can charge for games; Giga Couch receives a percentage of sales.
- Everyone is encouraged to try making something.

A 10% or 15% commission is a hypothesis to model, not an agreed rate. The business needs enough paid sales to cover the whole platform, including people who only play free games.

The central problem is that **free distribution still costs money**: storage, downloads, updates, account services, abuse handling, and potentially relay traffic. A popular free game could cost more to serve than an unpopular paid game. Bound free hosted usage, subsidize it deliberately, or offer paid capacity; do not assume marketplace sales automatically cover it.

### B. Charge creators for managed services

The earlier server-business idea was to let developers use Giga Couch networking instead of building and operating their own backend. Illustrative creator-plan ideas ranged from $5 to roughly $15/month, with higher usage priced separately; neither figure came from measured costs.

The current network design is a **message relay**. Player-owned computers run the games; Giga Couch forwards messages and manages connections. Developers still implement game rules and synchronization using SDK support. Hosting the entire game simulation would be a different, more demanding service.

This could become a standalone developer offering or a higher-capacity add-on. It need not be the primary identity of the consumer product. See [multiplayer responsibilities and metering](multiplayer.md).

### C. Charge everyone $5/month

This proposal treats players and creators as members of the same platform. Membership could include the game collection, creation tools, community access, and bounded distribution and relay usage. Creating a game would not require a separate creator upgrade.

It provides recurring revenue for SDK development, compatibility work, new games, and service operation. It also needs a recurring reason to stay: continued use, useful improvements, new content, or online services. Occasional party hosts may subscribe for an event and cancel.

Two distinct versions must not be confused:

- **Platform membership:** includes the platform and a defined collection; premium creator games can still cost extra.
- **All-access catalog membership:** includes participating premium games; creators need a subscription-revenue allocation or licensing arrangement.

The first does not automatically grant access to everything in the marketplace. The second cannot rely solely on a commission from purchases that never happen.

### D. Sell the platform once for $20

This matches the idea of selling Giga Couch like a game: buy it, receive games to play immediately, and gain the ability to customize and create more.

Define the entitlement before selling:

- Which local features and included games remain usable permanently?
- Which updates are included, and could future major versions cost extra?
- What distribution and online-play allowance comes with the purchase?
- Does it cover a person, household, host computer, or some number of devices?

A permanent local license can coexist with optional paid cloud services, expansions, or major upgrades. Avoid implying that $20 includes unlimited hosting, every future game, and every future update forever unless those promises are intentional and affordable.

For comparison, LaunchBox separates permanent software ownership from the period of included updates. That is an example of a licensing structure, not evidence that its exact pricing fits Giga Couch. [LaunchBox Premium](https://www.launchbox-app.com/premium)

### E. One-time purchase plus optional online membership

A possible compromise is a paid local collection and creation product, with optional recurring payment for managed online play, larger distribution allowances, or additional services.

This preserves a durable purchase while funding continuing costs. The tradeoff is a more complex offer. Decide whether basic online play is included before marketing multiplayer as a core purchase benefit; customers should understand any additional charge before buying.

Other later possibilities include paid game/template packs, storage or traffic packs, and plans for schools or event organizers. These are expansion options, not a reason to launch a complicated tier system.

## 3. Who pays in a 16-person game?

Price and licensing unit are separate decisions. “$5/month” is incomplete until we know whether it means per person, household, host, or account with device limits.

| Possible rule | Effect on adoption and revenue |
| --- | --- |
| Every participant pays | More potential subscribers; substantial friction when inviting guests |
| Each participating household pays | Shared use fits family play; household boundaries need definition |
| Each computer needs a license | Multiple local players can share a machine; network sessions may require several purchases |
| One paying host, guests join free | Easy invitations; the host's payment must support guest usage |
| Free phone remotes, paid game-running computers | Simple couch joining; still leaves remote-computer licensing to decide |

If every person needs a $5 membership, six people represent $30/month and 16 represent $80/month. If every person needs a $20 purchase, 16 first-time buyers represent $320 upfront. These examples apply only to a per-person policy; 16 controllers do not necessarily mean 16 licenses or network connections.

**Working recommendation to test:** free guest participation, especially phone remotes, with payment attached to the host or household. This is an alternative to the earlier “everyone subscribes” proposal, not a settled change to it.

Also separate the platform license from a game's license. A host owning Giga Couch does not automatically establish whether other computers may download and run a paid creator's game under that host's purchase.

## 4. Included games and the creator marketplace

### The base collection

Included games make the platform useful before a community marketplace exists. Prioritize a collection people want to replay, with a useful range of group sizes and activities. An editable subset can double as teaching material and creation starting points.

Specify the rights for each included game and its assets:

- Play only.
- Modify privately.
- Redistribute permitted remixes.
- Sell permitted derivatives.

These are different permissions. Commission or license suitable games and assets for the intended uses. The presence of a prototype in this repository is not evidence that its branding, characters, artwork, or design can be commercially bundled.

### Marketplace revenue

Creators could offer free games, paid games, and appropriately licensed templates or asset packs. A purchase commission lets Giga Couch earn more as creators sell more, while the base product earns revenue from private creation and play.

Before choosing a percentage, define:

- Whether the commission base excludes taxes, refunds, and discounts.
- Who bears payment processing, storefront charges, disputes, and payout costs.
- What hosting and relay usage the commission includes.
- Whether high usage creates an additional creator charge.
- What buyers retain if platform membership ends.

A reasonable policy to evaluate is preserving separately purchased games and customer-created projects, while subscription-only services expire. Actual access rules depend on the selected platform-license model and must be explained before purchase.

For comparison, itch.io lets sellers choose its revenue share and treats payment-provider fees separately. Its structure illustrates why the advertised commission alone does not describe a creator's payout. [itch.io payments documentation](https://itch.io/docs/creators/payments)

If premium creator games enter an all-access subscription, define a separate compensation model: negotiated licenses, a revenue pool, or another explicit agreement. Usage-based pools introduce measurement and gaming problems; they are additional product work.

## 5. Costs: development counts too

Pricing must fund the product's creation and continued improvement as well as the servers.

| Cost category | Examples |
| --- | --- |
| Initial development | Launcher, SDK, packaging, multiplayer, controller integration, templates, onboarding |
| Continuing development | Godot/OS compatibility, bug fixes, documentation, new features and games |
| Content | Original games, licensed assets, commissioned work, creator compensation |
| Distribution | Package storage, download traffic, update traffic, backups |
| Online operation | Rooms, relay traffic, connections, backend capacity, monitoring |
| Community and commerce | Support, moderation, payment costs, refunds, fraud, creator payouts |
| Business operation | Customer acquisition, administration, and other operating expenses |

Running games on player computers avoids operating every game simulation, but does not make online play free. Relay cost depends on connected computers, message volume, recipients, and duration. Sixteen people on one computer can have very different service costs from sixteen computers.

Illustrations, not vendor quotes:

- A 200 MB game downloaded 100 times transfers roughly 20 GB before overhead or caching effects.
- Relaying a 1 KB message to three computers 20 times per second sends roughly 216 MB/hour of outbound payload, before other messages and protocol overhead.
- Keeping local/LAN play local avoids relay traffic for those sessions.

If creation uses customers' own AI tools or API accounts, those AI costs stay with the customer. Including AI generation in a platform subscription would require a separate cost model and clear usage limits.

### Simple revenue arithmetic

| Example | Gross platform receipts or commission before costs |
| --- | --- |
| 1,000 new purchases at $20 | $20,000 once |
| 1,000 active members at $5/month | $5,000/month |
| $100,000 of eligible marketplace sales at 15% | $15,000 commission |

These are not profit projections. Marketplace sales belonging to creators are not all platform revenue. Processing, taxes where applicable, refunds, acquisition, support, infrastructure, content, and development still need treatment in the model.

Four months at $5 equals $20 in nominal gross payments. It does not establish economic equivalence: conversion, cancellations, repeat use, lifetime service cost, and the timing of cash receipts all matter.

For a first model, calculate contribution per customer after variable costs, then ask how many purchases or retained members cover monthly development and other fixed expenses. Model free users and heavy users explicitly; an average-only forecast can hide expensive usage.

## 6. Open source, adoption, and revenue

Open source could encourage trust, integrations, contributions, and self-hosting. It also permits redistribution under the chosen license, so compulsory payment for access to the same software becomes harder to sustain. Open source allows commercial use; a restriction against competitors selling the code would not meet the Open Source Definition. [Open Source Initiative](https://opensource.org/osd)

| Approach | Potential benefit | Revenue implication |
| --- | --- | --- |
| Open SDK, examples, and package specification; proprietary launcher | Creators can inspect and integrate the platform while the consumer product remains paid | Supports selling the official product; only some components are open source |
| Open launcher and SDK; paid managed services | Broad participation and self-hosting | Revenue comes from convenience, operation, content, and community services |
| Paid official builds of open-source software | Supporters can pay for convenient distribution and development | Others may redistribute under the license; payment cannot be assumed universal |
| Open software with separately licensed game collection | Community improves the tools while included content supports the bundle's value | Code and content rights must be clear and independently managed |

Godot's MIT license permits commercial products and does not require games created with it to use the same license. Giga Couch's own code, included games, and individual assets still need their own licensing decisions and applicable notices. [Godot license](https://godotengine.org/license/)

GDevelop provides an example of an open-source engine combined with paid service plans. This demonstrates a possible structure, not that contributions or subscription revenue will automatically cover Giga Couch's costs. [GDevelop plans](https://gdevelop.io/pricing)

Potential contributions are valuable but require documentation, review, maintenance, and project direction. Do not count volunteer work as guaranteed development capacity. Self-hosting also does not entitle someone to unlimited use of Giga Couch-operated servers.

**Open decision:** how much to open, and under which licenses. No source-release decision is made by this document.

## 7. Phones, mobile apps, and pricing

Phone remotes could make large-group play easier: scan a code and use buttons, text entry, drawing, or private game information. A free browser-based remote is a promising guest experience because it can reduce the need for extra controllers and guest purchases. It remains a feature to build and validate.

This is distinct from a mobile app that downloads and executes complete Godot games. Apple's rules address downloaded code, creator content, and mini apps in different sections; Godot's ability to export to iOS does not by itself establish approval for a downloadable-game catalog. Do not make the initial revenue plan depend on that approval. [Apple App Review Guidelines, sections 1.2.1, 2.5.2, and 4.7](https://developer.apple.com/app-store/review/guidelines/)

A remote input connection also does not automatically show a remote player's game screen. Multi-computer play needs a local game instance or a separately designed video-streaming experience. Any pricing promise about playing remotely must match the implemented experience.

## 8. What Minecraft suggests—and what it does not

Minecraft illustrates selling a compelling creative product early, then expanding the surrounding business. Its alpha price was €9.95; the beta transition in December 2010 raised the price to €14.95. Early buyers received different future-update promises from later buyers. The lesson is to define founding-customer entitlements carefully. [Contemporary pricing report](https://www.gamedeveloper.com/game-platforms/pricier-beta-version-of-i-minecraft-i-to-hit-december-20), [archived announcement by Notch](https://blog.omniarchive.net/post/2175441966/minecraft-beta-december-20-2010/)

For Giga Couch, the useful analogy is that **playing and creating can justify a purchase before a marketplace exists**. It supports testing a paid early product with real included value. It does not prove that $20 is the right price, that lifetime online services are affordable, or that a similar commercial outcome is likely.

Minecraft also separates software from hosting: players can run their own server, while Realms offers paid managed hosting. The Marketplace arrived in 2017, years after the original paid game. These illustrate ways to add services and creator commerce around an already valuable product. Giga Couch's proposed relay performs less work than a hosted game server, so Realms pricing would not directly establish relay economics. [Minecraft server software](https://www.minecraft.net/en-us/download/server), [Realms](https://www.minecraft.net/en-us/realms), [Marketplace anniversary](https://www.minecraft.net/nb-no/article/marketplace-5-year-celebration)

The revenue question from the discussion provides historical scale:

- Reporting put Mojang revenue at roughly $80 million in its first 15-month reporting period starting in October 2010. [Forbes](https://www.forbes.com/sites/danielnyegriffiths/2012/03/28/mojang-minecraft-millions/)
- Reported 2012 revenue was around $240 million. [GameSpot](https://www.gamespot.com/articles/notch-discusses-minecraft-money/1100-6403344/)
- One contemporary account valued 2013 revenue at about $330 million using its currency conversion. [TIME](https://time.com/28891/minecraft-is-still-generating-insane-amounts-of-cash-for-developer-mojang/)

Those rough figures add to about $650 million through 2013. This is a sum of reported company revenues, not profit, personal earnings, or an exact Minecraft-only total through the acquisition date. Dollar conversions vary across reports. Microsoft completed the acquisition on November 6, 2014 for $2.5 billion, net of acquired cash; that purchase price is separate from game-sales revenue. [Microsoft acquisition disclosure](https://www.sec.gov/Archives/edgar/data/789019/000119312515272806/R17.htm)

Treat Minecraft as an exceptional case and a product-model reference, not a Giga Couch forecast.

## 9. How to choose without guessing

Test the same clear product proposition under the leading offers:

1. **$20 once:** included game collection plus local play and creation, with explicit update and online-service terms.
2. **$5/month:** the collection, creation, and defined ongoing services while subscribed.
3. **Hybrid, if needed:** paid local product plus optional recurring online services.

Separately test the licensing unit: everyone pays versus a host or household paying with free guests. Changing both the price and the guest policy at once makes the results harder to interpret.

Useful evidence includes:

- Actual paid pilot purchases and reasons people decline.
- Time from installation to a successful group game.
- Time to a first meaningful customization or playable creation.
- Repeat play and creation after 30 and 90 days.
- Guest-to-customer conversion and invitation abandonment.
- Subscription retention and event-driven cancellations.
- Download and relay costs per active household and per heavy user.
- Support effort, refund reasons, and demand for additional included games.
- Whether people value private creation without sharing or selling.

Begin with a small, polished collection and a convincing creation loop. Record the limits of the tested multiplayer setup. Sell features that work, with future features clearly distinguished from purchase entitlements.

## 10. Working conclusion and unresolved decisions

**The strongest current product hypothesis is a paid multiplayer game collection with the ability to modify and create games, plus an optional community and marketplace.** This follows the latest discussion and earns revenue from the core value even when customers never sell anything.

| Decision | Current status |
| --- | --- |
| Primary value | Play, customize, and create games for your people |
| Included game collection | Desired part of the base offer; size and rights unresolved |
| Base price | $20 once and $5/month are leading hypotheses |
| Who pays | Everyone was explicitly proposed; host, household, and free-guest alternatives remain open |
| Multiplayer | Up to 16 players is a product target; supported configurations need qualification |
| Online infrastructure | Managed message relay; games execute on player-owned computers |
| Marketplace | Optional selling with a platform commission; rate and fee allocation unresolved |
| Free games | No separate game price; platform-access requirements and hosting subsidy depend on the chosen model |
| Online allowances | Must be measured and defined before promising a flat-price service |
| Updates and cancellation | Permanent versus subscription entitlements need explicit terms |
| Open source | Scope and licenses unresolved; SDK openness and paid product can coexist |
| Mobile | Phone remotes are a promising route; downloaded-game app approval is not assumed |

Choose the initial offer after validating both willingness to pay and the cost of serving real groups. Keep the explanation centered on the customer's experience: **games to play now, tools to make them your own, and people to play them with.**
