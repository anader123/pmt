import { ethers } from "ethers";
import axios from "axios";
import { getSignatureFromScan } from "pbt-chip-client/kong";
import { useState, useEffect } from "react";
import { useBlockData } from "~/hooks/useBlockData";
import {
  apiEndpoint, //URL for the API
  chipPublicKey, // Pub Key for the chip, can be obtained here: https://bulk.vrfy.ch/
  explorerURL, // Block explorer URL 
  chainId, // Network the NFT is on
} from "~/constants/pmt";

export const Vegas = () => {
  const [input, setInput] = useState<string>("");
  const [txHash, setTxHash] = useState<string>("");
  const [error, setError] = useState<string>("");
  const [userAddress, setUserAddress] = useState<string>("0x");
  const [blockData, setBlockData] = useState<{
    blockHash: string;
    blockNumber: number;
  } | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      const data = await useBlockData(chainId);
      setBlockData(data);
    };

    fetchData();
  }, []);

  const handleInputChange = async (event: any) => {
    const value = event.target.value;
    setUserAddress(value);

  };

  const mintNFT = async () => {
    setError("");
    const { blockHash = "", blockNumber } = blockData ?? {};

    if (!input || !ethers.utils.isAddress(userAddress)) {
      setError("Invalid address");
      setInput("");
      return;
    }

    if (!blockData) {
      setError("Could not retrieve block data");
      return;
    }

    try {
      const signature = await getSignatureFromScan({
        chipPublicKey,
        address: userAddress,
        hash: blockHash,
      });

      const postData = {
        userAddress,
        blockHash,
        blockNumber,
        signature,
      };

      if (!signature) {
        setError("Failed to sign");
        return;
      }

      const res = await axios.post(apiEndpoint, postData);
      if (res.status === 200) setTxHash(res.data.txHash);
    } catch (error: any) {
      if (error.response.data.message) {
        setError(error.response.data.message);
      } else setError(error.message);
    }
  };

  return (
    <div>
      <div>Sample PMT</div>
      <img src={yourMedia} alt="media" />
      <div>
        <input
          type="text"
          value={input}
          onChange={handleInputChange}
          placeholder="Enter Address"
        />

        {error.length > 0 ? <div>{error}</div> : null}
        {txHash.length > 0 ? (
          <div>
            <a target="blank" href={`${explorerURL}/${txHash}`}>
              Transaction Submitted
            </a>
          </div>
        ) : null}
        <button type="button" onClick={() => mintNFT()}>
          Mint
        </button>
      </div>
    </div>
  );
};
