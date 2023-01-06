const { ethers } = require("hardhat");

async function mintAndList() {
    const NFT_Marketplace = await ethers.getContract("NFT_marketplace")
    const BasicNft = await ethers.getContract("BasicNft")
    const mint = await BasicNft.mintNft()
    const receipt = await mint.wait(1)
    const tokenID = receipt.events[0].args.tokenID

    const approval = await BasicNft.approve(NFT_Marketplace.address, tokenID)
    await approval.wait(1)
    const tx = await NFT_Marketplace.list_NFT2(BasicNft.address, tokenID, 0.00001)
    await tx.wait(1)
}

mintAndList().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });