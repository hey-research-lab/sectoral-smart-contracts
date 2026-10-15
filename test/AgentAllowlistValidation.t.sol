// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProtocolAuthority} from "../src/ProtocolAuthority.sol";
import {AccountRegistry} from "../src/AccountRegistry.sol";
import {AgentController} from "../src/AgentController.sol";
import {IProtocolAuthority} from "../src/interfaces/IProtocolAuthority.sol";
import {IAccountRegistry} from "../src/interfaces/IAccountRegistry.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "../src/libraries/ProtocolErrors.sol";

contract AgentAllowlistValidationTest is Test {
    AgentController agents;
    MockERC20 usdg;

    address compliance = makeAddr("compliance");
    address gwen = makeAddr("gwen");
    address vendor = makeAddr("vendor");
    address other = makeAddr("other");

    function setUp() public {
        usdg = new MockERC20("Global Dollar", "USDG", 6);
        ProtocolAuthority protocol = new ProtocolAuthority(compliance);
        AccountRegistry registry = new AccountRegistry(IProtocolAuthority(address(protocol)));
        agents = new AgentController(
            IProtocolAuthority(address(protocol)), IAccountRegistry(address(registry))
        );

        vm.prank(gwen);
        registry.createProfile("gwen", AccountRegistry.AccountKind.Personal);
    }

    function _create(address[] memory list) internal returns (uint256) {
        vm.prank(gwen);
        return agents.createAgent(
            makeAddr("signer"),
            "coding-assistant",
            AgentController.AutonomyTier.SemiAutonomous,
            address(usdg),
            10e6,
            50e6,
            5e6,
            list,
            true
        );
    }

    function test_create_rejects_a_zero_recipient() public {
        address[] memory list = new address[](2);
        list[0] = vendor;
        vm.expectRevert(ZeroAddress.selector);
        _create(list);
    }

    function test_create_rejects_duplicate_recipients() public {
        address[] memory list = new address[](3);
        list[0] = vendor;
        list[1] = other;
        list[2] = vendor;
        vm.expectRevert(RecipientAlreadyAllowed.selector);
        _create(list);
    }

    function test_update_applies_the_same_rules() public {
        address[] memory list = new address[](1);
        list[0] = vendor;
        uint256 agentId = _create(list);

        address[] memory dupes = new address[](2);
        dupes[0] = other;
        dupes[1] = other;
        vm.expectRevert(RecipientAlreadyAllowed.selector);
        vm.prank(gwen);
        agents.updateSpendPolicy(agentId, 10e6, 50e6, 5e6, true, dupes);

        address[] memory zero = new address[](1);
        vm.expectRevert(ZeroAddress.selector);
        vm.prank(gwen);
        agents.updateSpendPolicy(agentId, 10e6, 50e6, 5e6, true, zero);
    }

    function test_a_clean_list_is_accepted() public {
        address[] memory list = new address[](2);
        list[0] = vendor;
        list[1] = other;
        uint256 agentId = _create(list);
        assertEq(agents.getPolicy(agentId).allowedRecipients.length, 2);
    }
}
