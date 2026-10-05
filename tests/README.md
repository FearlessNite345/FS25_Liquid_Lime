# Liquid Lime regression checks

From the repository root, run `lua tests/fill_state.lua` with Lua 5.1 or later.
The suite uses engine stubs and does not require FS25. It covers temporary getter
cleanup (including inherited methods, nested wrappers and errors), empty tanks,
switching to fertilizer, attached sources and helper auto-buy selection.
`build.bat` excludes this directory from the playable mod.

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
