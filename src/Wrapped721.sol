// SPDX-License-Identifier: MIT

/**
 * Author: Lambdalf the White
 */

pragma solidity >=0.8.4 <0.9.0;

import {ERC173Initializable} from "./ERC173Initializable.sol";
import {ERC2981Initializable} from "./ERC2981Initializable.sol";
import {IAsset} from "./interfaces/IAsset.sol";
import {IERC165} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC165.sol";
import {IERC173} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC173.sol";
import {IERC721} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721Metadata.sol";
import {IERC721Enumerable} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721Enumerable.sol";
import {IERC721Receiver} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721Receiver.sol";
import {IERC2981} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC2981.sol";

contract Wrapped721 is IERC165, ERC173Initializable, ERC2981Initializable, IERC721, IERC721Metadata, IERC721Enumerable {
  // **************************************
  // *****           ERRORS           *****
  // **************************************
  /// @dev Thrown when trying to withdraw from the contract with no balance.
  error ETHER_NO_BALANCE();
  /// @dev Thrown when contract fails to send ether to recipient.
  ///
  /// @param to the recipient of the ether
  /// @param amount the amount of ether being sent
  error ETHER_TRANSFER_FAIL(address to, uint256 amount);
  // **************************************

  // **************************************
  // *****     STORAGE VARIABLES      *****
  // **************************************
  IAsset public underlyingAsset;

  // ***********
  // * IERC721 *
  // ***********
  /// @dev Number of NFT tracked by this contract
  uint256 public totalSupply;
  /// @dev Token ID mapped to approved address
  mapping(uint256 => address) private _approvals;
  /// @dev Token owner mapped to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;
  /// @dev List of owner addresses
  mapping(uint256 => address) private _owners;
  /// @dev List of owner balances
  mapping(address => uint256) private _balances;
  // ***********
  // **************************************

  constructor() {
    initialize(address(0), address(0), address(0), 0);
  }

  function initialize(
    address admin_,
    address asset_,
    address royaltyRecipient_,
    uint96 royaltyRate_
  ) public initializer {
    underlyingAsset = IAsset(asset_);
    _init_ERC173(admin_);
    _init_ERC2981(royaltyRecipient_, royaltyRate_);
  }

  // **************************************
  // *****          FALLBACK          *****
  // **************************************
  fallback() external payable {} // solhint-disable no-empty-blocks
  receive() external payable {} // solhint-disable no-empty-blocks
  // **************************************

  // **************************************
  // *****          MODIFIER          *****
  // **************************************
  // ***********
  // * IERC721 *
  // ***********
  /// @dev Throws if `tokenId_` doesn't exist.
  /// A token exists if it has been minted and is not owned by the zero address.
  ///
  /// @param tokenId_ identifier of the NFT being referenced
  modifier exists(uint256 tokenId_) {
    if (_owners[tokenId_] == address(0)) {
      revert IERC721_NONEXISTANT_TOKEN(tokenId_);
    }
    _;
  }
  // ***********
  // **************************************

  // **************************************
  // *****           PUBLIC           *****
  // **************************************
  /// @dev Wraps a token from the underlying collection and transfers it to `toAddress_`.
  ///
  /// @param tokenIds_ list of identifiers of the NFT being referenced
  ///
  /// Requirements:
  ///
  /// - The token number `tokenId_` must exist in the underlying collection.
  /// - The caller must own the token in the underlying collection.
  /// - This contract must be allowed to transfer `tokenId_` from the underlying collection on behalf of the caller.
  function wrap(uint256[] calldata tokenIds_) public {
    unchecked {
      totalSupply += tokenIds_.length;
      _balances[msg.sender] += tokenIds_.length;
    }
    for (uint256 i; i < tokenIds_.length; ++i) {
      _owners[tokenIds_[i]] = msg.sender;
      emit Transfer(address(0), msg.sender, tokenIds_[i]);
      underlyingAsset.transferFrom(msg.sender, address(this), tokenIds_[i]);
    }
  }
  /// @dev Unwraps a token from the underlying collection and transfers it to `toAddress_`.
  ///
  /// @param tokenIds_ list of identifiers of the NFT being referenced
  ///
  /// Requirements:
  ///
  /// - The token number `tokenId_` must exist in the underlying collection.
  /// - The caller must own the token or be an approved operator.

  function unwrap(uint256[] calldata tokenIds_) public {
    unchecked {
      totalSupply -= tokenIds_.length;
      _balances[msg.sender] -= tokenIds_.length;
    }
    for (uint256 i; i < tokenIds_.length; ++i) {
      if (_owners[tokenIds_[i]] != msg.sender) {
        revert IERC721_CALLER_NOT_APPROVED(msg.sender, tokenIds_[i]);
      }
      _owners[tokenIds_[i]] = address(0);
      emit Transfer(msg.sender, address(0), tokenIds_[i]);
      underlyingAsset.transferFrom(address(this), msg.sender, tokenIds_[i]);
    }
  }
  // ***********
  // * IERC721 *
  // ***********
  /// @dev Gives permission to `to_` to transfer the token number `tokenId_` on behalf of its owner.
  /// The approval is cleared when the token is transferred.
  ///
  /// Only a single account can be approved at a time, so approving the zero address clears previous approvals.
  ///
  /// @param to_ The new approved NFT controller
  /// @param tokenId_ The NFT to approve
  ///
  /// Requirements:
  ///
  /// - The token number `tokenId_` must exist.
  /// - The caller must own the token or be an approved operator.
  /// - Must emit an {Approval} event.

  function approve(address to_, uint256 tokenId_) public virtual override {
    address _tokenOwner_ = ownerOf(tokenId_);
    if (to_ == _tokenOwner_) {
      revert IERC721_INVALID_APPROVAL();
    }
    bool _isApproved_ = _isApprovedOrOwner(_tokenOwner_, msg.sender, tokenId_);
    if (!_isApproved_) {
      revert IERC721_CALLER_NOT_APPROVED(msg.sender, tokenId_);
    }
    _approvals[tokenId_] = to_;
    emit Approval(_tokenOwner_, to_, tokenId_);
  }
  /// @dev Transfers the token number `tokenId_` from `from_` to `to_`.
  ///
  /// @param from_ The current owner of the NFT
  /// @param to_ The new owner
  /// @param tokenId_ identifier of the NFT being referenced
  ///
  /// Requirements:
  ///
  /// - The token number `tokenId_` must exist.
  /// - `from_` must be the token owner.
  /// - The caller must own the token or be an approved operator.
  /// - `to_` must not be the zero address.
  /// - If `to_` is a contract, it must implement {IERC721Receiver-onERC721Received} with a return value of `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`,
  /// - Must emit a {Transfer} event.

  function safeTransferFrom(address from_, address to_, uint256 tokenId_) public virtual override {
    safeTransferFrom(from_, to_, tokenId_, "");
  }
  /// @dev Transfers the token number `tokenId_` from `from_` to `to_`.
  ///
  /// @param from_ The current owner of the NFT
  /// @param to_ The new owner
  /// @param tokenId_ identifier of the NFT being referenced
  /// @param data_ Additional data with no specified format, sent in call to `to_`
  ///
  /// Requirements:
  ///
  /// - The token number `tokenId_` must exist.
  /// - `from_` must be the token owner.
  /// - The caller must own the token or be an approved operator.
  /// - `to_` must not be the zero address.
  /// - If `to_` is a contract, it must implement {IERC721Receiver-onERC721Received} with a return value of `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`,
  /// - Must emit a {Transfer} event.

  function safeTransferFrom(address from_, address to_, uint256 tokenId_, bytes memory data_) public virtual override {
    transferFrom(from_, to_, tokenId_);
    if (!_checkOnERC721Received(from_, to_, tokenId_, data_)) {
      revert IERC721_INVALID_RECEIVER(to_);
    }
  }
  /// @dev Allows or disallows `operator_` to manage the caller's tokens on their behalf.
  ///
  /// @param operator_ Address to add to the set of authorized operators
  /// @param approved_ True if the operator is approved, false to revoke approval
  ///
  /// Requirements:
  ///
  /// - Must emit an {ApprovalForAll} event.

  function setApprovalForAll(address operator_, bool approved_) public virtual override {
    if (operator_ == msg.sender) {
      revert IERC721_INVALID_APPROVAL();
    }
    _operatorApprovals[msg.sender][operator_] = approved_;
    emit ApprovalForAll(msg.sender, operator_, approved_);
  }
  /// @dev Transfers the token number `tokenId_` from `from_` to `to_`.
  ///
  /// @param from_ the current owner of the NFT
  /// @param to_ the new owner
  /// @param tokenId_ identifier of the NFT being referenced
  ///
  /// Requirements:
  ///
  /// - The token number `tokenId_` must exist.
  /// - `from_` must be the token owner.
  /// - The caller must own the token or be an approved operator.
  /// - `to_` must not be the zero address.
  /// - Must emit a {Transfer} event.

  function transferFrom(address from_, address to_, uint256 tokenId_) public virtual override {
    if (to_ == address(0)) {
      revert IERC721_INVALID_RECEIVER(to_);
    }
    address _tokenOwner_ = ownerOf(tokenId_);
    if (from_ != _tokenOwner_) {
      revert IERC721_INVALID_TOKEN_OWNER();
    }
    if (!_isApprovedOrOwner(_tokenOwner_, msg.sender, tokenId_)) {
      revert IERC721_CALLER_NOT_APPROVED(msg.sender, tokenId_);
    }
    unchecked {
      --_balances[from_];
      ++_balances[to_];
    }
    _transfer(from_, to_, tokenId_);
  }
  // ***********
  // ***********************
  // * ERC721BatchBurnable *
  // ***********************
  /// @dev Burns `tokenId_`.
  ///
  /// Requirements:
  ///
  /// - `tokenId_` must exist
  /// - The caller must own `tokenId_` or be an approved operator

  function burn(uint256 tokenId_) public {
    address _tokenOwner_ = ownerOf(tokenId_);
    if (!_isApprovedOrOwner(_tokenOwner_, msg.sender, tokenId_)) {
      revert IERC721_CALLER_NOT_APPROVED(msg.sender, tokenId_);
    }
    unchecked {
      --totalSupply;
      --_balances[msg.sender];
    }
    _transfer(_tokenOwner_, address(0), tokenId_);
  }
  // ***********************
  // **************************************

  // **************************************
  // *****       CONTRACT_OWNER       *****
  // **************************************
  /// @notice Withdraws all the money stored in the contract and sends it to the treasury.
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  /// - Contract must have a positive balance.
  /// - Caller must be able to receive the funds.
  function withdraw() public onlyOwner {
    uint256 _balance_ = address(this).balance;
    if (_balance_ == 0) {
      revert ETHER_NO_BALANCE();
    }

    // solhint-disable-next-line
    (bool _success_,) = payable(msg.sender).call{value: _balance_}("");
    if (!_success_) {
      revert ETHER_TRANSFER_FAIL(msg.sender, _balance_);
    }
  }

  // ************
  // * IERC2981 *
  // ************
  /// @dev Sets the royalty rate to `newRoyaltyRate_` and the royalty recipient to `newRoyaltyRecipient_`.
  ///
  /// @param newRoyaltyRecipient_ the address that will receive royalty payments
  /// @param newRoyaltyRate_ the percentage of the sale price that will be taken off as royalties,
  ///   expressed in Basis Points (100 BP = 1%)
  ///
  /// Requirements:
  ///
  /// - Caller must be the contract owner.
  /// - `newRoyaltyRate_` cannot be higher than {ROYALTY_BASE};
  function setRoyaltyInfo(address newRoyaltyRecipient_, uint96 newRoyaltyRate_) public onlyOwner {
    _setRoyaltyInfo(newRoyaltyRecipient_, newRoyaltyRate_);
  }
  // ************
  // **************************************

  // **************************************
  // *****            VIEW            *****
  // **************************************
  // ***********
  // * IERC721 *
  // ***********
  /// @dev Returns the number of tokens in `tokenOwner_`'s account.
  ///
  /// @param tokenOwner_ address that owns tokens
  ///
  /// @return ownerBalance the nomber of tokens owned by `tokenOwner_`
  ///
  /// Requirements:
  ///
  /// - `tokenOwner_` must not be the zero address
  function balanceOf(address tokenOwner_) public view virtual override returns (uint256 ownerBalance) {
    if (tokenOwner_ == address(0)) {
      revert IERC721_INVALID_TOKEN_OWNER();
    }
    ownerBalance = _balances[tokenOwner_];
  }
  /// @dev Returns the address that has been specifically allowed to manage `tokenId_` on behalf of its owner.
  ///
  /// @param tokenId_ the NFT that has been approved
  ///
  /// @return approved the address allowed to manage `tokenId_`
  ///
  /// Requirements:
  ///
  /// - `tokenId_` must exist.
  ///
  /// Note: See {Approve}

  function getApproved(uint256 tokenId_) public view virtual override returns (address approved) {
    if (_owners[tokenId_] == address(0)) {
      revert IERC721_NONEXISTANT_TOKEN(tokenId_);
    }
    return _approvals[tokenId_];
  }
  /// @dev Returns whether `operator_` is allowed to manage tokens on behalf of `tokenOwner_`.
  ///
  /// @param tokenOwner_ address that owns tokens
  /// @param operator_ address that tries to manage tokens
  ///
  /// @return isApproved whether `operator_` is allowed to handle `tokenOwner`'s tokens
  ///
  /// Note: See {setApprovalForAll}

  function isApprovedForAll(
    address tokenOwner_,
    address operator_
  ) public view virtual override returns (bool isApproved) {
    return _operatorApprovals[tokenOwner_][operator_];
  }
  /// @dev Returns the owner of the token number `tokenId_`.
  ///
  /// @param tokenId_ the NFT to verify ownership of
  ///
  /// @return tokenOwner the owner of token number `tokenId_`
  ///
  /// Requirements:
  ///
  /// - `tokenId_` must exist.

  function ownerOf(uint256 tokenId_) public view virtual override returns (address tokenOwner) {
    tokenOwner = _owners[tokenId_];
    if (tokenOwner == address(0)) {
      revert IERC721_NONEXISTANT_TOKEN(tokenId_);
    }
  }
  // ***********

  // *********************
  // * IERC721Enumerable *
  // *********************
  /// @dev Enumerate valid NFTs
  ///
  /// @param index_ the index requested
  ///
  /// @return tokenId the identifier of the token at the specified index
  ///
  /// Requirements:
  ///
  /// - `index_` must be less than {totalSupply}
  function tokenByIndex(uint256 index_) public view virtual override returns (uint256) {
    if (index_ >= totalSupply) {
      revert IERC721Enumerable_INDEX_OUT_OF_BOUNDS(index_);
    }

    uint256 _count_;
    uint256 _id_;
    while (_count_ <= index_) {
      if (_owners[_id_] != address(0)) {
        if (index_ == _count_) {
          return _id_;
        }
        unchecked {
          ++_count_;
        }
      }
      unchecked {
        ++_id_;
      }
    }
  }
  /// @dev Enumerate NFTs assigned to an owner
  ///
  /// @param tokenOwner_ the address requested
  /// @param index_ the index requested
  ///
  /// @return tokenId the identifier of the token at the specified index
  ///
  /// Requirements:
  ///
  /// - `index_` must be less than {balanceOf(tokenOwner_)}
  /// - `tokenOwner_` must not be the zero address

  function tokenOfOwnerByIndex(address tokenOwner_, uint256 index_) public view virtual override returns (uint256) {
    if (tokenOwner_ == address(0)) {
      revert IERC721_INVALID_TOKEN_OWNER();
    }
    if (index_ >= _balances[tokenOwner_]) {
      revert IERC721Enumerable_OWNER_INDEX_OUT_OF_BOUNDS(index_);
    }

    uint256 _count_;
    uint256 _id_;
    while (_count_ <= index_) {
      if (_owners[_id_] == tokenOwner_) {
        if (index_ == _count_) {
          return _id_;
        }
        unchecked {
          ++_count_;
        }
      }
      unchecked {
        ++_id_;
      }
    }
  }
  // *********************

  // *******************
  // * IERC721Metadata *
  // *******************
  /// @dev A descriptive name for a collection of NFTs in this contract
  ///
  /// @return tokenName The descriptive name of the NFTs
  function name() public view virtual override returns (string memory tokenName) {
    tokenName = underlyingAsset.name();
  }
  /// @dev An abbreviated name for NFTs in this contract
  ///
  /// @return tokenSymbol The abbreviated name of the NFTs

  function symbol() public view virtual override returns (string memory tokenSymbol) {
    tokenSymbol = underlyingAsset.symbol();
  }
  /// @dev A distinct Uniform Resource Identifier (URI) for a given asset.
  ///
  /// @param tokenId_ the NFT that has been approved
  ///
  /// @return uri the URI of the token
  ///
  /// Requirements:
  ///
  /// - `tokenId_` must exist.

  function tokenURI(uint256 tokenId_) public view virtual override returns (string memory uri) {
    if (_owners[tokenId_] == address(0)) {
      revert IERC721_NONEXISTANT_TOKEN(tokenId_);
    }
    uri = underlyingAsset.tokenURI(tokenId_);
  }
  // *******************

  // ***********
  // * IERC165 *
  // ***********
  /// @dev Query if a contract implements an interface.
  /// @dev see https://eips.ethereum.org/EIPS/eip-165
  ///
  /// @param interfaceId_ the interface identifier, as specified in ERC-165
  ///
  /// @return bool true if the contract implements the specified interface, false otherwise
  ///
  /// Requirements:
  ///
  /// - This function must use less than 30,000 gas.
  function supportsInterface(bytes4 interfaceId_) public pure override returns (bool) {
    return interfaceId_ == type(IERC721).interfaceId || interfaceId_ == type(IERC721Enumerable).interfaceId
      || interfaceId_ == type(IERC721Metadata).interfaceId || interfaceId_ == type(IERC173).interfaceId
      || interfaceId_ == type(IERC165).interfaceId || interfaceId_ == type(IERC2981).interfaceId;
  }
  // ***********
  // **************************************

  // **************************************
  // *****          INTERNAL          *****
  // **************************************
  // ***********
  // * IERC721 *
  // ***********
  /// @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
  /// The call is not executed if the target address is not a contract.
  ///
  /// @param from_ address owning the token being transferred
  /// @param to_ address the token is being transferred to
  /// @param tokenId_ identifier of the NFT being referenced
  /// @param data_ optional data to send along with the call
  ///
  /// @return isValidReceiver whether the call correctly returned the expected value
  function _checkOnERC721Received(
    address from_,
    address to_,
    uint256 tokenId_,
    bytes memory data_
  ) internal virtual returns (bool isValidReceiver) {
    // This method relies on extcodesize, which returns 0 for contracts in
    // construction, since the code is only stored at the end of the
    // constructor execution.
    //
    // IMPORTANT
    // It is unsafe to assume that an address not flagged by this method
    // is an externally-owned account (EOA) and not a contract.
    //
    // Among others, the following types of addresses will not be flagged:
    //
    //  - an externally-owned account
    //  - a contract in construction
    //  - an address where a contract will be created
    //  - an address where a contract lived, but was destroyed
    uint256 _size_;
    assembly {
      _size_ := extcodesize(to_)
    }
    // If address is a contract, check that it is aware of how to handle ERC721 tokens
    if (_size_ > 0) {
      try IERC721Receiver(to_).onERC721Received(msg.sender, from_, tokenId_, data_) returns (bytes4 retval) {
        return retval == IERC721Receiver.onERC721Received.selector;
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert IERC721_INVALID_RECEIVER(to_);
        } else {
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }
  /// @dev Internal function returning whether `operator_` is allowed to handle `tokenId_`
  ///
  /// Note: To avoid multiple checks for the same data, it is assumed
  /// that existence of `tokenId_` has been verified prior via {_exists}
  /// If it hasn't been verified, this function might panic
  ///
  /// @param operator_ address that tries to handle the token
  /// @param tokenId_ identifier of the NFT being referenced
  ///
  /// @return isApproved whether `operator_` is allowed to manage the token

  function _isApprovedOrOwner(
    address tokenOwner_,
    address operator_,
    uint256 tokenId_
  ) internal view virtual returns (bool isApproved) {
    return operator_ == tokenOwner_ || operator_ == getApproved(tokenId_) || _operatorApprovals[tokenOwner_][operator_];
  }
  /// @dev Transfers `tokenId_` from `fromAddress_` to `toAddress_`.
  ///
  /// Emits a {Transfer} event.
  ///
  /// @param fromAddress_ the current owner of the NFT
  /// @param toAddress_ the new owner
  /// @param tokenId_ identifier of the NFT being referenced

  function _transfer(address fromAddress_, address toAddress_, uint256 tokenId_) internal virtual {
    _approvals[tokenId_] = address(0);
    _owners[tokenId_] = toAddress_;
    emit Transfer(fromAddress_, toAddress_, tokenId_);
  }
  // ***********
  // **************************************
}
