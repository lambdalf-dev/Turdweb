pragma solidity 0.8.24;

import {IImmutableCreate2Factory} from "./../src/interfaces/IImmutableCreate2Factory.sol";
import {Migrated721} from "./../src/Migrated721.sol";
import {Migrated721Factory} from "./../src/Migrated721Factory.sol";
import {Wrapped721} from "./../src/Wrapped721.sol";
import {Wrapped721Factory} from "./../src/Wrapped721Factory.sol";
import {Script} from "forge-std/Script.sol";

contract DeployScript is Script {
  IImmutableCreate2Factory CREATE2 = IImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);

  function run() external {
    uint256 deployerPrivateKey = vm.envUint("TEST_DEV_PRIVATE_KEY");

    bytes32 migratedSalt = bytes32(0x00) & bytes12(keccak256(abi.encodePacked("MIGRATED721")));
    bytes memory migrated721Code = abi.encodePacked(type(Migrated721).creationCode);
    bytes memory migrated721FactoryCode = abi.encodePacked(type(Migrated721Factory).creationCode);

    bytes32 wrappedSalt = bytes32(0x00) & bytes12(keccak256(abi.encodePacked("WRAPPED721")));
    bytes memory wrapped721Code = abi.encodePacked(type(Wrapped721).creationCode);
    bytes memory wrapped721FactoryCode = abi.encodePacked(type(Wrapped721Factory).creationCode);

    vm.startBroadcast(deployerPrivateKey);

    address migratedImpl = CREATE2.safeCreate2(migratedSalt, migrated721Code);
    address migratedFactory = CREATE2.safeCreate2(migratedSalt, migrated721FactoryCode);

    address wrappedImpl = CREATE2.safeCreate2(wrappedSalt, wrapped721Code);
    address wrappedFactory = CREATE2.safeCreate2(wrappedSalt, wrapped721FactoryCode);

    vm.stopBroadcast();
  }
}
