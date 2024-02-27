import {ethers} from "hardhat";

async function main() {

    const NFTFactory = await ethers.deployContract("NFTFactory");

    await NFTFactory.waitForDeployment();


    const NFTSocialMedia = await ethers.deployContract("NFTSocialMedia");

    await NFTSocialMedia.waitForDeployment();

    console.log(
        `NFTFactory deployed to ${NFTFactory.target}`
    );

    console.log(
        `NFTSocialMedia deployed to ${NFTSocialMedia.target}`
    );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
