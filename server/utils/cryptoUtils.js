const ethers = require("ethers");

// EIP-191 Hashing Function
const hashMessageEIP191SolidityKeccak = (address, hash) => {
  const messagePrefix = "\x19Ethereum Signed Message:\n32";
  const message = address
    ? ethers.utils.solidityKeccak256(["address", "bytes32"], [address, hash])
    : ethers.utils.solidityKeccak256(["bytes32"], [hash]);
  return ethers.utils.solidityKeccak256(
    ["string", "bytes32"],
    [messagePrefix, ethers.utils.arrayify(message)]
  );
};

module.exports = {
  hashMessageEIP191SolidityKeccak,
};
