async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const Router = await ethers.getContractFactory("BifrostRouter01");
    const router = await Router.deploy();

    console.log("Router address:", router.address);
}
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});