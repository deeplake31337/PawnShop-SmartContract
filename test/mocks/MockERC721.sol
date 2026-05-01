// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockERC721
 * @dev Phiên bản giả lập siêu nhỏ gọn của ERC721 (NFT) để chạy test
 */
contract MockERC721 {
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => address) public getApproved;

    function mint(address to, uint256 tokenId) external {
        ownerOf[tokenId] = to;
    }

    function approve(address spender, uint256 tokenId) external {
        getApproved[tokenId] = spender;
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        // Trong môi trường test đơn giản ta skip các bước check Owner/Approve phức tạp
        ownerOf[tokenId] = to;
    }
}