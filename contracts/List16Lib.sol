// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library List16Lib {

    function list16Length(uint256 list) internal view returns (uint16 length) {
        assembly {
            length := and(sload(list), 0x000000000000000000000000000000000000000000000000000000000000FFFF)
        }
    }

    function list16SetLength(uint256 list, uint16 newLength) internal {
        assembly {
            let firstSlot := sload(list)
            let length := and(firstSlot, 0x000000000000000000000000000000000000000000000000000000000000FFFF)
            if lt(newLength, length) {
                mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(4, 32)
                mstore(36, 22)
                mstore(68, "List16Lib: setLength A")
                revert(0, 100)
            }
            firstSlot := or(newLength, and(firstSlot, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000))
            sstore(list, firstSlot)
        }
    }

    function list16GetPos(uint256 list, uint16 pos) internal view returns (uint16 elt) {
        assembly {
            let firstSlot := sload(list)
            let length := and(firstSlot, 0x000000000000000000000000000000000000000000000000000000000000FFFF)
            let realPos := add(pos, 1)
            if gt(realPos, length) {
                mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(4, 32)
                mstore(36, 19)
                mstore(68, "List16Lib: getPos A")
                revert(0, 100)
            }
            let eltSlotNum := div(realPos, 0x10)
            let shiftBits := mul(mod(realPos, 0x10), 0x10)
            switch eltSlotNum
            case 0 {
                elt := shr(shiftBits, and(firstSlot, shl(shiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF)))
            }
            default {
                let eltSlot := sload(add(list, eltSlotNum))
                elt := shr(shiftBits, and(eltSlot, shl(shiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF)))
            }
        }
    }

    function list16RemovePos(uint256 list, uint16 pos) internal returns (uint16 replacedElt, uint16 replacedPos) {
        assembly {
            let firstSlot := sload(list)
            let realLastPos := and(firstSlot, 0x000000000000000000000000000000000000000000000000000000000000FFFF)
            replacedPos := sub(realLastPos, 1)
            let realPos := add(pos, 1)
            if gt(realPos, realLastPos) {
                mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(4, 32)
                mstore(36, 22)
                mstore(68, "List16Lib: removePos A")
                revert(0, 100)
            }

            let lastSlotNum := div(realLastPos, 0x10)
            let lastSlot
            switch lastSlotNum
            case 0 {
                lastSlot := firstSlot
            }
            default {
                lastSlot := sload(add(list, lastSlotNum))
            }

            let shiftBits := mul(mod(realLastPos, 0x10), 0x10)
            replacedElt := shr(shiftBits, and(lastSlot, shl(shiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF)))
            if lt(realPos, realLastPos) {
                let replaceSlotNum := div(realPos, 0x10)
                let replaceShiftBits := mul(mod(realPos, 0x10), 0x10)
                if iszero(replaceSlotNum) {
                    firstSlot := or(and(firstSlot, not(shl(replaceShiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF))), shl(replaceShiftBits, replacedElt))
                }
                if and(gt(replaceSlotNum, 0), lt(replaceSlotNum, lastSlotNum)) {
                    let replaceSlot := sload(add(list, replaceSlotNum))
                    replaceSlot := or(and(replaceSlot, not(shl(replaceShiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF))), shl(replaceShiftBits, replacedElt))
                    sstore(add(list, replaceSlotNum), replaceSlot)
                }
                if and(gt(replaceSlotNum, 0), eq(replaceSlotNum, lastSlotNum)) {
                    lastSlot := or(and(lastSlot, not(shl(replaceShiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF))), shl(replaceShiftBits, replacedElt))
                }
            }

            switch lastSlotNum
            case 0 {
                firstSlot := and(firstSlot, not(shl(shiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF)))
            }
            default {
                lastSlot := and(lastSlot, not(shl(shiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF)))
                sstore(add(list, lastSlotNum), lastSlot)
            }

            sstore(list, sub(firstSlot, 1))
        }
    }

    function list16AddElt(uint256 list, uint16 elt) internal returns (uint16 newPos) {
        assembly {
            let firstSlot := sload(list)
            newPos := and(firstSlot, 0x000000000000000000000000000000000000000000000000000000000000FFFF)
            if eq(newPos, 0x000000000000000000000000000000000000000000000000000000000000FFFF) {
                revert(0, 0)
            }
            let realPos := add(newPos, 1)
            if lt(realPos, 0x10) {
                firstSlot := or(firstSlot, shl(mul(realPos, 0x10), elt))
            }
            sstore(list, add(firstSlot, 1))
            if gt(realPos, 0x0F) {
                let s := add(list, div(realPos, 0x10))
                let lastSlot := sload(s)
                lastSlot := or(lastSlot, shl(mul(mod(realPos, 0x10), 0x10), elt))
                sstore(s, lastSlot)
            }
        }
    }

    /**
     * @dev Replaces an element at a position pos in a list list.
     * New value is elt, a replaced value is returned as replacedElt.
     *
     * Warning! There is no length check. But pos cannot exceed uint16.
     *
     * @param list List16 slot number
     * @param pos a position
     * @param elt new value
     * @return replacedElt previous value
     */
    function list16SetElt(uint256 list, uint16 pos, uint16 elt) internal returns (uint16 replacedElt) {
        assembly {
            let realPos := add(pos, 1)
            let replaceSlotNum := div(realPos, 0x10)
            let replaceShiftBits := mul(mod(realPos, 0x10), 0x10)
            let replaceSlot := sload(add(list, replaceSlotNum))
            replacedElt := shr(replaceShiftBits, and(replaceSlot, shl(replaceShiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF)))
            replaceSlot := or(and(replaceSlot, not(shl(replaceShiftBits, 0x000000000000000000000000000000000000000000000000000000000000FFFF))), shl(replaceShiftBits, elt))
            sstore(add(list, replaceSlotNum), replaceSlot)
        }
    }

}