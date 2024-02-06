pragma solidity 0.8.24;

import {DeployBase} from "./DeployBase.sol";
import {Factory} from "./../src/Factory.sol";
import {console} from "forge-std/console.sol";

contract DeployScript is DeployBase {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("TEST_DEV_PRIVATE_KEY");

    bytes memory factoryCode = abi.encodePacked(type(Factory).creationCode);

    vm.startBroadcast(deployerPrivateKey);

    address factory = CREATE2.safeCreate2(factorySalt, factoryCode);
    console.log("Deployed factory at address: ", factory);

    vm.stopBroadcast();
  }
}
