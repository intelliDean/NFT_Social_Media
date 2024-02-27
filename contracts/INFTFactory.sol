// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


interface INFTFactory {

    function createNFT(address owner, string memory tokenName, string memory tokenSymbol) external returns (address);

    function mintNFT(uint256 contractIndex, address _to, string memory _uri) external;

    function getNFT(uint256 contractIndex, uint256 _tokenId) external view returns (string memory);
}