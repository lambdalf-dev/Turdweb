pragma solidity 0.8.24;

import {DeployBase} from "./DeployBase.sol";
import {Wrapped721} from "./../src/Wrapped721.sol";
import {console} from "forge-std/console.sol";

contract DeployScript is DeployBase {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("MAIN_DEV_PRIVATE_KEY");

    bytes memory wrapped721Code = abi.encodePacked(type(Wrapped721).creationCode);

    vm.startBroadcast(deployerPrivateKey);

    address wrapped = CREATE2.safeCreate2(wrappedSalt, wrapped721Code);
    console.log("Deployed wrapped at address: ", wrapped);

    vm.stopBroadcast();
  }
}
