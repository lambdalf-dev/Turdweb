// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IImmutableCreate2Factory {
  function safeCreate2(bytes32 salt, bytes calldata initializationCode) external payable returns (address);

  function findCreate2Address(bytes32 salt, bytes calldata initCode) external view returns (address);

  function findCreate2AddressViaHash(bytes32 salt, bytes32 initCodeHash) external view returns (address);

  function hasBeenDeployed(address deploymentAddress) external view returns (bool);
}
