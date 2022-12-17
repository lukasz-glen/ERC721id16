// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./List16Lib.sol";

/**
 * @dev
 * Gas efficient implementation of ERC721 and ERC721Enumerable.
 *
 * Token ids are limited to uint16 range, it means there can be ~64k nfts.
 * The contract is abstract, totalSupply() and tokenByIndex() and not implemented as they may depend on minting.
 *
 * Sources of gas saving:
 * - lists of owned tokens are compated with List16
 * - enumeration indexes are appended to _owners
 * - _tokenApprovals are not cleared in _transfer() thanks to tracking transferCounter.
 *
 * It differs from OZ implementation - storage variables are internal and
 * there is no _beforeTokenTransfer() or _afterTokenTransfer().
 * And permission checks are moved into _transfer() function.
 * But the order of checks and the revert messages are almost the same.
 */
abstract contract ERC721id16 is Context, IERC721, IERC721Enumerable {
    using Address for address;

    // a slot contains compacted [address owner, uint16 enumerationIndex, uint80 transferCounter]
    mapping(uint256 => uint256) internal _owners;
    // it is a pointer to List16
    mapping(address => uint256) internal _wallets;
    // a slot contains compacted [address approved, uint16 zeros, uint80 transferCounter]
    // if transferCounter is different than current token's transferCounter, then the approval is invalid
    mapping(uint256 => uint256) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;


    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) external view override virtual returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return List16Lib.list16Length(_walletSlotNum(owner));
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view virtual returns (uint256) {
        require(index < type(uint16).max, "ERC721: invalid index");
        return List16Lib.list16GetPos(_walletSlotNum(owner), uint16(index));
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) external view override virtual returns (address) {
        uint256 owning = _owners[tokenId];
        require(owning != 0, "ERC721: invalid token ID");
        return address(bytes20(bytes32(owning)));
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override {
        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, ""), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) external virtual override {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     * It is checked if the send has a permission to transfer the token.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        uint256 owning = _owners[tokenId];
        address owner;
        uint16 enumerationIndex;
        uint256 transferCounter = owning % 2**80;
        assembly {
            owner := shr(96, owning)
            enumerationIndex := shr(240, shl(160, owning))
        }
        address spender = _msgSender();

        // the structure of checkes refers to OZ implementation
        if (spender != owner) {
            if (!_operatorApprovals[owner][spender]) {
                require(owning != 0, "ERC721: invalid token ID");
                // sender == approved && current transferCounter == approved transferCounter
                require(_tokenApprovals[tokenId] == uint256(bytes32(bytes20(spender))) | transferCounter, "ERC721: caller is not token owner or approved");
            } else {
                require(owning != 0, "ERC721: invalid token ID");
            }
        } else {
            require(owning != 0, "ERC721: invalid token ID");
        }
        require(owner == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        (uint16 replacedTokenId, uint16 replacedPos) = List16Lib.list16RemovePos(_walletSlotNum(from), enumerationIndex);
        // if the token was the last on the owner's list, then there is not need to change an index of additional token
        if (enumerationIndex != replacedPos) {
            _owners[replacedTokenId] = (_owners[replacedTokenId] & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF) | (uint256(enumerationIndex) << 80);
        }
        uint16 _newEnumerationIndex = List16Lib.list16AddElt(_walletSlotNum(to), uint16(tokenId));
        // this is in the case of crazy situation with over 2**80 token transfers
        if (transferCounter == 0xFFFFFFFFFFFFFFFFFFFF) {
            transferCounter = 0;
            delete _tokenApprovals[tokenId];
        }
        assembly {
            owning := or(or(shl(96, to), shl(80, _newEnumerationIndex)), add(transferCounter, 1))
        }
        _owners[tokenId] = owning;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     * TokenId must meet uint16 range.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(_owners[tokenId] == 0 , "ERC721: token already minted");
        // tokenId must meet uint16 range
        require(tokenId <= type(uint16).max, "ERC721: invalid token ID");

        // it is uint16 actually
        uint256 _newEnumerationIndex = List16Lib.list16AddElt(_walletSlotNum(to), uint16(tokenId));
        // + 1 is the initial transferCounter
        unchecked {
            _owners[tokenId] = uint256(bytes32(bytes20(to))) + (_newEnumerationIndex << 80) + 1;
        }

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        uint256 owning = _owners[tokenId];
        address owner;
        uint16 enumerationIndex;
        assembly {
            owner := shr(96, owning)
            enumerationIndex := shr(240, shl(160, owning))
        }

        require(owning != 0, "ERC721: invalid token ID");

        (uint16 replacedTokenId, uint16 replacedPos) = List16Lib.list16RemovePos(_walletSlotNum(owner), enumerationIndex);
        if (enumerationIndex != replacedPos) {
            _owners[replacedTokenId] = (_owners[replacedTokenId] & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF) | (uint256(enumerationIndex) << 80);
        }
        // Clear approval
        delete _tokenApprovals[tokenId];
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) external virtual override {
        uint256 owning = _owners[tokenId];
        address owner;
        uint256 transferCounter = owning % 2**80;
        assembly {
            owner := shr(96, owning)
        }
        address operator = _msgSender();

        require(owning != 0, "ERC721: invalid token ID");
        require(to != owner, "ERC721: approval to current owner");
        require(
            operator == owner || _operatorApprovals[owner][operator],
            "ERC721: approve caller is not token owner or approved for all"
        );

        _tokenApprovals[tokenId] = uint256(bytes32(bytes20(to))) + transferCounter;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external override {
        address owner = _msgSender();
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) external view override returns (address) {
        uint256 owning = _owners[tokenId];
        require(owning != 0, "ERC721: invalid token ID");

        uint256 tokenApproval = _tokenApprovals[tokenId];

        return owning % 2**80 == tokenApproval % 2**80 ? address(bytes20(bytes32(tokenApproval))) : address(0);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function _walletSlotNum(address user) internal pure returns (uint256 walletSlotNum) {
        assembly {
            mstore(0, user)
            mstore(0x20, _wallets.slot)
            walletSlotNum := keccak256(0, 0x40)
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view override virtual returns (bool) {
        return interfaceId == type(IERC721).interfaceId
            || interfaceId == type(IERC721Enumerable).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }
}