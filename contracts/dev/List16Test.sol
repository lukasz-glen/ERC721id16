// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../List16Lib.sol";

contract List16Test {
    using List16Lib for uint256;

    uint256 private list; // slot 0

    function length() external view returns (uint256) {
        return uint256(0).list16Length();
    }

    function setLength(uint256 newLength) external {
        uint256(0).list16SetLength(uint16(newLength));
    }

    function add(uint256 elt) external returns (uint256) {
        return uint256(0).list16AddElt(uint16(elt));
    }

    function addAndTestPos(uint256 elt, uint256 expectedPos) external {
        uint256 pos = uint256(0).list16AddElt(uint16(elt));
        require(pos == expectedPos, "List16Test: invalid pos");
    }

    function remove(uint256 pos) external {
        uint256(0).list16RemovePos(uint16(pos));
    }

    function get(uint256 pos) external view returns (uint256) {
        return uint256(0).list16GetPos(uint16(pos));
    }

    function set(uint256 pos, uint256 elt) external returns (uint256) {
        return uint256(0).list16SetElt(uint16(pos), uint16(elt));
    }
}