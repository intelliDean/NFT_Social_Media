// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


interface INFTContract {

    function safeMint(address to, string memory uri) external;

   function tokenURI(uint256 tokenId) external view /*override(ERC721, ERC721URIStorage)*/ returns (string memory);

}