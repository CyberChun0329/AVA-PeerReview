// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVATransitionMatrix} from "../script/AVATransitionMatrix.s.sol";

contract M13TransitionMatrixExecutionTest {
    function testM131RegistrationRowsMatchKernelExecution() public {
        _assertRowsMatchKernel(0, 8);
    }

    function testM131ReviewAndGenericRowsMatchKernelExecution() public {
        _assertRowsMatchKernel(9, 19);
    }

    function testM131ChallengeRowsMatchKernelExecution() public {
        _assertRowsMatchKernel(20, 28);
    }

    function testM131RestorationRowsMatchKernelExecution() public {
        _assertRowsMatchKernel(29, 34);
    }

    function _assertRowsMatchKernel(uint256 firstRow, uint256 lastRow) internal {
        AVATransitionMatrix matrix = new AVATransitionMatrix();
        require(matrix.rowCount() == 35, "unexpected matrix row count");
        for (uint256 rowId = firstRow; rowId <= lastRow; rowId++) {
            require(
                keccak256(bytes(matrix.executeRowString(rowId))) == keccak256(bytes(matrix.expectedRowString(rowId))),
                "matrix row does not match kernel execution"
            );
        }
    }
}
