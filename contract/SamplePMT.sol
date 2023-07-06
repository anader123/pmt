// SPDX-License-Identifier: MIT
                                                                    
pragma solidity 0.8.18;

/// @title Sample PMT
/// @notice An ERC-721 contract requires a signature to mint

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

// *********** Errors *********** //

/// @notice Address has already minted
error MaxMinted();

/// @notice Minting has concluded
error EndTimePassed();

/// @notice Blocknumber is greater than current number
error InvalidBlockNumber();

/// @notice Signature is not valid
error InvalidSignature();

/// @notice Token URI called for NonexistentToken
error URIQueryForNonexistentToken();

/// @notice Royalty called for NonexistentToken
error RoyaltyQueryForNonexistentToken();

contract SamplePMT is Ownable, ERC721A, IERC2981 {
    using ECDSA for bytes32;
    using Strings for uint256;

    // *********** Variables *********** //

    string imageURI;
    string description;

    /// @notice Address of the NFC signing chip
    address public chipAddress;

    /// @notice Maximum amount that an address can mint
    uint16 public maxMintAmount;

    /// @notice Final time to be able to mint
    uint32 public endTime;

    /// @notice Complete Contract URI
    string public contractURI;

    /// @notice Royalty Recipient Address
    address public royaltyRecipient;

    /// @notice Royalty Basis Points 
    uint16 public royaltyBPS = 5_00; // 5%

    // *********** Events *********** //

    /// @notice Event emitted for updating the contractURI
    /// @param newContractURI new contractURI
    event ContractURIUpdated(string newContractURI);

    /// @notice Event emitted for triggering a metadata refresh
    /// @param fromTokenId start tokenId
    /// @param toTokenId end tokenId
    event BatchMetadata(uint256 fromTokenId, uint256 toTokenId);

    /// @notice Event emitted for updaing the royalty info
    /// @param royaltyRecipient new recipient
    /// @param royaltyBPS new royalty basis points
    event RoyaltyInfoUpdated(address royaltyRecipient, uint16 royaltyBPS);

    // *********** Constructor *********** //

    /// @notice Construct SamplePMT with the given parameters
    /// @param contractURI_ initial contractURI
    /// @param imageURI_ image for the NFT
    /// @param description_ description for the NFT
    /// @param chipAddress_ address that is able to sign for minting
    constructor(
        string memory contractURI_,
        string memory imageURI_,
        string memory description_,
        address chipAddress_,
        uint32 endTime_,
        uint16 maxMintAmount_
    ) ERC721A("SamplePMT", "SPMT"){
        contractURI = contractURI_;
        imageURI = imageURI_;
        description = description_;
        chipAddress = chipAddress_;
        endTime = endTime_;
        maxMintAmount = maxMintAmount_;
        royaltyRecipient = msg.sender;
    }

    // *********** Functions *********** //

    /// @notice Mints an NFT to an address if provided with a signature
    /// @param signatureFromChip signature from an NFC chip
    /// @param blockNumberUsedInSig blocknumber for the signed blockhash
    /// @param mintTo address to mint the NFT to
    function mintWithSig(
        bytes calldata signatureFromChip, 
        uint256 blockNumberUsedInSig, 
        address mintTo
    ) external {

        if(_numberMinted(mintTo) >= maxMintAmount) {
            revert MaxMinted();
        }

        if(block.timestamp > endTime) {
            revert EndTimePassed();
        }

        // The blockNumberUsedInSig must be in a previous block because the blockhash of the current
        // block does not exist yet.
        if (block.number <= blockNumberUsedInSig) {
            revert InvalidBlockNumber();
        }

        bytes32 blockHash = blockhash(blockNumberUsedInSig);
        bytes32 signedHash = keccak256(abi.encodePacked(mintTo, blockHash)).toEthSignedMessageHash();
        address signerAddress = signedHash.recover(signatureFromChip);

        if(signerAddress != chipAddress) {
            revert InvalidSignature();
        }

        _mint(mintTo, 1);
    }

    /// @notice Returns the base64-encoded JSON metadata for a given token
    /// @param tokenId the id of the token
    /// @return metadata information about the token
    function tokenURI(
        uint256 tokenId
        ) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        bytes memory dataURI = abi.encodePacked(
            '{',
                '"name": "Sample PMT ', tokenId.toString(), '",',
                '"description": "', description, '",',
                '"image": "', imageURI, '"',
            '}'
        );
        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(dataURI)
        ));
    }

    /// @notice Gets how many NFTs an address has been minted
    /// @param minter address that has gotten minted an NFT
    /// @return numberMinted amount minted by the address
    function numberMinted(
        address minter
    ) public view returns (uint256) {
        return _numberMinted(minter);
    }

    /// @notice Updates the metadata for the NFT
    /// @param newImageURI image for the NFT
    /// @param newDescription description for the NFT
    function updateMetadata(
        string memory newImageURI,
        string memory newDescription
    ) public onlyOwner {
        imageURI = newImageURI;
        description = newDescription;

        emit BatchMetadata(0, _totalMinted()-1);
    }

    /// @notice Updates the URI for the contract
    /// @param newContractURI the  contractURI
    function updateContractURI(
        string calldata newContractURI
    ) external onlyOwner {
        contractURI = newContractURI;

        emit ContractURIUpdated(newContractURI);
    }

    /// @notice Returns royalty amount for a given sale price
    /// @param tokenId specific token to get royalties for
    /// @param salePrice amount the token is selling for
    /// @return receiver royalty payout address
    /// @return royaltyAmount amount to send
    function royaltyInfo(
        uint256 tokenId, 
        uint256 salePrice
    ) external view
    returns (address receiver, uint256 royaltyAmount) {
        if(!_exists(tokenId)) revert RoyaltyQueryForNonexistentToken();
        return (
            royaltyRecipient,
            (salePrice * royaltyBPS) / 10_000
        );
    }

    /// @notice Updates the royalties settings 
    /// @param newRoyaltyRecipient new address to recieve royalties
    /// @param newRoyaltyBPS new basis points amount
    function updateRoyaltyInfo(
        address newRoyaltyRecipient, 
        uint16 newRoyaltyBPS
    ) external onlyOwner {
        royaltyRecipient = newRoyaltyRecipient;
        royaltyBPS = newRoyaltyBPS;

        emit RoyaltyInfoUpdated(newRoyaltyRecipient, newRoyaltyBPS);
    }

    /// @notice ERC165 supports interface
    /// @param interfaceId interface id to check if supported
    function supportsInterface(bytes4 interfaceId) public view override(ERC721A, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}