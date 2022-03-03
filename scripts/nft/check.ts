

import { ethers } from "hardhat";
import { Brewery_address } from "../NFT_ADDRESSES";

async function main() {
    // The signers
    const [deployer] = await ethers.getSigners();

    const Brewery = await ethers.getContractAt("Brewery", Brewery_address)

    /// GENEARL BREWERY INFO
    console.log("==== GENERAL INFO ====")
    console.log("Contract:", Brewery.address);
    console.log("Total Supply", (await Brewery.totalSupply()).toString());
    console.log("Base Mead Per Second: ", ethers.utils.formatUnits(await Brewery.baseProductionRatePerSecond(), 18));
    console.log("Fermentation Period: ", Number(await Brewery.baseFermentationPeriod()) / 86400, "days");
    console.log("Experience Per Second: ", (await Brewery.baseExperiencePerSecond()).toString());

    /// SPECIFIC BREWERY INFO
    const id = "1";
    const stats = await Brewery.breweryStats(id);

    console.log("\n\t==== Token", id, "====")
    console.log("\tName:", stats.name);
    console.log("\tType:", stats.type_.toString());
    console.log("\tCurrent Tier:", stats.tier.toString());
    console.log("\tPending Tier:", (await Brewery.getTier(id)).toString());
    const xp = (await Brewery.getPendingXp(id)).add(stats.xp);
    console.log("\tCurrent Xp:", xp.toString());

    var currentdate = new Date(Number(stats.lastTimeClaimed) * 1000); 
    var datetime =  currentdate.getDate() + "/"
                    + (currentdate.getMonth()+1)  + "/" 
                    + currentdate.getFullYear() + " @ "  
                    + currentdate.getHours() + ":"  
                    + currentdate.getMinutes() + ":" 
                    + currentdate.getSeconds();

    console.log("\tProduction Rate:", ethers.utils.formatUnits(await Brewery.yields(stats.tier), 18), "MEAD/day");
    console.log("\tPending Rewards:", ethers.utils.formatUnits(await Brewery.pendingMead(id), 18), "MEAD")
    console.log("\tLast Claim:", datetime);
    console.log("\tTotal Claimed:", ethers.utils.formatUnits(stats.totalYield, 18));
    console.log("\tProduction Rate Multiplier:", ethers.utils.formatUnits(stats.productionRatePerSecondMultiplier, 10));
    console.log("\tFermentation Period Multiplier:", ethers.utils.formatUnits(stats.fermentationPeriodMultiplier, 10));
    console.log("\tFermentation Period Multiplier:", ethers.utils.formatUnits(stats.experienceMultiplier, 10));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});
