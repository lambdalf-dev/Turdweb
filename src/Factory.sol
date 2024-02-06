// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

contract Factory {
  address[] public proxies;

  function deployClone(address implementationContract_, bytes calldata deploymentData_) external returns (address) {
    // convert the address to 20 bytes
    bytes20 implementationContractInBytes = bytes20(implementationContract_);
    //address to assign a cloned proxy
    address proxy;

    // as stated earlier, the minimal proxy has this bytecode
    // <3d602d80600a3d3981f3363d3d373d3d3d363d73><address of implementation contract><5af43d82803e903d91602b57fd5bf3>

    // <3d602d80600a3d3981f3> == creation code which copies runtime code into memory and deploys it

    // <363d3d373d3d3d363d73> <address of implementation contract> <5af43d82803e903d91602b57fd5bf3> == runtime code that makes a delegatecall to the implentation contract

    assembly {
      /*
      reads the 32 bytes of memory starting at the pointer stored in 0x40
      In solidity, the 0x40 slot in memory is special: it contains the "free memory pointer"
      which points to the end of the currently allocated memory.
      */
      let clone := mload(0x40)
      // store 32 bytes to memory starting at "clone"
      mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)

      /*
        |              20 bytes                |
      0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
                            ^
                            pointer
      */
      // store 32 bytes to memory starting at "clone" + 20 bytes
      // 0x14 = 20
      mstore(add(clone, 0x14), implementationContractInBytes)

      /*
        |               20 bytes               |                 20 bytes              |
      0x3d602d80600a3d3981f3363d3d373d3d3d363d73bebebebebebebebebebebebebebebebebebebebe
                                                ^
                                                pointer
      */
      // store 32 bytes to memory starting at "clone" + 40 bytes
      // 0x28 = 40
      mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)

      /*
      |                 20 bytes                  |          20 bytes          |           15 bytes          |
      0x3d602d80600a3d3981f3363d3d373d3d3d363d73b<implementationContractInBytes>5af43d82803e903d91602b57fd5bf3 == 45 bytes in total
      */

      // create a new contract
      // send 0 Ether
      // code starts at the pointer stored in "clone"
      // code size == 0x37 (55 bytes)
      proxy := create(0, clone, 0x37)

      // Call initialization
      // Get the size of deploymentData_
      // revert if call reverts
      // The following list explains what the arguments are to the `staticcall` function below
      // first, we use staticcall to ensure read-only behavior
      // gas()              : forward all gas
      // proxy              : contract we are calling
      // 0x00               : no ether is sent with the call
      // deploymentData_    : our calldata start location
      // deploymentDataSize : make sure we send all the calldata
      // 0x00               : where the return data starts in memory
      // 0x20               : the offset of where the return data ends in memory
      calldatacopy(mload(0x40), deploymentData_.offset, deploymentData_.length)
      if iszero(call(gas(), proxy, 0x00, mload(0x40), deploymentData_.length, 0x00, 0x20)) {
        returndatacopy(0x00, 0x00, returndatasize())
        revert(0x00, returndatasize())
      }
    }
    proxies.push(proxy);
    return proxy;
  }
}
