// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTMarketplace is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    struct SaleItem {
        uint256 id;
        address seller;
        uint256 price;
        uint256 royaltyPercentage; // New feature: Royalty percentage for the seller
        bool sold;
    }

    mapping(uint256 => SaleItem) private _saleItems;
    mapping(address => mapping(uint256 => bool)) private _itemIsListed;

    event ItemListed(uint256 indexed itemId, address indexed seller, uint256 price, uint256 royaltyPercentage); // Updated event
    event ItemSold(uint256 indexed itemId, address indexed buyer, uint256 price);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function listNFT(uint256 price, uint256 royaltyPercentage) external {
        uint256 newItemId = _itemIds.current();
        _saleItems[newItemId] = SaleItem(newItemId, msg.sender, price, royaltyPercentage, false);
        _itemIsListed[msg.sender][newItemId] = true;
        _safeMint(msg.sender, newItemId);
        _itemIds.increment();
        emit ItemListed(newItemId, msg.sender, price, royaltyPercentage);
    }

    function buyNFT(uint256 itemId) external payable {
        SaleItem storage item = _saleItems[itemId];
        require(item.id != 0, "Item not found");
        require(!item.sold, "Item already sold");
        require(msg.value >= item.price, "Insufficient payment");

        item.sold = true;
        _itemsSold.increment();
        _transfer(item.seller, msg.sender, itemId);

        // Calculate and transfer royalties to the seller
        uint256 royaltyAmount = (msg.value * item.royaltyPercentage) / 100;
        payable(item.seller).transfer(royaltyAmount);

        // Transfer remaining amount to the original creator
        uint256 remainingAmount = msg.value - royaltyAmount;
        payable(ownerOf(itemId)).transfer(remainingAmount);

        emit ItemSold(itemId, msg.sender, item.price);
    }

    function getItem(uint256 itemId) external view returns (uint256 id, address seller, uint256 price, uint256 royaltyPercentage, bool sold) {
        SaleItem storage item = _saleItems[itemId];
        return (item.id, item.seller, item.price, item.royaltyPercentage, item.sold);
    }

    function getTotalItems() external view returns (uint256) {
        return _itemIds.current();
    }

    function getTotalItemsSold() external view returns (uint256) {
        return _itemsSold.current();
    }

    function isItemListed(address seller, uint256 itemId) external view returns (bool) {
        return _itemIsListed[seller][itemId];
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}