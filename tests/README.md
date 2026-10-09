# Liquid Lime regression checks

From the repository root, run `lua tests/fill_state.lua` and
`lua tests/price_history.lua` with Lua 5.1 or later.
The suite uses engine stubs and does not require FS25. It covers temporary getter
cleanup (including inherited methods, nested wrappers and errors), empty tanks,
switching to fertilizer, attached sources and helper auto-buy selection.
`build.bat` excludes this directory from the playable mod.

## Price-history correction in the refreshed release

The new `PriceHistory.lua` module changes only LIQUIDLIME's native price-history
values. It never changes fill-type base prices, seasonal factors, selling-point
multipliers, helper costs, production revenue, purchases, or the Prices GUI.
The version stays 1.3.0.1 and the stable release tag stays v1.3.0.1.

On the server, after saved economy and placeables finish loading, it checks every
LIQUIDLIME-accepting selling station (including hidden stations). A correction is
allowed only when at least one exists, all are this mod's sell point, and their
original per-litre prices agree. The initial twelve months then use that station
baseline times the fill type's seasonal factors. With the current configuration,
the starting Hard-difficulty range is 202.50–258.75 per 1,000 L. The normal GIANTS
graph, difficulty scaling, hourly history averaging and save/network code continue
to operate afterward. A historical/seasonal graph is not an exact current quote;
use the station's displayed current price for a sale.

Mixed or unknown sellers and malformed data leave history unchanged. If a first
compatible station is placed later, the correction is deferred until its loading
has completed and all twelve months are synchronized through GIANTS' native
pricing-history events. Clients never perform the migration themselves.

Before changing history, all twelve old values are copied in memory. On the next
normal save they are retained under `economy.liquidLimePriceHistory.backup` in
`economy.xml`, alongside a version marker. The backup is never replaced with newer
history, and the marker prevents repeated corrections on reload. Any existing
marker, including an unsupported or malformed one, blocks a second reset. Known
backup values and marker attributes are retained; unknown future fields are not
interpreted by this version. A full pre-install save backup is still recommended.

For rollback, back up the save first, remove this refreshed release, and restore the
pre-install save with the previous stable ZIP. If retaining later gameplay progress,
the twelve backup values can instead restore LIQUIDLIME's native history entries
(native entries store rounded price-per-litre × 1,000). This advanced recovery
should be performed on a copy; never change other fill types or money values.

The engine-independent suite checks the one-time correction, complete old-history
backup, marker roundtrips, unchanged pricing inputs, malformed/foreign station
guards, client behavior, late placement and sync retries, and hook cleanup across
save loads. These tests do not establish actual FS25 gameplay compatibility.

### Required in-game checks for this correction

- Use a backup of the affected save and a fresh save. With the mod's sell point,
  compare the graph, current station quote and a measured small sale before/after.
  The quote and proceeds should remain unchanged under identical conditions.
- Save, exit and reload. Confirm the marker and twelve original backup values
  survive, and a subsequently recorded month's price is not reset again.
- Check Hard, Normal and Easy, single player, hosted multiplayer and a dedicated
  server. Confirm a joining client sees the corrected graph.
- Start without the sell point, then place it. Verify the deferred correction and
  existing-client synchronization. Test mixed map/mod sellers: no correction.
- Verify fixed tank purchases, helper auto-buy and production direct-selling are
  unchanged. Retain log.txt and record the exact FS25/PF/Courseplay versions.

API behavior was inspected against FS25 1.24.0.0, source snapshot
`3468a959481747ea9c60ecdb455c661e3b7762a5` in
https://github.com/maxkra1985/FarmingSimulator25_dataS:
`scripts/economy/EconomyManager.lua`, `scripts/objects/SellingStation.lua`,
`scripts/FSBaseMission.lua`, `scripts/BaseMission.lua`, and the native pricing
history events. Other game builds and actual gameplay have not been tested here.

## Community feedback for v1.3.0.1

- [#38](https://github.com/FearlessNite345/FS25_Liquid_Lime/issues/38#issuecomment-5979282156): gesture1968 reported no more switching issues in `v1.3.0.1-beta.1`.
- [#40](https://github.com/FearlessNite345/FS25_Liquid_Lime/issues/40#issuecomment-5923879258): NongDeChuanRen tested Test Build 1 with Precision Farming and reported that the stale unload prompt was gone.
- [#39](https://github.com/FearlessNite345/FS25_Liquid_Lime/issues/39#issuecomment-5980123960): NongDeChuanRen reported successful Courseplay stop, refill and resume behaviour with the Condor Endurance. The original DT 2800H S5 was unavailable; the exact beta, Precision Farming and helper auto-buy settings were not explicitly reconfirmed in that reply.

The maintainer accepted this feedback for closing #38, #39 and #40 and preparing
the stable GitHub release. This is not a full gameplay test matrix. ModHub
submission to GIANTS Software for testing is planned, not yet submitted or approved.

## Remaining in-game verification

Use a backup save and the latest FS25, Precision Farming and Courseplay versions.
Record their version numbers and keep log.txt. Test single player and a dedicated
server/client; repeat basic fill/unload checks without Precision Farming.

- #38/#40: In the Vantage 4300 and a second base-game sprayer, fill with liquid
  lime, spray, unload completely, then refill with liquid fertilizer. Verify that
  PF switches to nitrogen application without reloading the save and that
  unloading removes the correct material exactly once. Repeat in reverse and with
  herbicide. Recheck the reported COOP filler on Ray County Missouri.
- #39: With helper purchase disabled, run the DT 2800H S5 out of lime on a
  Courseplay course. Verify that spraying stops and Courseplay requests/refills
  material. Refill and resume. Separately check the base-game helper with purchase
  enabled: liquid lime should still be bought, charged and applied correctly.
- Repeat with an attached supply tank, including an empty sprayer with a loaded
  tank. Verify nozzle visuals, PF pH application and consumption.
- #37: Check the existing and newly placed sell point on Hard, including the
  reported Ratzinger Hoehe server. Compare the price table and actual sale payout
  after loading the updated mod. Confirm that purchase prices are unchanged.

## Proposed sale balance

Only the mod's sell-point multiplier changes, from 0.23 to 0.50. At unchanged
market conditions, the reported 119 per 1,000 L becomes approximately 258.70.
This is a balance proposal, not a guaranteed price or profit on every map.

With the current recipe, 1,000 L lime plus 1,000 L water yields 2,000 L liquid lime.
At the reported 224 lime cost, the above sale yields 517.39 gross, leaving 293.39
before water, operating costs, upkeep, transport and the building investment.
Ten cycles at four per hour incur 50 in active production costs. Market movement,
price drops, difficulty and map-specific costs still affect the result.

Beyond the community feedback above, these checks have not been verified in FS25
for this release. The price, payout and screenshot/display concerns in #37 remain
open, and map-specific interactions need in-game verification. Existing leaked
runtime getters are cleared by restarting the game/server with the updated mod.
