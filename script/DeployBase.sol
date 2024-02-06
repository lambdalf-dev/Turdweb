pragma solidity 0.8.24;

import {IImmutableCreate2Factory} from "./../src/interfaces/IImmutableCreate2Factory.sol";
import {Script} from "forge-std/Script.sol";

contract DeployBase is Script {
  IImmutableCreate2Factory CREATE2 = IImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);
  bytes32 factorySalt = bytes32(0x00) & bytes12(keccak256(abi.encodePacked("FACTORY")));
  bytes32 migratedSalt = bytes32(0x00) & bytes12(keccak256(abi.encodePacked("MIGRATED721")));
  bytes32 wrappedSalt = bytes32(0x00) & bytes12(keccak256(abi.encodePacked("WRAPPED_721")));
}
