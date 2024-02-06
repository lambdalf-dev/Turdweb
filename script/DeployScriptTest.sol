pragma solidity 0.8.24;

import {DeployBase} from "./DeployBase.sol";
import {Factory} from "./../src/Factory.sol";
import {Migrated721} from "./../src/Migrated721.sol";
import {Wrapped721} from "./../src/Wrapped721.sol";
import {console} from "forge-std/console.sol";

contract DeployScript is DeployBase {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("TEST_PRIVATE_KEY");

    bytes memory factoryCode = abi.encodePacked(type(Factory).creationCode);

    bytes memory migrated721Code = abi.encodePacked(type(Migrated721).creationCode);

    bytes memory wrapped721Code = abi.encodePacked(type(Wrapped721).creationCode);

    vm.startBroadcast(deployerPrivateKey);

    address factory = CREATE2.safeCreate2(factorySalt, factoryCode);
    console.log("Deployed factory at address: ", factory);
    address migrated = CREATE2.safeCreate2(migratedSalt, migrated721Code);
    console.log("Deployed migrated at address: ", migrated);
    address wrapped = CREATE2.safeCreate2(wrappedSalt, wrapped721Code);
    console.log("Deployed wrapped at address: ", wrapped);

    vm.stopBroadcast();
  }
}
