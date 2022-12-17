// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./ERC721id16.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @dev The extension of ERC721id16.
 * See {ERC721id16} for details on the id16 concept.
 *
 * Batch mint properties:
 * - Token ids are from 1 to totalSupply. totalSupply is set in the constructor.
 * - The ConsecutiveTransfer event for minting is emitted eagerly in the constructor.
 * - Initially all tokens belongs to a default owner. A default owner cannot be changed.
 *
 * Implementation uses controversial EIP 2309. So use it within your consideration.
 */
contract ERC721id16BatchMint is ERC721id16, IERC721Metadata {
    using Strings for uint256;

    /**
     * @dev Emitted when tokens in `fromTokenId` to `toTokenId`
     * (inclusive) is transferred from `from` to `to`, as defined in the
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309) standard.
     *
     * See {_mintERC2309} for more details.
     */
    event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed from, address indexed to);

    uint256 public immutable totalSupply;
    address public immutable defaultOwner;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    constructor(uint256 totalSupply_, address defaultOwner_, string memory name_, string memory symbol_)  {
        require(totalSupply_ > 0, "ERC721: nothing to mint");
        require(totalSupply_ <= type(uint16).max, "ERC721: max tokenId exceeded");
        require(defaultOwner_ != address(0), "ERC721: a default owner cannot be zero");

        totalSupply = totalSupply_;
        defaultOwner = defaultOwner_;

        _name = name_;
        _symbol = symbol_;

        List16Lib.list16SetLength(_walletSlotNum(defaultOwner_), uint16(totalSupply_));

        emit ConsecutiveTransfer(1, totalSupply_, address(0), defaultOwner_);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(tokenId > 0 && tokenId <= totalSupply, "ERC721: invalid token ID");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function tokenByIndex(uint256 index) external view returns (uint256) {
        require(index < totalSupply, "ERC721Enumerable: global index out of bounds");
        return index + 1;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view override returns (uint256 tokenId) {
        require(index < type(uint16).max, "ERC721: invalid index");
        tokenId = List16Lib.list16GetPos(_walletSlotNum(owner), uint16(index));
        if (tokenId == 0) {
            tokenId = index + 1;
        }
    }

    function getSpender() view external returns (address) {
        return _msgSender();
    }

    /**
     * @dev See {ERC721id16-_transfer}.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override virtual {
        uint256 owning = _owners[tokenId];
        uint256 transferCounter;
        address spender = _msgSender();

        // the structure of checks refers to OZ implementation
        if (owning == 0) {
            // the first transfer is for minting
            transferCounter = 1;

            require(tokenId > 0 && tokenId <= totalSupply, "ERC721: invalid token ID");
            // individual approvals fills _owners[] so no need to check here
            require(spender == defaultOwner || _operatorApprovals[defaultOwner][spender], "ERC721: caller is not token owner or approved");
            require(defaultOwner == from, "ERC721: transfer from incorrect owner");

            // initially tokenId n is placed on the position n-1
            uint16 enumerationIndex = uint16(tokenId - 1);
            (uint16 replacedTokenId, uint16 replacedPos) = List16Lib.list16RemovePos(_walletSlotNum(defaultOwner), enumerationIndex);
            if (enumerationIndex != replacedPos) {
                // if replacedTokenId is touched in enumeration for the first time, it has to be updated from zero
                if (replacedTokenId == 0) {
                    // initially tokenId n is placed on the position n-1
                    unchecked {
                        replacedTokenId = replacedPos + 1;
                    }
                    // 0x1 is a first transfer counter
                    _owners[replacedTokenId] = uint256(bytes32(bytes20(defaultOwner))) | (uint256(enumerationIndex) << 80) | 0x1;
                    // it is zero, it should be replacedTokenId
                    List16Lib.list16SetElt(_walletSlotNum(defaultOwner), enumerationIndex, replacedTokenId);
                } else {
                    _owners[replacedTokenId] = (_owners[replacedTokenId] & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF) | (uint256(enumerationIndex) << 80);
                }
            }
        } else {
            address owner;
            uint16 enumerationIndex;
            assembly {
                owner := shr(96, owning)
                enumerationIndex := shr(240, shl(160, owning))
            }
            transferCounter = owning % 2**80;

            if (spender != owner) {
                if (!_operatorApprovals[owner][spender]) {
                    // sender == approved && current transferCounter == approved transferCounter
                    require(_tokenApprovals[tokenId] == uint256(bytes32(bytes20(spender))) | transferCounter, "ERC721: caller is not token owner or approved");
                }
            }
            require(owner == from, "ERC721: transfer from incorrect owner");

            (uint16 replacedTokenId, uint16 replacedPos) = List16Lib.list16RemovePos(_walletSlotNum(from), enumerationIndex);
            // if the token was the last on the owner's list, then there is not need to change an index of additional token
            if (enumerationIndex != replacedPos) {
                // if replacedTokenId is touched in enumeration for the first time, it has to be updated from zero
                if (replacedTokenId == 0) {
                    // initially tokenId n is placed on the position n-1
                    unchecked {
                        replacedTokenId = replacedPos + 1;
                    }
                    // 0x1 is a first transfer counter, and it must be a defaultOwner
                    _owners[replacedTokenId] = uint256(bytes32(bytes20(defaultOwner))) | (uint256(enumerationIndex) << 80) | 0x1;
                    // it is zero, it should be replacedTokenId
                    List16Lib.list16SetElt(_walletSlotNum(defaultOwner), enumerationIndex, replacedTokenId);
                } else {
                    _owners[replacedTokenId] = (_owners[replacedTokenId] & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF) | (uint256(enumerationIndex) << 80);
                }
            }
            // this is in the case of crazy situation with over 2**80 token transfers
            if (transferCounter == 0xFFFFFFFFFFFFFFFFFFFF) {
                transferCounter = 0;
                delete _tokenApprovals[tokenId];
            }
        }

        require(to != address(0), "ERC721: transfer to the zero address");

        uint16 _newEnumerationIndex = List16Lib.list16AddElt(_walletSlotNum(to), uint16(tokenId));
        assembly {
            owning := or(or(shl(96, to), shl(80, _newEnumerationIndex)), add(transferCounter, 1))
        }
        _owners[tokenId] = owning;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev See {ERC721id16-ownerOf}.
     */
    function ownerOf(uint256 tokenId) external view override(ERC721id16, IERC721) returns (address) {
        uint256 owning = _owners[tokenId];
        if (owning != 0) {
            return address(bytes20(bytes32(owning)));
        }
        require(tokenId > 0 && tokenId <= totalSupply, "ERC721: invalid token ID");
        return defaultOwner;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) external virtual override(ERC721id16, IERC721) {
        uint256 owning = _owners[tokenId];
        address owner;
        uint256 transferCounter;
        // if an approval is before a first transfer (_owners[] is zero), it fills data structures
        if (owning == 0) {
            transferCounter = 1;
            owner = defaultOwner;
            require(tokenId > 0 && tokenId <= totalSupply, "ERC721: invalid token ID");
            uint16 enumerationIndex = uint16(tokenId - 1);
            // 0x1 is a first transfer counter
            _owners[tokenId] = uint256(bytes32(bytes20(defaultOwner))) | (enumerationIndex << 80) | 0x1;
            List16Lib.list16SetElt(_walletSlotNum(defaultOwner), enumerationIndex, uint16(tokenId));
        } else {
            transferCounter = owning % 2**80;
            assembly {
                owner := shr(96, owning)
            }
        }
        address operator = _msgSender();

        require(to != owner, "ERC721: approval to current owner");
        require(
            operator == owner || _operatorApprovals[owner][operator],
            "ERC721: approve caller is not token owner or approved for all"
        );

        unchecked {
            _tokenApprovals[tokenId] = uint256(bytes32(bytes20(to))) + transferCounter;
        }
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721id16, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}