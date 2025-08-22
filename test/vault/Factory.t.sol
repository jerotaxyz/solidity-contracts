// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Import contracts to be tested and their interfaces/libraries
import {Factory} from "../../src/vault/Factory.sol";
import {Vault} from "../../src/vault/Vault.sol";
import {IVault} from "../../src/vault/interfaces/IVault.sol";
import {IFactory} from "../../src/vault/interfaces/IFactory.sol";
import {Errors} from "../../src/vault/libraries/Errors.sol";

// --- Mock Contracts ---

contract MockERC20 {
    function mint(address, uint256) public {}
    function approve(address, uint256) public {}
    function transferFrom(address, address, uint256) public {}
}

// --- Test Contract ---

contract FactoryTest is Test {
    // Contracts
    Factory internal factory;
    Vault internal vaultImplementation;
    MockERC20 internal mockToken;
    MockERC20 internal anotherMockToken;

    // Actors
    address internal owner = makeAddr("owner");
    address internal user1 = makeAddr("user1");
    address internal user2 = makeAddr("user2");
    address internal initialDistributor = makeAddr("initialDistributor");
    address internal newDistributor = makeAddr("newDistributor");
    address internal initialFeeWallet = makeAddr("initialFeeWallet");
    address internal newFeeWallet = makeAddr("newFeeWallet");

    // Constants
    uint8 internal constant INITIAL_FEE_PERCENTAGE = 10; // 10%

    function setUp() public {
        // Deploy the logic contract for vaults
        vaultImplementation = new Vault();
        mockToken = new MockERC20();
        anotherMockToken = new MockERC20();

        // Deploy the factory, making `owner` the owner
        vm.prank(owner);
        factory = new Factory(
            owner, address(vaultImplementation), initialDistributor, initialFeeWallet, INITIAL_FEE_PERCENTAGE
        );
    }

    // --- Test Constructor ---

    function testConstructorSetsInitialValues() public view {
        assertEq(factory.owner(), owner);
        assertEq(factory.vaultImplementation(), address(vaultImplementation));
        assertEq(factory.getRewardDistributor(), initialDistributor);
        assertEq(factory.getFeeWallet(), initialFeeWallet);
        assertEq(factory.getCampaignFeePercentage(), INITIAL_FEE_PERCENTAGE);
    }

    function testRevertIfConstructorReceivesZeroAddressImplementation() public {
        vm.prank(owner);
        vm.expectRevert(Errors.InvalidClassHash.selector);
        new Factory(owner, address(0), initialDistributor, initialFeeWallet, INITIAL_FEE_PERCENTAGE);
    }

    function testRevertIfConstructorReceivesZeroAddressDistributor() public {
        vm.prank(owner);
        vm.expectRevert(Errors.InvalidDistributor.selector);
        new Factory(owner, address(vaultImplementation), address(0), initialFeeWallet, INITIAL_FEE_PERCENTAGE);
    }

    function testRevertIfConstructorReceivesInvalidFee() public {
        vm.prank(owner);
        vm.expectRevert(Errors.InvalidFeePercentage.selector);
        new Factory(owner, address(vaultImplementation), initialDistributor, initialFeeWallet, 101);
    }

    // --- Test `createCampaign` ---

    function testCreateCampaignSuccess() public {
        vm.startPrank(user1);

        // Check indexed topics (campaignId, creator) but not the non-deterministic vaultAddress in the data.
        vm.expectEmit(true, true, false, false);
        emit IFactory.CampaignCreated(1, user1, address(0)); // Address is a placeholder.
        address vaultAddress = factory.createCampaign();
        vm.stopPrank();

        assertEq(factory.getVaultCount(), 1);
        assertEq(factory.getVaultAddress(1), vaultAddress);
        assertNotEq(vaultAddress, address(0));

        IVault newVault = IVault(vaultAddress);
        assertEq(newVault.getCreator(), user1);
        assertEq(newVault.getDistributor(), initialDistributor);
    }

    // --- Test Token Allowlist ---

    function testAddAllowedToken() public {
        vm.startPrank(owner);

        // Event: TokenAdded(address indexed tokenAddress)
        // Check topic1 (tokenAddress) and the data payload.
        vm.expectEmit(true, false, false, true);
        emit IFactory.TokenAdded(address(mockToken));
        factory.addAllowedToken(address(mockToken));
        vm.stopPrank();

        assertTrue(factory.isTokenAllowed(address(mockToken)));
        address[] memory tokens = factory.getAllowedTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(mockToken));
    }

    function testRevertIfAddAllowedTokenCalledByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        factory.addAllowedToken(address(mockToken));
    }

    function testRemoveAllowedToken() public {
        vm.startPrank(owner);
        factory.addAllowedToken(address(mockToken));
        factory.addAllowedToken(address(anotherMockToken));

        // Event: TokenRemoved(address indexed tokenAddress)
        // Check topic1 (tokenAddress) and the data payload.
        vm.expectEmit(true, false, false, true);
        emit IFactory.TokenRemoved(address(mockToken));
        factory.removeAllowedToken(address(mockToken));
        vm.stopPrank();

        assertFalse(factory.isTokenAllowed(address(mockToken)));
        address[] memory tokens = factory.getAllowedTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(anotherMockToken));
    }

    function testRevertIfRemoveAllowedTokenCalledByNonOwner() public {
        vm.prank(owner);
        factory.addAllowedToken(address(mockToken));

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        factory.removeAllowedToken(address(mockToken));
    }

    // --- Test Admin Setters ---

    function testSetVaultImplementation() public {
        Vault newImplementation = new Vault();
        vm.startPrank(owner);

        // Event: VaultImplementationUpdated(address indexed newVaultImplementation)
        // Check topic1 (newVaultImplementation). No data payload.
        vm.expectEmit(true, false, false, false);
        emit IFactory.VaultImplementationUpdated(address(newImplementation));
        factory.setVaultImplementation(address(newImplementation));
        vm.stopPrank();

        assertEq(factory.vaultImplementation(), address(newImplementation));
    }

    function testRevertIfSetVaultImplementationByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        factory.setVaultImplementation(address(0x123));
    }

    function testSetRewardDistributor() public {
        vm.startPrank(owner);
        // Event: DistributorUpdated(address indexed oldDistributor, address indexed newDistributor)
        // Check topic1 and topic2. No data payload.
        vm.expectEmit(true, true, false, false);
        emit IFactory.DistributorUpdated(initialDistributor, newDistributor);
        factory.setRewardDistributor(newDistributor);
        vm.stopPrank();

        assertEq(factory.getRewardDistributor(), newDistributor);
    }

    function testRevertIfSetRewardDistributorByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        factory.setRewardDistributor(newDistributor);
    }

    function testSetFeeWallet() public {
        vm.startPrank(owner);
        // Event: FeeWalletUpdated(address indexed oldFeeWallet, address indexed newFeeWallet)
        // Check topic1 and topic2. No data payload.
        vm.expectEmit(true, true, false, false);
        emit IFactory.FeeWalletUpdated(initialFeeWallet, newFeeWallet);
        factory.setFeeWallet(newFeeWallet);
        vm.stopPrank();

        assertEq(factory.getFeeWallet(), newFeeWallet);
    }

    function testRevertIfSetFeeWalletByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        factory.setFeeWallet(newFeeWallet);
    }

    function testSetCampaignFeePercentage() public {
        uint8 newFee = 25;
        vm.startPrank(owner);
        // Event: FeePercentageUpdated(uint8 oldFeePercentage, uint8 newFeePercentage)
        // No indexed topics, so only check the data payload.
        vm.expectEmit(false, false, false, true);
        emit IFactory.FeePercentageUpdated(INITIAL_FEE_PERCENTAGE, newFee);
        factory.setCampaignFeePercentage(newFee);
        vm.stopPrank();

        assertEq(factory.getCampaignFeePercentage(), newFee);
    }

    function testRevertIfSetCampaignFeePercentageByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        factory.setCampaignFeePercentage(25);
    }

    function testRevertIfSetCampaignFeePercentageAbove100() public {
        vm.prank(owner);
        vm.expectRevert(Errors.InvalidFeePercentage.selector);
        factory.setCampaignFeePercentage(101);
    }

    // --- Test View Functions ---

    function testGetAllVaults() public {
        vm.prank(user1);
        address vault1 = factory.createCampaign();
        vm.prank(user2);
        address vault2 = factory.createCampaign();

        address[] memory vaults = factory.getAllVaults();
        assertEq(vaults.length, 2);
        assertEq(vaults[0], vault1);
        assertEq(vaults[1], vault2);
    }
}
