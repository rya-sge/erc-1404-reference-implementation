// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {WhitelistRuleEngine} from "../src/engine/WhitelistRuleEngine.sol";
import {RestrictedToken} from "../src/engine/RestrictedToken.sol";
import {IERC1404Restriction} from "../src/engine/IERC1404Restriction.sol";

contract WhitelistRuleEngineTest is Test {
    WhitelistRuleEngine engine;
    RestrictedToken token;

    address owner = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant SUPPLY = 1_000_000e18;

    function setUp() public {
        engine = new WhitelistRuleEngine();
        token = new RestrictedToken("Restricted", "RST", SUPPLY, engine);
        // Deployer (owner) holds the initial supply; whitelist it so it can move tokens.
        engine.setWhitelisted(owner, true);
    }

    // -------------------------------------------------------------------------
    // detectTransferRestriction — mirrors the table in EXAMPLE_ERC_1404.md
    // -------------------------------------------------------------------------

    function test_noRestrictionWhenBothWhitelisted() public {
        engine.setWhitelisted(alice, true);
        engine.setWhitelisted(bob, true);
        assertEq(engine.detectTransferRestriction(alice, bob, 1e18), engine.TRANSFER_OK());
    }

    function test_senderNotWhitelisted() public {
        engine.setWhitelisted(bob, true);
        assertEq(engine.detectTransferRestriction(alice, bob, 1e18), engine.SENDER_NOT_WHITELISTED());
    }

    function test_recipientNotWhitelisted() public {
        engine.setWhitelisted(alice, true);
        assertEq(engine.detectTransferRestriction(alice, bob, 1e18), engine.RECIPIENT_NOT_WHITELISTED());
    }

    function test_detectChecksFromBeforeTo() public view {
        // neither whitelisted → sender check fires first
        assertEq(engine.detectTransferRestriction(alice, bob, 1e18), engine.SENDER_NOT_WHITELISTED());
    }

    // -------------------------------------------------------------------------
    // messageForTransferRestriction — deterministic, non-empty messages
    // -------------------------------------------------------------------------

    function test_messageCode0() public view {
        assertEq(engine.messageForTransferRestriction(0), engine.MESSAGE_TRANSFER_OK());
    }

    function test_messageCode1() public view {
        assertEq(engine.messageForTransferRestriction(1), engine.MESSAGE_SENDER_NOT_WHITELISTED());
    }

    function test_messageCode2() public view {
        assertEq(engine.messageForTransferRestriction(2), engine.MESSAGE_RECIPIENT_NOT_WHITELISTED());
    }

    function test_messageUnknownCode() public view {
        assertEq(engine.messageForTransferRestriction(99), engine.MESSAGE_UNKNOWN_RESTRICTION());
    }

    // -------------------------------------------------------------------------
    // Whitelist management
    // -------------------------------------------------------------------------

    function test_ownerCanAddToWhitelist() public {
        engine.setWhitelisted(alice, true);
        assertTrue(engine.whitelist(alice));
    }

    function test_ownerCanRemoveFromWhitelist() public {
        engine.setWhitelisted(alice, true);
        engine.setWhitelisted(alice, false);
        assertFalse(engine.whitelist(alice));
    }

    function test_nonOwnerCannotSetWhitelist() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        engine.setWhitelisted(bob, true);
    }

    function test_setWhitelistedZeroAddressReverts() public {
        vm.expectRevert(WhitelistRuleEngine.AddressZeroNotAllowed.selector);
        engine.setWhitelisted(address(0), true);
    }

    // -------------------------------------------------------------------------
    // ERC-165
    // -------------------------------------------------------------------------

    function test_supportsERC1404Interface() public view {
        assertTrue(engine.supportsInterface(0xab84a5c8));
    }

    function test_supportsERC165Interface() public view {
        assertTrue(engine.supportsInterface(0x01ffc9a7));
    }

    function test_doesNotSupportRandomInterface() public view {
        assertFalse(engine.supportsInterface(0xdeadbeef));
    }

    // -------------------------------------------------------------------------
    // Token wired to engine — reverts exactly when the engine returns non-zero
    // -------------------------------------------------------------------------

    function test_constructorRejectsZeroEngine() public {
        vm.expectRevert(RestrictedToken.EngineAddressZero.selector);
        new RestrictedToken("Bad", "BAD", 0, IERC1404Restriction(address(0)));
    }

    function test_transferSucceedsWhenUnrestricted() public {
        engine.setWhitelisted(alice, true);
        assertTrue(token.transfer(alice, 100e18));

        engine.setWhitelisted(bob, true);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 50e18));
        assertEq(token.balanceOf(bob), 50e18);
    }

    function test_transferRevertsWhenSenderNotWhitelisted() public {
        engine.setWhitelisted(bob, true);
        address stranger = makeAddr("stranger");
        deal(address(token), stranger, 10e18);

        // Evaluate the engine view calls before prank so they don't consume it.
        bytes memory expected = abi.encodeWithSelector(
            RestrictedToken.TransferRestricted.selector,
            engine.SENDER_NOT_WHITELISTED(),
            engine.MESSAGE_SENDER_NOT_WHITELISTED()
        );
        vm.expectRevert(expected);
        vm.prank(stranger);
        token.transfer(bob, 1e18);
    }

    function test_transferRevertsWhenRecipientNotWhitelisted() public {
        // owner is whitelisted in setUp; bob is not
        vm.expectRevert(
            abi.encodeWithSelector(
                RestrictedToken.TransferRestricted.selector,
                engine.RECIPIENT_NOT_WHITELISTED(),
                engine.MESSAGE_RECIPIENT_NOT_WHITELISTED()
            )
        );
        token.transfer(bob, 1e18);
    }

    function test_transferFromSucceedsWhenUnrestricted() public {
        engine.setWhitelisted(alice, true);
        engine.setWhitelisted(bob, true);

        assertTrue(token.transfer(alice, 100e18));
        vm.prank(alice);
        token.approve(bob, 50e18);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, 50e18));
        assertEq(token.balanceOf(bob), 50e18);
    }

    function test_transferFromRevertsWhenRecipientNotWhitelisted() public {
        engine.setWhitelisted(alice, true);
        assertTrue(token.transfer(alice, 100e18));

        vm.prank(alice);
        token.approve(owner, 100e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                RestrictedToken.TransferRestricted.selector,
                engine.RECIPIENT_NOT_WHITELISTED(),
                engine.MESSAGE_RECIPIENT_NOT_WHITELISTED()
            )
        );
        token.transferFrom(alice, bob, 1e18);
    }

    // -------------------------------------------------------------------------
    // Mint / burn — zero-address legs bypass the engine
    // -------------------------------------------------------------------------

    function test_mintBypassesWhitelist() public {
        // alice is not whitelisted, yet issuance to her succeeds
        token.mint(alice, 500e18);
        assertEq(token.balanceOf(alice), 500e18);
    }

    function test_burnBypassesWhitelist() public {
        deal(address(token), alice, 10e18);
        token.burn(alice, 10e18);
        assertEq(token.balanceOf(alice), 0);
    }

    // -------------------------------------------------------------------------
    // One engine, many tokens — shared rule set
    // -------------------------------------------------------------------------

    function test_engineSharedAcrossTokens() public {
        RestrictedToken token2 = new RestrictedToken("Restricted2", "RS2", SUPPLY, engine);

        // Whitelisting alice in the single engine unblocks her on both tokens.
        engine.setWhitelisted(alice, true);
        assertTrue(token.transfer(alice, 1e18));
        assertTrue(token2.transfer(alice, 1e18));
        assertEq(token.balanceOf(alice), 1e18);
        assertEq(token2.balanceOf(alice), 1e18);
    }
}
