// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {IERC721} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721.sol";
import {IERC173} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC173.sol";
import {IERC721Metadata} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721Metadata.sol";

interface IAsset is IERC173, IERC721, IERC721Metadata {}
