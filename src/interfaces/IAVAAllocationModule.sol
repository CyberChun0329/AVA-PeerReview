// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAllocationAdapter} from "./IAllocationAdapter.sol";
import {IRuleModuleIdentity} from "./IRuleModuleIdentity.sol";

interface IAVAAllocationModule is IAllocationAdapter, IRuleModuleIdentity {}
