// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const ethers = hre.ethers;

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    await hre.run('compile');
    const [owner, addr1, addr2] = await ethers.getSigners();
    console.log("Owner: " + owner.address);

    // Deploy RAINBOW
    const RAINBOW = await ethers.getContractFactory("RainbowToken");
    const rainbow = await RAINBOW.deploy();
    rainbow.connect(owner).transfer(addr1.address, 1e13);
    console.log(owner.address + " RAINBOW balance: " + await rainbow.balanceOf(owner.address));
    console.log(addr1.address + " RAINBOW balance: " + await rainbow.balanceOf(addr1.address));
    console.log(addr2.address + " RAINBOW balance: " + await rainbow.balanceOf(addr2.address));
    rainbow.connect(addr1).transfer(addr2.address, 1e13);
    console.log(owner.address + " RAINBOW balance: " + await rainbow.balanceOf(owner.address));
    console.log(addr1.address + " RAINBOW balance: " + await rainbow.balanceOf(addr1.address));
    console.log(addr2.address + " RAINBOW balance: " + await rainbow.balanceOf(addr2.address));
    await rainbow.deployed();
    console.log("RAINBOW deployed to:", rainbow.address);

    // Deploy Launcher
    const BifrostLauncher = await ethers.getContractFactory("BifrostLauncher");
    const launcher = await BifrostLauncher.deploy(owner.address, true, rainbow.address, '0x0000000000000000000000000000000000000000', 0);
    await launcher.deployed();
    console.log("BifrostLauncher deployed to:", launcher.address);

    // Transfer

    //launcher.launch();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
