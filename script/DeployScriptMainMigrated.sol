pragma solidity 0.8.24;

import {DeployBase} from "./DeployBase.sol";
import {Migrated721} from "./../src/Migrated721.sol";
import {console} from "forge-std/console.sol";

contract DeployScript is DeployBase {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("MAIN_DEV_PRIVATE_KEY");

    bytes memory migrated721Code = abi.encodePacked(type(Migrated721).creationCode);

    vm.startBroadcast(deployerPrivateKey);

    address migrated = CREATE2.safeCreate2(migratedSalt, migrated721Code);
    console.log("Deployed migrated at address: ", migrated);

    vm.stopBroadcast();
  }
}
