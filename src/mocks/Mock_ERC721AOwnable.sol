// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {IERC721} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721.sol";
import {IERC721Enumerable} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721Enumerable.sol";
import {IERC721Metadata} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721Metadata.sol";
import {IERC165} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC165.sol";
import {ERC173} from "@lambdalf-dev/ethereum-contracts/contracts/utils/ERC173.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";

/* solhint-disable */
contract Mock_ERC721AOwnable is ERC721A, IERC165, ERC173 {
  constructor() ERC721A("NFT Collection", "NFT") ERC173(msg.sender) {}

  function mint(address recipient_, uint256 qty_) external {
    _mint(recipient_, qty_);
  }

  function supportsInterface(bytes4 interfaceId_) public pure override(IERC165, ERC721A) returns (bool) {
    return interfaceId_ == type(IERC721).interfaceId || interfaceId_ == type(IERC721Enumerable).interfaceId
      || interfaceId_ == type(IERC721Metadata).interfaceId || interfaceId_ == type(IERC165).interfaceId;
  }
}
/* solhint-enable */
