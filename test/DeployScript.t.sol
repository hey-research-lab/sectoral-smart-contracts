// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {ProtocolAuthority} from "../src/ProtocolAuthority.sol";
import {ConfidentialToken} from "../src/confidential/ConfidentialToken.sol";
import {FeeSchedule} from "../src/fees/FeeSchedule.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// The deploy script has to leave every admin role with the key that
/// broadcast it, not with whatever `msg.sender` the script happens to run as.
contract DeployScriptTest is Test {
    function test_deployer_holds_every_admin_role() public {
        uint256 pk = 0xA11CE;
        address deployer = vm.addr(pk);
        MockERC20 usdg = new MockERC20("Global Dollar", "USDG", 6);

        vm.setEnv("PRIVATE_KEY", vm.toString(pk));
        vm.setEnv("COMPLIANCE_AUTHORITY", vm.toString(makeAddr("compliance")));
        vm.setEnv("USDG_ADDRESS", vm.toString(address(usdg)));
        vm.setEnv("TRANSFER_VERIFIER_ADDRESS", vm.toString(address(0)));
        vm.setEnv("TREASURY", vm.toString(makeAddr("treasury")));

        uint64 nonce = vm.getNonce(deployer);
        new Deploy().run();

        // Creation order in Deploy.run: protocol, registry, agents, requests,
        // disclosures, stub verifier, confidential token, fee schedule.
        ProtocolAuthority protocol = ProtocolAuthority(vm.computeCreateAddress(deployer, nonce));
        ConfidentialToken confidential =
            ConfidentialToken(vm.computeCreateAddress(deployer, nonce + 6));
        FeeSchedule feeSchedule = FeeSchedule(vm.computeCreateAddress(deployer, nonce + 7));

        assertEq(protocol.authority(), deployer);
        assertEq(confidential.authority(), deployer);
        assertEq(feeSchedule.authority(), deployer);
        assertEq(protocol.feeSchedule(), address(feeSchedule));
    }
}
