async function main() {
    const [deployer] = await ethers.getSigners();


    // Settings
    //  0x10ED43C718714eb63d5aA57B78B54704E256024E  (PcS V2 Mainnet)
    //  0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3  (PcS V2 Testnet)
    let pancakeRouter          = '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3';
    let listingFee             = '1e16';               // The flat fee in BNB (25e16 = 0.25 BNB)
    let launchingFee           = 100;                  // The percentage of fees returned to the router owner for successful sales (100 = 1%)
    let minLiquidityPercentage = 5000;                 // The minimum liquidity percentage (5000 = 50%)
    let minCapRatio            = 5000;                 // The ratio of soft cap to hard cap, i.e. 50% means soft cap must be at least 50% of the hard cap
    let minUnlockTimeSeconds   = 1;//30 days;          // The minimum amount of time before liquidity can be unlocked
    let minSaleTime            = 1;// hours;           // The minimum amount of time a sale has to run for
    let maxSaleTime            = 0; 

    console.log("Deploying contracts with the account:", deployer.address);

    const Router = await ethers.getContractFactory("BifrostRouter01");
    const router = await Router.deploy(
        pancakeRouter,
        listingFee,
        launchingFee,
        minLiquidityPercentage,
        minCapRatio,
        minUnlockTimeSeconds,
        minSaleTime,
        maxSaleTime
    );

    console.log("Router address:", router.address);
}
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});