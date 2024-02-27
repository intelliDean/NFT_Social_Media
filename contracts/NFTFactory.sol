// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/socialMedia/INFTs.sol";
import "contracts/socialMedia/NFTs.sol";

contract NFTFactory {

    address[] public nfts;
    uint256 public noOfNFTContracts;
    mapping(address => address) public eachNFTContract;

    function createNFT(address owner, string memory tokenName, string memory tokenSymbol) external returns (address) {

        address _nfts = address(new NFTs(owner, tokenName, tokenSymbol));

        eachNFTContract[owner] = address(_nfts);
        nfts.push(address(_nfts));
        noOfNFTContracts = noOfNFTContracts + 1;

        return _nfts;
    }

    function mintNFT(address _to, string memory _uri) external returns (bool) {
        INFTs(eachNFTContract[msg.sender]).safeMint(_to, _uri);
        return true;
    }

    function getNFT(uint256 _tokenId) external view returns (string memory) {
        return INFTs(eachNFTContract[msg.sender]).tokenURI(_tokenId);
    }

}