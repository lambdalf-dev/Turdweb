// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import {Migrated721} from "../src/Migrated721.sol";
import {Factory} from "../src/Factory.sol";
import {TokenERC721} from "../src/mocks/TokenERC721.sol";

import {TestHelper} from "./TestHelper.sol";
import {IERC721Receiver} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721Receiver.sol";
import {IERC721} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721.sol";
import {IERC721Enumerable} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721Enumerable.sol";
import {IERC721Metadata} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC721Metadata.sol";
import {IERC173} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC173.sol";
import {IERC165} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC165.sol";
import {IERC2981} from "@lambdalf-dev/ethereum-contracts/contracts/interfaces/IERC2981.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IERC173Events} from "../src/mocks/events/IERC173Events.sol";
import {IERC721Events} from "../src/mocks/events/IERC721Events.sol";
import {Mock_Invalid_Eth_Receiver} from
  "@lambdalf-dev/ethereum-contracts/contracts/mocks/external/Mock_Invalid_Eth_Receiver.sol";
import {Mock_NonERC721Receiver} from
  "@lambdalf-dev/ethereum-contracts/contracts/mocks/external/Mock_NonERC721Receiver.sol";
import {Mock_ERC721Receiver} from "@lambdalf-dev/ethereum-contracts/contracts/mocks/external/Mock_ERC721Receiver.sol";

contract Deployed is TestHelper, IERC173Events, IERC721Events {
  bytes4[] public INTERFACES = [
    type(IERC721).interfaceId,
    type(IERC721Enumerable).interfaceId,
    type(IERC721Metadata).interfaceId,
    type(IERC173).interfaceId,
    type(IERC165).interfaceId,
    type(IERC2981).interfaceId
  ];
  Factory factory;
  Migrated721 implementation;
  Migrated721 testContract;
  TokenERC721 underlyingAsset;

  function setUp() public virtual override {
    super.setUp();
    address[] memory addrs = new address[](1);
    addrs[0] = address(this);
    underlyingAsset = new TokenERC721(
      address(this),
      NAME,
      SYMBOL,
      CONTRACT_URI,
      addrs,
      address(this),
      ROYALTY_RECIPIENT.addr,
      ROYALTY_BASE - ROYALTY_RATE,
      ROYALTY_RATE,
      address(this)
    );
    for (uint256 i; i < ALICE_INIT_SUPPLY; ++i) {
      underlyingAsset.mintTo(ALICE.addr, BASE_URI);
    }
    underlyingAsset.mintTo(BOB.addr, BASE_URI);
    for (uint256 i; i < ALICE_MORE_SUPPLY; ++i) {
      underlyingAsset.mintTo(ALICE.addr, BASE_URI);
    }

    implementation = new Migrated721();
    factory = new Factory();
    testContract = Migrated721(
      payable(
        factory.deployClone(
          address(implementation),
          abi.encodeWithSelector(
            Migrated721.initialize.selector,
            address(this),
            address(underlyingAsset),
            ROYALTY_RECIPIENT.addr,
            ROYALTY_RATE,
            MINTED_SUPPLY,
            NAME,
            SYMBOL,
            BASE_URI
          )
        )
      )
    );
  }

  function _approveFixture(address account) internal {
    vm.prank(ALICE.addr);
    testContract.approve(account, TARGET_TOKEN);
  }

  function _approveAllFixture(address account) internal {
    vm.prank(ALICE.addr);
    testContract.setApprovalForAll(account, true);
  }

  function _burnFixture() internal {
    vm.prank(ALICE.addr);
    testContract.burn(TARGET_TOKEN);
  }
}

// **************************************
// *****          FALLBACK          *****
// **************************************
contract Unit_fallback is Deployed {
  function test_fallback_receivesEth() public {
    uint256 initialBalance = address(testContract).balance;
    (bool success,) = payable(address(testContract)).call{value: 10}(DATA);
    assertTrue(success, "transfer failed");
    assertEq(address(testContract).balance, initialBalance + 10);
  }

  function test_receive_receivesEth() public {
    uint256 initialBalance = address(testContract).balance;
    (bool success,) = payable(address(testContract)).call{value: 10}("");
    assertTrue(success, "transfer failed");
    assertEq(address(testContract).balance, initialBalance + 10);
  }
}
// **************************************

// **************************************
// *****           PUBLIC           *****
// **************************************
// ***************
// * Migrated721 *
// ***************
contract Unit_burn is Deployed {
  function test_revertWhen_tokenDontExist() public {
    address operator = ALICE.addr;
    uint256 tokenId = NONEXISTANT_TOKEN;
    vm.prank(operator);
    vm.expectRevert();
    testContract.burn(tokenId);
  }

  function test_revertWhen_operator_isNotApproved() public {
    address operator = OPERATOR.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_CALLER_NOT_APPROVED.selector, operator, tokenId));
    testContract.burn(tokenId);
  }

  function test_revertWhen_token_isBurned() public {
    address operator = ALICE.addr;
    uint256 tokenId = TARGET_TOKEN;
    _burnFixture();
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_NONEXISTANT_TOKEN.selector, tokenId));
    testContract.burn(tokenId);
  }

  function test_emitTransferEventWhen_caller_isTokenOwner() public {
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Transfer(tokenOwner, address(0), tokenId);
    testContract.burn(tokenId);
    assertEq(testContract.balanceOf(tokenOwner), ALICE_SUPPLY - BURNED_SUPPLY, "invalid balance after burn");
  }

  function test_emitTransferEventWhen_caller_isIndividuallyApproved() public {
    address operator = OPERATOR.addr;
    address tokenOwner = ALICE.addr;
    uint256 tokenId = TARGET_TOKEN;
    _approveFixture(operator);
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Transfer(tokenOwner, address(0), tokenId);
    testContract.burn(tokenId);
    assertEq(testContract.balanceOf(tokenOwner), ALICE_SUPPLY - BURNED_SUPPLY, "invalid balance after burn");
  }

  function test_emitTransferEventWhen_caller_isApprovedForAll() public {
    address operator = OPERATOR.addr;
    address tokenOwner = ALICE.addr;
    uint256 tokenId = TARGET_TOKEN;
    _approveAllFixture(operator);
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Transfer(tokenOwner, address(0), tokenId);
    testContract.burn(tokenId);
    assertEq(testContract.balanceOf(tokenOwner), ALICE_SUPPLY - 1, "invalid sender balance");
  }
}
// ***************

// ***********
// * IERC721 *
// ***********
contract Unit_approve is Deployed {
  function test_revertWhen_tokenDontExist() public {
    address operator = ALICE.addr;
    address approvedAccount = OPERATOR.addr;
    uint256 tokenId = NONEXISTANT_TOKEN;
    vm.prank(operator);
    vm.expectRevert();
    testContract.approve(approvedAccount, tokenId);
  }

  function test_revertWhen_operator_isNotApproved() public {
    address operator = OPERATOR.addr;
    address approvedAccount = OPERATOR.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_CALLER_NOT_APPROVED.selector, operator, tokenId));
    testContract.approve(approvedAccount, tokenId);
  }

  function test_revertWhen_approvingTokenOwner() public {
    address operator = ALICE.addr;
    address approvedAccount = ALICE.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(IERC721.IERC721_INVALID_APPROVAL.selector);
    testContract.approve(approvedAccount, tokenId);
  }

  function test_revertWhen_token_isBurned() public {
    address operator = ALICE.addr;
    address approvedAccount = OPERATOR.addr;
    uint256 tokenId = TARGET_TOKEN;
    _burnFixture();
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_NONEXISTANT_TOKEN.selector, tokenId));
    testContract.approve(approvedAccount, tokenId);
  }

  function test_emitApprovalEventWhen_caller_isTokenOwner() public {
    address operator = ALICE.addr;
    address approvedAccount = OPERATOR.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Approval(operator, approvedAccount, tokenId);
    testContract.approve(approvedAccount, tokenId);
    assertEq(testContract.getApproved(tokenId), approvedAccount, "invalid approval");
  }

  function test_emitApprovalEventWhen_caller_isIndividuallyApproved() public {
    address operator = OPERATOR.addr;
    address approvedAccount = OPERATOR.addr;
    uint256 tokenId = TARGET_TOKEN;
    _approveFixture(approvedAccount);
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Approval(ALICE.addr, approvedAccount, tokenId);
    testContract.approve(approvedAccount, tokenId);
    assertEq(testContract.getApproved(tokenId), approvedAccount, "invalid approval");
  }

  function test_emitApprovalEventWhen_caller_isApprovedForAll() public {
    address operator = OPERATOR.addr;
    address approvedAccount = OPERATOR.addr;
    uint256 tokenId = TARGET_TOKEN;
    _approveAllFixture(approvedAccount);
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Approval(ALICE.addr, approvedAccount, tokenId);
    testContract.approve(approvedAccount, tokenId);
    assertEq(testContract.getApproved(tokenId), approvedAccount, "invalid approval");
  }
}

contract Unit_safeTransferFrom is Deployed {
  function test_revertWhen_tokenDontExist() public {
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = NONEXISTANT_TOKEN;
    vm.prank(operator);
    vm.expectRevert();
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_recipient_isAddressZero() public {
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = address(0);
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_INVALID_RECEIVER.selector, recipient));
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_from_dontOwnToken() public {
    address operator = ALICE.addr;
    address tokenOwner = OPERATOR.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(IERC721.IERC721_INVALID_TOKEN_OWNER.selector);
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_operator_isNotApproved() public {
    address operator = OPERATOR.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_CALLER_NOT_APPROVED.selector, operator, TARGET_TOKEN));
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_receiver_isNonReceiverContract() public {
    Mock_NonERC721Receiver receivingContract = new Mock_NonERC721Receiver();
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = address(receivingContract);
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_INVALID_RECEIVER.selector, recipient));
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_receiverContract_returns_unexpectedValue() public {
    Mock_ERC721Receiver receivingContract = new Mock_ERC721Receiver(
          RETVAL,
          Mock_ERC721Receiver.Error.None
        );
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = address(receivingContract);
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_INVALID_RECEIVER.selector, recipient));
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_receiverContract_reverts_withCustomError() public {
    Mock_ERC721Receiver receivingContract = new Mock_ERC721Receiver(
          type(IERC721Receiver).interfaceId,
          Mock_ERC721Receiver.Error.RevertWithError
        );
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = address(receivingContract);
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(Mock_ERC721Receiver.ERC721ReceiverError.selector);
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_receiverContract_reverts_withMessage() public {
    Mock_ERC721Receiver receivingContract = new Mock_ERC721Receiver(
          type(IERC721Receiver).interfaceId,
          Mock_ERC721Receiver.Error.RevertWithMessage
        );
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = address(receivingContract);
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert("Mock_ERC721Receiver: reverting");
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_receiverContract_reverts_withoutMessage() public {
    Mock_ERC721Receiver receivingContract = new Mock_ERC721Receiver(
          type(IERC721Receiver).interfaceId,
          Mock_ERC721Receiver.Error.RevertWithoutMessage
        );
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = address(receivingContract);
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert();
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_receiverContract_panics() public {
    Mock_ERC721Receiver receivingContract = new Mock_ERC721Receiver(
          type(IERC721Receiver).interfaceId,
          Mock_ERC721Receiver.Error.Panic
        );
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = address(receivingContract);
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x12));
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_token_isBurned() public {
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    _burnFixture();
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_NONEXISTANT_TOKEN.selector, tokenId));
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
  }

  function test_emitTransferEventWhen_caller_isTokenOwner() public {
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Transfer(tokenOwner, recipient, tokenId);
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
    assertEq(testContract.ownerOf(tokenId), recipient, "invalid token owner");
    assertEq(testContract.balanceOf(recipient), 1, "invalid recipient balance");
    assertEq(testContract.balanceOf(tokenOwner), ALICE_SUPPLY - 1, "invalid sender balance");
    assertEq(testContract.getApproved(tokenId), address(0), "invalid single approval");
  }

  function test_emitTransferEventWhen_caller_isIndividuallyApproved() public {
    address operator = OPERATOR.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    _approveFixture(operator);
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Transfer(tokenOwner, recipient, tokenId);
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
    assertEq(testContract.ownerOf(tokenId), recipient, "invalid token owner");
    assertEq(testContract.balanceOf(recipient), 1, "invalid recipient balance");
    assertEq(testContract.balanceOf(tokenOwner), ALICE_SUPPLY - 1, "invalid sender balance");
    assertEq(testContract.getApproved(tokenId), address(0), "invalid single approval");
  }

  function test_emitTransferEventWhen_caller_isApprovedForAll() public {
    address operator = OPERATOR.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    _approveAllFixture(operator);
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Transfer(tokenOwner, recipient, tokenId);
    testContract.safeTransferFrom(tokenOwner, recipient, tokenId);
    assertEq(testContract.ownerOf(tokenId), recipient, "invalid token owner");
    assertEq(testContract.balanceOf(recipient), 1, "invalid recipient balance");
    assertEq(testContract.balanceOf(tokenOwner), ALICE_SUPPLY - 1, "invalid sender balance");
    assertEq(testContract.getApproved(tokenId), address(0), "invalid single approval");
  }
}

contract Unit_setApprovalForAll is Deployed {
  function test_revertWhen_approvingSelf() public {
    address operator = ALICE.addr;
    address approvedAccount = ALICE.addr;
    bool isApproved = true;
    vm.prank(operator);
    vm.expectRevert(IERC721.IERC721_INVALID_APPROVAL.selector);
    testContract.setApprovalForAll(approvedAccount, isApproved);
    assertFalse(testContract.isApprovedForAll(operator, approvedAccount), "invalid approval");
  }

  function test_emitApprovalForAllWhen_approvingOther() public {
    address operator = ALICE.addr;
    address approvedAccount = OPERATOR.addr;
    bool isApproved = true;
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit ApprovalForAll(operator, approvedAccount, isApproved);
    testContract.setApprovalForAll(approvedAccount, isApproved);
    assertTrue(testContract.isApprovedForAll(operator, approvedAccount), "invalid approval");
  }

  function test_emitApprovalForAllWhen_disprovingOther() public {
    address operator = ALICE.addr;
    address approvedAccount = OPERATOR.addr;
    bool isApproved = false;
    _approveAllFixture(approvedAccount);
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit ApprovalForAll(operator, approvedAccount, isApproved);
    testContract.setApprovalForAll(approvedAccount, isApproved);
    assertFalse(testContract.isApprovedForAll(operator, approvedAccount), "invalid approval");
  }
}

contract Unit_transferFrom is Deployed {
  function test_revertWhen_tokenDontExist() public {
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = NONEXISTANT_TOKEN;
    vm.prank(operator);
    vm.expectRevert();
    testContract.transferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_recipient_isAddressZero() public {
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = address(0);
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_INVALID_RECEIVER.selector, recipient));
    testContract.transferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_from_dontOwnToken() public {
    address operator = ALICE.addr;
    address tokenOwner = OPERATOR.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(IERC721.IERC721_INVALID_TOKEN_OWNER.selector);
    testContract.transferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_operator_isNotApproved() public {
    address operator = OPERATOR.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_CALLER_NOT_APPROVED.selector, operator, tokenId));
    testContract.transferFrom(tokenOwner, recipient, tokenId);
  }

  function test_revertWhen_token_isBurned() public {
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    _burnFixture();
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_NONEXISTANT_TOKEN.selector, tokenId));
    testContract.transferFrom(tokenOwner, recipient, tokenId);
  }

  function test_emitTransferEventWhen_caller_isTokenOwner() public {
    address operator = ALICE.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Transfer(tokenOwner, recipient, tokenId);
    testContract.transferFrom(tokenOwner, recipient, tokenId);
    assertEq(testContract.ownerOf(tokenId), recipient, "invalid token owner");
    assertEq(testContract.balanceOf(recipient), 1, "invalid recipient balance");
    assertEq(testContract.balanceOf(tokenOwner), ALICE_SUPPLY - 1, "invalid sender balance");
    assertEq(testContract.getApproved(tokenId), address(0), "invalid single approval");
  }

  function test_emitTransferEventWhen_caller_isIndividuallyApproved() public {
    address operator = OPERATOR.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    _approveFixture(operator);
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Transfer(tokenOwner, recipient, tokenId);
    testContract.transferFrom(tokenOwner, recipient, tokenId);
    assertEq(testContract.ownerOf(tokenId), recipient, "invalid token owner");
    assertEq(testContract.balanceOf(recipient), 1, "invalid recipient balance");
    assertEq(testContract.balanceOf(tokenOwner), ALICE_SUPPLY - 1, "invalid sender balance");
    assertEq(testContract.getApproved(tokenId), address(0), "invalid single approval");
  }

  function test_emitTransferEventWhen_caller_isApprovedForAll() public {
    address operator = OPERATOR.addr;
    address tokenOwner = ALICE.addr;
    address recipient = RECIPIENT.addr;
    uint256 tokenId = TARGET_TOKEN;
    _approveAllFixture(operator);
    vm.prank(operator);
    vm.expectEmit(address(testContract));
    emit Transfer(tokenOwner, recipient, tokenId);
    testContract.transferFrom(tokenOwner, recipient, tokenId);
    assertEq(testContract.ownerOf(tokenId), recipient, "invalid token owner");
    assertEq(testContract.balanceOf(recipient), 1, "invalid recipient balance");
    assertEq(testContract.balanceOf(tokenOwner), ALICE_SUPPLY - 1, "invalid sender balance");
    assertEq(testContract.getApproved(tokenId), address(0), "invalid single approval");
  }
}
// ***********
// **************************************

// **************************************
// *****       CONTRACT OWNER       *****
// **************************************
// ***************
// * Migrated721 *
// ***************
contract Unit_withdraw is Deployed {
  function test_revertWhen_caller_isNotContractOwner() public {
    address operator = OPERATOR.addr;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC173.IERC173_NOT_OWNER.selector, operator));
    testContract.withdraw();
  }

  function test_revertWhen_contract_holdsNoEth() public {
    vm.expectRevert(Migrated721.ETHER_NO_BALANCE.selector);
    testContract.withdraw();
  }

  function test_revertWhen_caller_cantReceiveEth() public {
    vm.deal(address(testContract), 1 ether);
    vm.expectRevert(abi.encodeWithSelector(Migrated721.ETHER_TRANSFER_FAIL.selector, address(this), 1 ether));
    testContract.withdraw();
  }

  function test_withdraw_isSuccess() public {
    vm.deal(address(testContract), 1 ether);
    address operator = OPERATOR.addr;
    testContract.transferOwnership(operator);
    vm.prank(operator);
    testContract.withdraw();
    assertEq(address(OPERATOR.addr).balance, 100 ether + 1 ether, "invalid treasury balance");
    assertEq(address(testContract).balance, 0, "invalid contract balance");
  }
}
// ***************

// ***********
// * IERC173 *
// ***********
contract Unit_TransferOwnership is Deployed {
  function test_revertWhen_caller_isNotContractOwner() public {
    address operator = OPERATOR.addr;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC173.IERC173_NOT_OWNER.selector, operator));
    testContract.transferOwnership(operator);
  }

  function test_emitTransferOwnershipWhen_callerIsOwner() public {
    address newOwner = OPERATOR.addr;
    vm.expectEmit(address(testContract));
    emit OwnershipTransferred(address(this), newOwner);
    testContract.transferOwnership(newOwner);
    assertEq(testContract.owner(), newOwner, "invalid owner");
  }

  function test_emitTransferOwnershipWhen_renouncingOwnership() public {
    address newOwner = OPERATOR.addr;
    vm.expectEmit(address(testContract));
    emit OwnershipTransferred(address(this), newOwner);
    testContract.transferOwnership(newOwner);
    assertEq(testContract.owner(), newOwner, "invalid owner");
  }
}
// ***********

// ************
// * IERC2981 *
// ************
contract Unit_setRoyaltyInfo is Deployed {
  function test_revertWhen_caller_isNotContractOwner() public {
    address operator = OPERATOR.addr;
    address newRecipient = OPERATOR.addr;
    uint96 newRate = ROYALTY_RATE / 2;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC173.IERC173_NOT_OWNER.selector, operator));
    testContract.setRoyaltyInfo(newRecipient, newRate);
  }

  function test_revertWhen_royaltyRateIsHigherThanRoyaltyBase() public {
    address newRecipient = OPERATOR.addr;
    uint96 newRate = ROYALTY_BASE + 1;
    vm.expectRevert(IERC2981.IERC2981_INVALID_ROYALTIES.selector);
    testContract.setRoyaltyInfo(newRecipient, newRate);
  }

  function test_settingRoyalties_isSuccess() public {
    address newRecipient = OPERATOR.addr;
    uint96 newRate = ROYALTY_RATE / 2;
    uint256 tokenId = TARGET_TOKEN;
    uint256 price = 1 ether;
    address expectedRecipient = newRecipient;
    uint256 expectedAmount = price * newRate / ROYALTY_BASE;
    testContract.setRoyaltyInfo(newRecipient, newRate);
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }

  function test_removingRoyaltyRecipient() public {
    address newRecipient = address(0);
    uint96 newRate = ROYALTY_RATE / 2;
    uint256 tokenId = TARGET_TOKEN;
    uint256 price = 1 ether;
    address expectedRecipient = address(0);
    uint256 expectedAmount = 0;
    testContract.setRoyaltyInfo(newRecipient, newRate);
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }

  function test_removingRoyaltyRate() public {
    address newRecipient = OPERATOR.addr;
    uint96 newRate = 0;
    uint256 tokenId = TARGET_TOKEN;
    uint256 price = 1 ether;
    address expectedRecipient = address(0);
    uint256 expectedAmount = 0;
    testContract.setRoyaltyInfo(newRecipient, newRate);
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }
}

contract Fuzz_setRoyaltyInfo is Deployed {
  function test_settingRoyalties_isSuccess(uint96 newRate, uint256 price) public {
    address newRecipient = OPERATOR.addr;
    newRate = uint96(bound(newRate, 1, ROYALTY_BASE));
    uint256 tokenId = TARGET_TOKEN;
    price = bound(price, 100, 1e36);
    address expectedRecipient = newRecipient;
    uint256 expectedAmount = price * newRate / ROYALTY_BASE;
    testContract.setRoyaltyInfo(newRecipient, newRate);
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }
}
// ************

// *******************
// * IERC721Metadata *
// *******************
contract Unit_setBaseUri is Deployed {
  function test_revertWhen_caller_isNotContractOwner() public {
    address operator = OPERATOR.addr;
    string memory newBaseUri = NEW_BASE_URI;
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(IERC173.IERC173_NOT_OWNER.selector, operator));
    testContract.setBaseUri(newBaseUri);
  }

  function test_setBaseUri_isSuccess() public {
    string memory newBaseUri = NEW_BASE_URI;
    uint256 tokenId = TARGET_TOKEN;
    testContract.setBaseUri(newBaseUri);
    assertEq(
      keccak256(abi.encodePacked(testContract.tokenURI(tokenId))),
      keccak256(abi.encodePacked(newBaseUri, Strings.toString(tokenId))),
      "invalid uri"
    );
  }
}
// *******************

// ***********
// * IERC165 *
// ***********
contract Unit_supportsInterface is Deployed {
  function test_supportsExpectedInterfaces() public {
    for (uint256 i; i < INTERFACES.length; ++i) {
      assertTrue(testContract.supportsInterface(INTERFACES[i]), "invalid interface");
    }
  }
}
// ***********
// **************************************

// **************************************
// *****            VIEW            *****
// **************************************
// ***********
// * IERC173 *
// ***********
contract Unit_Owner is Deployed {
  function test_contractOwner_isCorrect() public {
    assertEq(testContract.owner(), address(this), "invalid owner");
  }
}
// ***********

// ***********
// * IERC721 *
// ***********
contract Unit_balanceOf is Deployed {
  function test_revertWhen_checkingBalanceOfZeroAddress() public {
    address tokenOwner = address(0);
    vm.expectRevert(IERC721.IERC721_INVALID_TOKEN_OWNER.selector);
    testContract.balanceOf(address(0));
  }

  function test_balanceOf_nonTokenOwner_isZero() public {
    address tokenOwner = OPERATOR.addr;
    assertEq(testContract.balanceOf(tokenOwner), 0, "invalide balance");
  }

  function test_balanceOf_tokenOwner_isAccurate() public {
    assertEq(testContract.balanceOf(ALICE.addr), ALICE_SUPPLY, "invalid ALICE.addr balance");
    assertEq(testContract.balanceOf(BOB.addr), BOB_SUPPLY, "invalid BOB.addr balance");
  }
}

contract Unit_getApproved is Deployed {
  function test_revertWhen_tokenDontExist() public {
    uint256 tokenId = NONEXISTANT_TOKEN;
    vm.expectRevert();
    testContract.getApproved(tokenId);
  }

  function test_revertWhen_token_isBurned() public {
    uint256 tokenId = TARGET_TOKEN;
    _burnFixture();
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_NONEXISTANT_TOKEN.selector, tokenId));
    testContract.getApproved(tokenId);
  }

  function test_individualApproval_isAddressZero() public {
    uint256 tokenId = TARGET_TOKEN;
    assertEq(testContract.getApproved(tokenId), address(0), "invalid approval");
  }
}

contract Unit_isApprovedForAll is Deployed {
  function test_approvalForAll_isFalse() public {
    address tokenOwner = ALICE.addr;
    address operator = OPERATOR.addr;
    assertFalse(testContract.isApprovedForAll(tokenOwner, operator), "invalid approval");
  }
}

contract Unit_ownerOf is Deployed {
  function test_revertWhen_tokenDontExist() public {
    uint256 tokenId = NONEXISTANT_TOKEN;
    vm.expectRevert();
    testContract.ownerOf(tokenId);
  }

  function test_revertWhen_token_isBurned() public {
    uint256 tokenId = TARGET_TOKEN;
    _burnFixture();
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_NONEXISTANT_TOKEN.selector, tokenId));
    testContract.ownerOf(tokenId);
  }

  function test_ownerOfExistingToken_isAccurate() public {
    assertEq(testContract.ownerOf(BOB_TOKEN), BOB.addr, "invalid owner");
    assertEq(testContract.ownerOf(TARGET_TOKEN), ALICE.addr, "invalid owner");
  }
}

contract Fuzz_ownerOf is Deployed {
  function test_ownerOfExistingToken_isAccurate(uint256 tokenId) public {
    vm.assume(tokenId < MINTED_SUPPLY);
    if (tokenId == BOB_TOKEN) {
      assertEq(testContract.ownerOf(tokenId), BOB.addr, "invalid owner");
    } else {
      assertEq(testContract.ownerOf(tokenId), ALICE.addr, "invalid owner");
    }
  }
}
// ***********

// *********************
// * IERC721Enumerable *
// *********************
contract Unit_tokenByIndex is Deployed {
  function test_revertWhen_indexDontExist() public {
    uint256 index = NONEXISTANT_INDEX;
    vm.expectRevert(abi.encodeWithSelector(IERC721Enumerable.IERC721Enumerable_INDEX_OUT_OF_BOUNDS.selector, index));
    testContract.tokenByIndex(index);
  }

  function test_tokenByIndex_isAccurate() public {
    uint256 index = TARGET_INDEX;
    assertEq(testContract.tokenByIndex(index), TARGET_TOKEN, "invalid index");
  }
}

contract Fuzz_TokenByIndex is Deployed {
  function test_tokenByIndex_isAccurate(uint256 index) public {
    vm.assume(index < MINTED_SUPPLY);
    assertEq(testContract.tokenByIndex(index), index, "invalid index");
  }
}

contract Unit_tokenOfOwnerByIndex is Deployed {
  function test_revertWhen_checkingBalanceOfZeroAddress() public {
    address tokenOwner = address(0);
    uint256 index = TARGET_INDEX;
    vm.expectRevert(IERC721.IERC721_INVALID_TOKEN_OWNER.selector);
    testContract.tokenOfOwnerByIndex(tokenOwner, index);
  }

  function test_revertWhen_indexDontExist() public {
    address tokenOwner = OPERATOR.addr;
    uint256 index = TARGET_INDEX;
    vm.expectRevert(
      abi.encodeWithSelector(IERC721Enumerable.IERC721Enumerable_OWNER_INDEX_OUT_OF_BOUNDS.selector, index)
    );
    testContract.tokenOfOwnerByIndex(tokenOwner, index);
  }

  function test_tokenOfOwnerByIndex_isAccurate() public {
    assertEq(testContract.tokenOfOwnerByIndex(BOB.addr, 0), BOB_TOKEN, "invalid token id");
    assertEq(testContract.tokenOfOwnerByIndex(ALICE.addr, TARGET_INDEX), TARGET_TOKEN, "invalid token id");
  }
}

contract Fuzz_TokenOfOwnerByIndex is Deployed {
  function test_tokenOfOwnerByIndex_isAccurate(uint256 index) public {
    vm.assume(index < MINTED_SUPPLY - BOB_SUPPLY);
    if (index < ALICE_INIT_SUPPLY) {
      assertEq(testContract.tokenOfOwnerByIndex(ALICE.addr, index), index, "invalid token id");
    } else {
      assertEq(testContract.tokenOfOwnerByIndex(ALICE.addr, index), index + BOB_SUPPLY, "invalid token id");
    }
  }
}

contract Unit_totalSupply is Deployed {
  function test_totalSupply_isAccurate() public {
    assertEq(testContract.totalSupply(), MINTED_SUPPLY, "invalid total supply");
  }

  function test_totalSupply_isAccurate_afterBurning() public {
    _burnFixture();
    assertEq(testContract.totalSupply(), MINTED_SUPPLY - BURNED_SUPPLY, "invalid total supply");
  }
}
// *********************

// *******************
// * IERC721Metadata *
// *******************
contract Unit_name is Deployed {
  function test_name_isAccurate() public {
    assertEq(testContract.name(), NAME, "invalid name");
  }
}

contract Unit_symbol is Deployed {
  function test_symbol_isAccurate() public {
    assertEq(testContract.symbol(), SYMBOL, "invalid ticker");
  }
}

contract Unit_tokenURI is Deployed {
  function test_revertWhen_tokenDontExist() public {
    uint256 tokenId = NONEXISTANT_TOKEN;
    vm.expectRevert();
    testContract.tokenURI(tokenId);
  }

  function test_revertWhen_token_isBurned() public {
    uint256 tokenId = TARGET_TOKEN;
    _burnFixture();
    vm.expectRevert(abi.encodeWithSelector(IERC721.IERC721_NONEXISTANT_TOKEN.selector, tokenId));
    testContract.tokenURI(tokenId);
  }

  function test_tokenUri_isAccurate() public {
    uint256 tokenId = TARGET_TOKEN;
    assertEq(
      keccak256(abi.encodePacked(testContract.tokenURI(tokenId))),
      keccak256(abi.encodePacked(BASE_URI, Strings.toString(tokenId))),
      "invalid uri"
    );
  }
}

contract Fuzz_tokenURI is Deployed {
  function test_tokenUri_isAccurate(uint256 tokenId) public {
    vm.assume(tokenId < MINTED_SUPPLY);
    assertEq(
      keccak256(abi.encodePacked(testContract.tokenURI(tokenId))),
      keccak256(abi.encodePacked(BASE_URI, Strings.toString(tokenId))),
      "invalid uri"
    );
  }
}
// *******************

// ************
// * IERC2981 *
// ************
contract Unit_royaltyInfo is Deployed {
  function test_noRoyaltiesWhen_priceIsZero() public {
    uint256 tokenId = TARGET_TOKEN;
    uint256 price = 0;
    address expectedRecipient = address(0);
    uint256 expectedAmount = 0;
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }

  function test_royaltyInfo_isAccurate() public {
    uint256 tokenId = TARGET_TOKEN;
    uint256 price = 1 ether;
    address expectedRecipient = ROYALTY_RECIPIENT.addr;
    uint256 expectedAmount = price * ROYALTY_RATE / ROYALTY_BASE;
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }
}

contract Fuzz_royaltyInfo is Deployed {
  function test_royaltyInfo_isAccurate(uint256 price) public {
    uint256 tokenId = TARGET_TOKEN;
    price = bound(price, 100, 1e36);
    address expectedRecipient = ROYALTY_RECIPIENT.addr;
    uint256 expectedAmount = price * ROYALTY_RATE / ROYALTY_BASE;
    (address recipient, uint256 royaltyAmount) = testContract.royaltyInfo(tokenId, price);
    assertEq(recipient, expectedRecipient, "invalid royalty recipient");
    assertEq(royaltyAmount, expectedAmount, "invalid royalty amount");
  }
}
// ************
// **************************************
