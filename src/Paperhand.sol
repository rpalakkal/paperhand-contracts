// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {PaperhandPosition} from "./PaperhandPosition.sol";

contract Paperhand is ERC721 {
    mapping(address => uint256) public nonces;
    mapping(uint256 => address) public positions;
    uint256 currentTokenId;
    address private feeRecipient;

    constructor(address _feeRecipient) ERC721("Paperhand", "PH") {
        feeRecipient = _feeRecipient;
    }

    function ape(uint32 asset, bool isBuy, uint64 sz, uint64 limitPx, uint64 closePx) public {
        /// forge-lint: disable-next-line(asm-keccak256)
        bytes32 salt = keccak256(abi.encode(msg.sender, nonces[msg.sender]++));
        PaperhandPosition position = new PaperhandPosition{salt: salt}(asset, isBuy, sz, limitPx, closePx);
        uint256 newTokenId = currentTokenId++;
        positions[newTokenId] = address(position);
        _safeMint(msg.sender, newTokenId);
    }

    function paperhand(uint256 tokenId, uint64 limitPx) public {
        require(ownerOf(tokenId) == msg.sender, "Not position owner");
        PaperhandPosition(positions[tokenId]).paperhand(limitPx);
    }

    function withdrawBalance(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Not position owner");
        PaperhandPosition(positions[tokenId]).withdrawBalance(msg.sender, address(feeRecipient));
        _burn(tokenId);
    }

    function getPositionAddress(uint32 asset, bool isBuy, uint64 sz, uint64 limitPx, uint64 closePx, address user)
        public
        view
        returns (address)
    {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            keccak256(abi.encode(user, nonces[user])),
                            keccak256(
                                abi.encodePacked(
                                    type(PaperhandPosition).creationCode, abi.encode(asset, isBuy, sz, limitPx, closePx)
                                )
                            )
                        )
                    )
                )
            )
        );
    }
}
