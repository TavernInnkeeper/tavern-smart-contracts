

import { ethers } from "hardhat";
import { dateString } from "../../helper/utils";
import { Brewery_address, ClassManager_address } from "../NFT_ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    const ClassManager = await ethers.getContractAt("ClassManager", ClassManager_address);
    const Brewery = await ethers.getContractAt("Brewery", Brewery_address);

    /// GENEARL BREWERY INFO
    console.log("==== GENERAL INFO ====")
    console.log("Contract:", Brewery.address);
    console.log("Total Supply", (await Brewery.totalSupply()).toString());
    console.log("Fermentation Period: ", Number(await Brewery.fermentationPeriod()) / 86400, "days");
    console.log("Experience Per Second: ", (await Brewery.experiencePerSecond()).toString());
    
    const tiers = await Brewery.getTiers();
    const yields = await Brewery.getYields();
    for (let i = 0; i < tiers.length; ++i) {
        console.log(`Tier ${i+1}:`, `XP ${tiers[i]}`, `Yield ${ethers.utils.formatUnits(yields[i], 18)}`)
    }

    /// Your Account
    const account = deployer.address;
    console.log("==== BREWERS STATS ====")
    console.log("Class:", (await ClassManager.getClass(account)).toString());
    console.log("Reputation:", (await ClassManager.getReputation(account)).toString());
    console.log("Brewery Count:", (await Brewery.balanceOf(account)).toString());
    console.log("Pending Rewards:", (await Brewery.getTotalPendingMead(account)).toString());
    console.log("Total Rewards:");

    /// SPECIFIC BREWERY INFO
    const id = "1";
    const stats = await Brewery.breweryStats(id);

    console.log("\n==== Token", id, "====")
    console.log("\tName:", stats.name);
    console.log("\tOwner:", await Brewery.ownerOf(id));
    console.log("\tURI:", await Brewery.tokenURI(id));
    console.log("\tType:", stats.type_.toString());
    console.log("\tCurrent Tier:", stats.tier.toString());
    const xp = (await Brewery.getPendingXp(id)).add(stats.xp);
    console.log("\tCurrent Xp:", xp.toString());

    let datetime = dateString(Number(stats.lastTimeClaimed) * 1000);

    console.log("\tProduction Rate:", ethers.utils.formatUnits((await Brewery.getProductionRatePerSecond(id)).mul(86400), 18), "MEAD/day");
    console.log("\tPending Rewards:", ethers.utils.formatUnits(await Brewery.pendingMead(id), 18), "MEAD")
    console.log("\tReward Period:", (await Brewery.getRewardPeriod(stats.lastTimeClaimed)).toString(), "s");
    console.log("\tLast Claim:", datetime);
    console.log("\tTotal Claimed:", ethers.utils.formatUnits(stats.totalYield, 18));
    console.log("\tProduction Rate Multiplier:", ethers.utils.formatUnits(stats.productionRatePerSecondMultiplier, 2) + "%");
    console.log("\tFermentation Period Multiplier:", ethers.utils.formatUnits(stats.fermentationPeriodMultiplier, 2) + "%");
    console.log("\tExperience Multiplier:", ethers.utils.formatUnits(stats.experienceMultiplier, 2) + "%");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
