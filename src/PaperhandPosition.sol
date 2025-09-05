// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CoreWriterLib, HLConversions} from "@hyper-evm-lib/src/CoreWriterLib.sol";
import {PrecompileLib} from "@hyper-evm-lib/src/PrecompileLib.sol";

contract PaperhandPosition is Ownable {
    using CoreWriterLib for *;

    uint64 public constant USDC_TOKEN_ID = 0;
    uint16 public constant PAPERHAND_TAX = 1500; // 15%
    uint16 public constant PROTOCOL_TAX = 20; // 0.2%

    uint32 public asset;
    bool public isBuy;
    uint64 public sz;
    uint64 public closePx;
    bool paperhanded;

    constructor(uint32 _asset, bool _isBuy, uint64 _sz, uint64 _limitPx, uint64 _closePx) Ownable(msg.sender) {
        asset = _asset;
        isBuy = _isBuy;
        sz = _sz;
        closePx = _closePx;
        paperhanded = false;
        CoreWriterLib.placeLimitOrder(asset, isBuy, _limitPx, sz, false, 2, 0);
        CoreWriterLib.placeLimitOrder(asset, !isBuy, closePx, sz, true, 2, 0);
    }

    function paperhand(uint64 limitPx) public onlyOwner {
        CoreWriterLib.placeLimitOrder(asset, !isBuy, limitPx, sz, true, 3, 0);
        paperhanded = true;
    }

    function withdrawBalance(address recipient, address feeRecipient) public onlyOwner {
        PrecompileLib.Position memory position = PrecompileLib.position(address(this), uint16(asset));
        require(position.szi == 0, "Position not closed");
        uint64 withdrawAmount = PrecompileLib.withdrawable(address(this));
        CoreWriterLib.transferUsdClass(withdrawAmount, false);
        uint64 withdrawAmountWei = HLConversions.perpToWei(withdrawAmount);

        uint64 taxAmountWei = (withdrawAmountWei * PROTOCOL_TAX) / 10000;
        if (paperhanded) {
            taxAmountWei += (withdrawAmountWei * PAPERHAND_TAX) / 10000;
        }

        CoreWriterLib.spotSend(recipient, USDC_TOKEN_ID, withdrawAmountWei - taxAmountWei);
        CoreWriterLib.spotSend(feeRecipient, USDC_TOKEN_ID, taxAmountWei);
    }
}
