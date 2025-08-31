// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {Jerota} from "../../src/token/Jerota.sol";

contract JerotaTest is Test {
    Jerota public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.prank(owner);
        token = new Jerota(owner);
    }

    function test_InitialState() public view {
        assertEq(token.name(), "Jerota Test");
        assertEq(token.symbol(), "JRTT");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
    }

    function test_Mint() public {
        uint256 amount = 1000 * 10 ** 18;

        vm.prank(owner);
        token.mint(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_MintOnlyOwner() public {
        uint256 amount = 1000 * 10 ** 18;

        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, amount);
    }

    function test_Burn() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 burnAmount = 300 * 10 ** 18;

        vm.prank(owner);
        token.mint(user1, amount);

        vm.prank(user1);
        token.burn(burnAmount);

        assertEq(token.balanceOf(user1), amount - burnAmount);
        assertEq(token.totalSupply(), amount - burnAmount);
    }

    function test_BurnFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 burnAmount = 300 * 10 ** 18;

        vm.prank(owner);
        token.mint(user1, amount);

        vm.prank(user1);
        token.approve(user2, burnAmount);

        vm.prank(user2);
        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), amount - burnAmount);
        assertEq(token.totalSupply(), amount - burnAmount);
    }

    function test_Transfer() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 transferAmount = 300 * 10 ** 18;

        vm.prank(owner);
        token.mint(user1, amount);

        vm.prank(user1);
        token.transfer(user2, transferAmount);

        assertEq(token.balanceOf(user1), amount - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
    }

    function test_Approve() public {
        uint256 amount = 1000 * 10 ** 18;

        vm.prank(user1);
        token.approve(user2, amount);

        assertEq(token.allowance(user1, user2), amount);
    }

    function test_TransferFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 transferAmount = 300 * 10 ** 18;

        vm.prank(owner);
        token.mint(user1, amount);

        vm.prank(user1);
        token.approve(user2, transferAmount);

        vm.prank(user2);
        token.transferFrom(user1, user2, transferAmount);

        assertEq(token.balanceOf(user1), amount - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.allowance(user1, user2), 0);
    }

    function test_Permit() public {
        uint256 privateKey = 0xBEEF;
        address signer = vm.addr(privateKey);
        uint256 amount = 1000 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        signer,
                        user1,
                        amount,
                        token.nonces(signer),
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, permitHash);

        token.permit(signer, user1, amount, deadline, v, r, s);

        assertEq(token.allowance(signer, user1), amount);
    }
}
