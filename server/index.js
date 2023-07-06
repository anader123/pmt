const express = require("express");
const ethers = require("ethers");
const cors = require("cors");
const { hashMessageEIP191SolidityKeccak } = require("./utils/crypotUtils");
require("dotenv").config();

const {
  NFT_CONTRACT_ADDRESS,
  CHIP_ADDRESS,
  ALCHEMY_KEY,
  PRIVATE_KEY,
  SERVER_PORT,
  NETWORK_NAME,
  GAS_LIMIT,
  MAX_MINT_AMOUNT
} = process.env;

const abi = [
  "function mintWithSig(bytes, uint256, address) external",
  "function numberMinted(address) public view returns(uint256)",
];

// Provider Instance
const provider = new ethers.providers.AlchemyProvider(NETWORK_NAME, ALCHEMY_KEY);

// Wallet Instance
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Contract Instance
const nftContract = new ethers.Contract(NFT_CONTRACT_ADDRESS, abi, wallet);

const app = express();
app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.status(200).send("Server is up and running.");
});

// Endpoint sponsors minting for an address if provided with a valid signature
app.post("/vegas-chip-mint", async (req, res) => {
  try {
    const { userAddress, blockHash, blockNumber, signature } = req.body;

    const isAddress = ethers.utils.isAddress(userAddress);
    if (
      !userAddress ||
      !blockHash ||
      !blockNumber ||
      !signature ||
      !isAddress ||
      blockHash.length !== 66 ||
      signature.length !== 132
    ) {
      return res.status(400).json({
        status: "error",
        message: "Address, Block Hash, or Signature incorrectly formatted.",
      });
    }

    const numberMinted = await nftContract.numberMinted(userAddress);

    // User can't mint more than max amount
    if (numberMinted >= MAX_MINT_AMOUNT) {
      return res
        .status(400)
        .json({ status: "error", message: "Address has already minted." });
    }

    const messageHash = hashMessageEIP191SolidityKeccak(userAddress, blockHash);

    const recoveredAddress = ethers.utils.recoverAddress(
      messageHash,
      signature
    );

    if (recoveredAddress.toLowerCase() !== CHIP_ADDRESS.toLowerCase()) {
      return res
        .status(400)
        .json({ status: "error", message: "Invalid signature provided." });
    }

    const overrides = { gasLimit: GAS_LIMIT };
    const result = await nftContract.mintWithSig(
      signature,
      blockNumber,
      userAddress,
      overrides
    );

    return res.status(200).json({ txHash: result.hash });
  } catch (err) {
    console.error(err);
    res.status(500).json({ status: "error", message: "Internal server error." });
  }
});

app.listen(SERVER_PORT, () =>
  console.log(`Server running on port ${SERVER_PORT}`)
);
