import { ethers, network } from "hardhat";

async function main() {
  // Get signers - first address will be lender, second will be borrower
  const [lender, borrower] = await ethers.getSigners();
  console.log("Lender address:", lender.address);
  console.log("Borrower address:", borrower.address);

  // Deploy MyNFT
  const MyNFT = await ethers.getContractFactory("MyNFT");
  const myNFT = await MyNFT.deploy();
  await myNFT.deployed();
  console.log("MyNFT deployed to:", myNFT.address);

  // Deploy RentToOwn
  const RentToOwn = await ethers.getContractFactory("RentToOwn");
  const rentToOwn = await RentToOwn.deploy();
  await rentToOwn.deployed();
  console.log("RentToOwn deployed to:", rentToOwn.address);
  
  // Mint NFT to lender with a token URI
  const tokenURI = "https://example.com/metadata/1"; // Replace with actual metadata URI
  await myNFT.connect(lender).safeMint(lender.address, tokenURI);
  const tokenId = Number(await myNFT.getCurrentTokenId()) - 1; // Get the last minted token ID
  console.log("NFT minted to lender at:", lender.address, "with tokenId:", tokenId.toString());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});