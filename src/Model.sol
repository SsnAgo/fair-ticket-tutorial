// SPDX-License-Identifier: MIT
// src/Model.sol
pragma solidity ^0.8.29;

// Project struct
struct Project {
    // id 合约中递增的项目id
    uint256 id;
    // fingerprint 由后端生成，存在数据库里，在创建项目时传入，为了建立数据库与合约中的项目的关联
    bytes32 fingerprint;
    // owner 项目的拥有者，可以进行状态修改
    address owner;
    // totalSupply 项目的票数供应
    uint256 totalSupply;
    // projectStatus 项目当前状态
    ProjectStatus projectStatus;
    // merkleRoot 项目的merkleRoot，在抽票完成后，根据中奖者构建Merkle树进行生成
    bytes32 merkleRoot;
}

// projectStatus 项目状态
enum ProjectStatus {
    NotStart,
    InProgress,
    Finished
}

// Participant 参与者的信息 记录地址以及设置的幸运数字
struct Participant {
    address addr;
    uint256 luckyNum;
}

// LotteryResult 记录项目的抽票依据
struct LotteryResult {
    uint256 projectId;
    // magicNumber 链上随机数，可使用ChainLink的VRF进行可靠随机数生成
    uint256 magicNumber;
}
