// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC1404Restriction} from "./IERC1404Restriction.sol";

/// @title WhitelistRuleEngine — standalone ERC-1404 compliance engine.
///
/// @notice A token-agnostic rule engine enforcing a sender/recipient whitelist.
/// It implements only the two ERC-1404 restriction functions and is *not* a
/// token: it never moves or holds balances. One or more tokens can point at the
/// same engine to share a single, independently-auditable rule set.
///
/// Restriction codes:
///   0  No restriction
///   1  Sender not whitelisted
///   2  Recipient not whitelisted
/// Restriction codes 1 and 2 are not defined by ERC-1404; they are issuer-defined.
contract WhitelistRuleEngine is ERC165, Ownable, IERC1404Restriction {
    uint8 public constant TRANSFER_OK = 0;
    uint8 public constant SENDER_NOT_WHITELISTED = 1;
    uint8 public constant RECIPIENT_NOT_WHITELISTED = 2;

    string public constant MESSAGE_TRANSFER_OK = "No restriction";
    string public constant MESSAGE_SENDER_NOT_WHITELISTED = "Sender not whitelisted";
    string public constant MESSAGE_RECIPIENT_NOT_WHITELISTED = "Recipient not whitelisted";
    string public constant MESSAGE_UNKNOWN_RESTRICTION = "Unknown restriction code";

    // ERC-165 interface ID for ERC-1404: bytes4(keccak256("detectTransferRestriction(address,address,uint256)"))
    //   XOR bytes4(keccak256("messageForTransferRestriction(uint8)"))
    bytes4 private constant _INTERFACE_ID_ERC1404 = 0xab84a5c8;

    mapping(address => bool) public whitelist;

    error AddressZeroNotAllowed();

    event WhitelistUpdated(address indexed account, bool status);

    constructor() Ownable(msg.sender) {}

    // -------------------------------------------------------------------------
    // Whitelist management
    // -------------------------------------------------------------------------

    /// @notice Add or remove `account` from the transfer whitelist.
    function setWhitelisted(address account, bool status) external onlyOwner {
        if (account == address(0)) revert AddressZeroNotAllowed();
        whitelist[account] = status;
        emit WhitelistUpdated(account, status);
    }

    // -------------------------------------------------------------------------
    // ERC-1404
    // -------------------------------------------------------------------------

    /// @notice Returns a restriction code for the proposed transfer, or 0 if unrestricted.
    /// @dev `value` is unused in this policy; override to add amount-based restrictions.
    ///      The sender is checked before the recipient so a single call distinguishes the cases.
    function detectTransferRestriction(
        address from,
        address to,
        uint256 /*value*/
    )
        public
        view
        override
        returns (uint8)
    {
        if (!whitelist[from]) return SENDER_NOT_WHITELISTED;
        if (!whitelist[to]) return RECIPIENT_NOT_WHITELISTED;
        return TRANSFER_OK;
    }

    /// @notice Returns the human-readable message for a restriction code.
    function messageForTransferRestriction(uint8 restrictionCode) public pure override returns (string memory) {
        if (restrictionCode == TRANSFER_OK) return MESSAGE_TRANSFER_OK;
        if (restrictionCode == SENDER_NOT_WHITELISTED) return MESSAGE_SENDER_NOT_WHITELISTED;
        if (restrictionCode == RECIPIENT_NOT_WHITELISTED) return MESSAGE_RECIPIENT_NOT_WHITELISTED;
        return MESSAGE_UNKNOWN_RESTRICTION;
    }

    // -------------------------------------------------------------------------
    // ERC-165
    // -------------------------------------------------------------------------

    /// @dev Advertising the ERC-1404 interface id lets tokens discover the engine on-chain.
    ///      Interface support alone is not evidence the contract is a token — by design it is not.
    function supportsInterface(bytes4 interfaceId) public view override(ERC165) returns (bool) {
        return interfaceId == _INTERFACE_ID_ERC1404 || super.supportsInterface(interfaceId);
    }
}
