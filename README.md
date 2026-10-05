# **Liquid Lime Mod - v1.3.0.1**

Welcome to the **Liquid Lime Mod**! This mod introduces **Liquid Lime**, a sprayer-compatible material designed to enhance your farming experience with added realism.  

![fsScreen_2024_11_20_19_27_44](https://github.com/user-attachments/assets/369f874b-1533-4049-bd0c-478e5be199d1)

## Official ModHub  

[Official ModHub Link](https://www.farming-simulator.com/mod.php?mod_id=304579).

**Pending ModHub Version:** v1.3.0.1 - planned for submission to GIANTS Software for ModHub testing; not yet submitted or approved.<br>
**Current ModHub Version:** v1.3.0.0

Stay tuned for future updates and fixes as needed! Please check the future plans outlined below.

## **GitHub Release v1.3.0.1**

- Fixed temporary Precision Farming fill-type overrides remaining after switching materials or unloading.
- Fixed empty tanks being treated as if they still contained Liquid Lime, affecting refill detection.
- Increased the Liquid Lime Sell Point multiplier from 0.23 to 0.50; buying prices are unchanged. Price, display and payout verification remains open in [#37](../../issues/37).
- Community feedback supports closing #38, #39 and #40. The Condor Endurance stop/refill/resume test does not cover every equipment and mod combination; see `tests/README.md` for the remaining checks.

This is the stable GitHub release. The earlier `v1.3.0.1-beta.1` remains available as a historical test build. Both display version `1.3.0.1` in game, so use the ZIP from the stable release when updating.

## **Install Notes**

- Use the in-game ModHub version when possible.
- If installing from GitHub, download the release zip and place it in `Documents/My Games/FarmingSimulator2025/mods`.
- Replace the existing `FS25_Liquid_Lime.zip` and restart the game/server. Do not keep both builds installed; everyone on a multiplayer server needs the same ZIP.
- Do not use GitHub's source-code zip directly unless you rename/repack it as a valid FS25 mod zip.
- Precision Farming support for Liquid Lime is fully built in. ThundRFS Precision Farming Configurator is no longer required for Liquid Lime support.

## **Features**  
- **Liquid Lime Fill Type**:  
  - Adds Liquid Lime to the game as a new material compatible with sprayers.  
  - Designed to closely replicate the properties of real liquid lime for a more authentic gameplay experience.
  - Adds runtime support for selected base-game liquid trailers: ABI 550, ABI 1600, Lizard MKS 8, and Lizard MKS 32.

## **Items**  
- **Liquid Lime Tank**:  
  - **Capacity**: 2000 liters  
  - **Price**: $1,100  
  - Allows you to fill sprayers with Liquid Lime.  

- **Liquid Lime Silo**:  
  - **Capacity**: 155,000 liters
  - **Price**: $46,500  
  - Provides storage and refill capabilities for Liquid Lime.

- **Liquid Lime Production**:  
  - **Output Storage**: 10,000 liters of Liquid Lime
  - **Input Storage**: 20,000 liters each for Lime and Water
  - **Price**: $42,500
  - **Recipe**: make Liquid Lime with Lime and Water
  - Supports loading stored Liquid Lime into compatible trailers.

## **Provide Feedback & Report Bugs**

We value your feedback! If you encounter any bugs or have suggestions to improve the mod, please let us know:  

- Use the **[Issues tab](../../issues)** on GitHub to report bugs or share your ideas.  
- Provide as much detail as possible to help us resolve issues quickly.  

Your input is crucial for refining this mod and ensuring the best possible experience for everyone!

## **Future Plans**
- Add more placeable Liquid Lime storage options so you have more ways to store and refill around the farm.  
- Expand support for more liquid trailers and tankers where possible.

---

Thank you for supporting this mod! Together, we can make it even better. Happy farming! ??
