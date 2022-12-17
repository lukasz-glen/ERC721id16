// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ERC721id16.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @dev The extension of ERC721id16.
 * See {ERC721id16} for details on the id16 concept.
 *
 * Lazy mint properties:
 * - The initial transfer (a first transfer of a token) is gas efficient.
 * - Token ids are from 1 to totalSupply. totalSupply is set in the constructor.
 * - The Transfer event for minting is emitted lazily in an initial transfer.
 * - Initially all tokens belongs to a default owner. A default owner can be changed.
 * - ownerOf() returns a default owner before an initial transfer.
 * - Tokens cannot be approved before an initial transfer.
 * - All tokens can be iterated globally anytime.
 * - Tokens before their initial transfers are not accessible by tokenOfOwnerByIndex() for a default owner.
 */
contract ERC721id16LazyMint is ERC721id16, IERC721Metadata {
    using Strings for uint256;

    event NewDefaultOwner(address indexed oldDefaultOwner, address indexed newDefaultOwner);

    uint256 public immutable totalSupply;
    address public defaultOwner;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    constructor(uint256 totalSupply_, string memory name_, string memory symbol_)  {
        require(totalSupply_ > 0, "ERC721: nothing to mint");
        require(totalSupply_ <= type(uint16).max, "ERC721: max tokenId exceeded");

        totalSupply = totalSupply_;
        defaultOwner = _msgSender();

        _name = name_;
        _symbol = symbol_;
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

    function transferDefaultOwner(address newDefaultOwner) external {
        require(newDefaultOwner != address(0), "ERC721: non zero default owner");
        require(_msgSender() == defaultOwner, "ERC721: caller is not default owner");

        emit NewDefaultOwner(defaultOwner, newDefaultOwner);
        defaultOwner = newDefaultOwner;
    }

    function tokenByIndex(uint256 index) external view returns (uint256) {
        require(index < totalSupply, "ERC721Enumerable: global index out of bounds");
        return index + 1;
    }

    function safeMint(
        uint256 tokenId,
        bytes memory data
    ) external virtual {
        require(tokenId > 0 && tokenId <= totalSupply, "ERC721: invalid token ID");
        address to = _msgSender();
        require(to == defaultOwner, "ERC721: caller is not default owner");

        // this call tests if the token is minted
        _safeMint(to, tokenId, data);
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
            // lazy initial transfer for minting
            transferCounter = 1;

            require(tokenId > 0 && tokenId <= totalSupply, "ERC721: invalid token ID");
            address defaultOwner_ = defaultOwner;
            // individual approvals are not supported for tokens to be lazy minted
            require(spender == defaultOwner_ || _operatorApprovals[defaultOwner_][spender], "ERC721: caller is not token owner or approved");
            require(defaultOwner_ == from, "ERC721: transfer from incorrect owner");

            // lazy event for minting
            emit Transfer(address(0), defaultOwner_, tokenId);
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
                _owners[replacedTokenId] = (_owners[replacedTokenId] & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF) | (uint256(enumerationIndex) << 80);
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
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721id16, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}