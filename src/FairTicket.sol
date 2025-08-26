// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Project, Participant, LotteryResult, ProjectStatus} from "./Model.sol";
import {Ownable} from "@openzeppelin/contracts//access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts//utils/cryptography/MerkleProof.sol";

// 使用openzeppelin封装的Ownable合约进行合约的权限控制。contract XX is YY 相当于XX合约继承了YY合约的一些属性和功能，可以在XX合约中直接使用。
contract FairTicket is Ownable {
    //// State Variables ////
    uint256 public s_globalId;
    mapping(uint256 => Project) public s_pid2project;
    mapping(uint256 => Participant[]) public s_projectid_participants;
    mapping(uint256 => mapping(address => Participant))
        public s_projectid_paddr_participant;
    mapping(uint256 => LotteryResult) public s_projectid_lottery;

    //// Events ////
    event ProjectCreated(
        uint256 indexed projectId,
        bytes32 indexed fingerprint
    );
    event ProjectStarted(uint256 indexed projectId);
    event ProjectFinished(uint256 indexed projectId);
    event MagicNumberPublished(uint256 indexed projectId, uint256 magicNumber);

    //// Errors ////
    error ProjectNotFound();
    error ProjectAlreadyStarted();
    error ProjectNotInProgress();
    error ProjectNotFinished();
    error TotalSupplyZero();
    error OnlyProjectOwner();
    error MerkleRootAlreadySet();
    error OffsetOutOfBounds();
    error MerkleProofInvalid(
        uint256 projectId,
        address sender,
        bytes32 self,
        bytes32[] proof
    );

    // 继承了Ownable合约要初始化。这里将合约的创建者设置为该合约的owner。
    constructor(uint256 _globalId) Ownable(msg.sender) {
        s_globalId = _globalId;
    }

    //// Modifiers ////
    // 项目存在验证修饰器
    modifier projectExist(uint256 _projectId) {
        if (s_pid2project[_projectId].id == 0) revert ProjectNotFound();
        _;
    }

    // 项目所有者验证修饰器
    modifier projectOwnerOnly(uint256 _projectId) {
        if (s_pid2project[_projectId].owner != msg.sender)
            revert OnlyProjectOwner();
        _;
    }

    // 项目进行中验证修饰器
    modifier projectInProgress(uint256 _projectId) {
        if (s_pid2project[_projectId].projectStatus != ProjectStatus.InProgress)
            revert ProjectNotInProgress();
        _;
    }

    // 项目结束验证修饰器
    modifier projectFinished(uint256 _projectId) {
        if (s_pid2project[_projectId].projectStatus != ProjectStatus.Finished)
            revert ProjectNotFinished();
        _;
    }

    //// Functions ////

    // 创建项目函数
    // 这里使用了onlyOwner修饰器，保证只有合约所有者可以执行该函数 这个onlyOwner修饰器是来自openzeppelin的Ownable.sol
    function createProject(
        bytes32 _fingerprint,
        address _owner,
        uint256 _totalSupply
    ) public onlyOwner {
        if (_totalSupply == 0) revert TotalSupplyZero();
        // 创建新项目
        Project memory newProject = Project({
            id: s_globalId,
            fingerprint: _fingerprint,
            owner: _owner,
            totalSupply: _totalSupply,
            projectStatus: ProjectStatus.NotStart,
            merkleRoot: bytes32(0)
        });
        // 将新项目信息存储到mappings中 并且将全局项目id+1
        s_pid2project[newProject.id] = newProject;
        s_globalId += 1;
        // 触发项目创建事件
        emit ProjectCreated(newProject.id, _fingerprint);
    }

    // 参与项目函数
    function participate(
        uint256 _projectId,
        address _addr,
        uint256 _luckyNum
    ) public projectExist(_projectId) projectInProgress(_projectId) {
        Participant memory newParticipant = Participant({
            addr: _addr,
            luckyNum: _luckyNum
        });
        s_projectid_participants[_projectId].push(newParticipant);
        s_projectid_paddr_participant[_projectId][_addr] = newParticipant;
    }

    // 开始项目函数
    // 这里使用了ProjectExist和onlyOwner修饰器
    function startProject(
        uint256 _projectId
    ) public projectExist(_projectId) onlyOwner {
        if (s_pid2project[_projectId].projectStatus != ProjectStatus.NotStart)
            revert ProjectAlreadyStarted();
        // 将项目状态设置为进行中
        s_pid2project[_projectId].projectStatus = ProjectStatus.InProgress;
        // 触发项目开始事件
        emit ProjectStarted(_projectId);
    }

    // 结束项目函数
    // 这里使用了ProjectExist和onlyOwner修饰器
    function finishProject(
        uint256 _projectId
    ) public onlyOwner projectExist(_projectId) {
        if (s_pid2project[_projectId].projectStatus != ProjectStatus.InProgress)
            revert ProjectNotInProgress();
        // 将项目状态设置为结束
        s_pid2project[_projectId].projectStatus = ProjectStatus.Finished;
        // 触发项目结束事件
        emit ProjectFinished(_projectId);
    }

    // 抽奖函数
    // 这里使用了ProjectExist和onlyOwner,projectFinished修饰器
    function lottery(
        uint256 _projectId
    ) public onlyOwner projectExist(_projectId) projectFinished(_projectId) {
        // 生成随机数
        uint256 magicNumber = SimpleMock.simpleVRF();
        // 创建抽奖结果
        LotteryResult memory result = LotteryResult({
            projectId: _projectId,
            magicNumber: magicNumber
        });
        // 将抽奖结果存储到mappings中
        s_projectid_lottery[_projectId] = result;
        // 触发抽奖结果发布事件
        emit MagicNumberPublished(_projectId, magicNumber);
    }

    // 设置MerkleRoot函数
    // 这里使用了onlyOwner修饰器，保证只有合约所有者可以执行该函数
    function SetMerkleRoot(
        uint256 _projectId,
        bytes32 _merkleRoot
    ) public onlyOwner {
        if (s_pid2project[_projectId].merkleRoot != bytes32(0))
            revert MerkleRootAlreadySet();
        // 设置MerkleRoot
        s_pid2project[_projectId].merkleRoot = _merkleRoot;
    }

    // 验证MerkleProof函数
    function verifyMerkleProof(
        uint256 _prjectId,
        bytes32[] memory proof
    ) public view returns (bool) {
        // 获取当前调用者的地址
        // address是一个bytes20类型 而keccak256的输入参数是bytes32类型
        // 因此需要abi.encodePacked 将msg.sender打包成bytes32类型 然后使用keccak256计算哈希值
        bytes32 self = keccak256(abi.encodePacked(msg.sender));
        // 验证MerkleProof 使用的是openzeppelin的MerkleProof库
        bool result = MerkleProof.verify(
            proof,
            s_pid2project[_prjectId].merkleRoot,
            self
        );

        if (!result) {
            revert MerkleProofInvalid(_prjectId, msg.sender, self, proof);
        }
        return result;
    }

    ///// Getters /////
    // 这里的Getters虽然可能某些函数不被业务需要 但如果不返回 在使用abi编译成go文件时，可能会缺失某些结构体

    // 分页获取参与者的函数
    // 参与者或许会很多，受到节点，网络等各种限制，不可能一次返回项目的所有参与者，所以需要分页获取
    function getProjectParticipants(
        uint256 _projectId,
        uint256 _offset,
        uint256 _limit
    ) public view returns (Participant[] memory) {
        uint256 totalParticipants = s_projectid_participants[_projectId].length;
        // 确保 offset 有效
        if (_offset >= totalParticipants) revert OffsetOutOfBounds();
        // 计算实际要返回的数量
        uint256 actualLimit = _limit;
        if (_offset + _limit > totalParticipants) {
            actualLimit = totalParticipants - _offset;
        }
        // 创建结果数组
        Participant[] memory result = new Participant[](actualLimit);
        for (uint256 i = 0; i < actualLimit; i++) {
            result[i] = s_projectid_participants[_projectId][_offset + i];
        }
        return result;
    }

    function getProjectInfo(
        uint256 _projectId
    ) public view returns (Project memory) {
        return s_pid2project[_projectId];
    }

    function getProjectStatus(
        uint256 _projectId
    ) public view returns (ProjectStatus) {
        return s_pid2project[_projectId].projectStatus;
    }

    function getLotteryResult(
        uint256 _projectId
    ) public view returns (LotteryResult memory) {
        return s_projectid_lottery[_projectId];
    }

    function getParticipantInfo(
        uint256 _projectId,
        address _addr
    ) public view returns (Participant memory) {
        return s_projectid_paddr_participant[_projectId][_addr];
    }

    function getProjectParticipantsAmount(
        uint256 _projectId
    ) public view returns (uint256) {
        return s_projectid_participants[_projectId].length;
    }

    function getMagicNumber(uint256 _projectId) public view returns (uint256) {
        return s_projectid_lottery[_projectId].magicNumber;
    }
}

// 一个简单的mock库，用于生成随机数
// 实际中应该调用链上合约的随机数生成函数，为了简单，这里就不介绍Chainlink VRF相关知识，也不打算编写VRF的Mock合约，而是直接提供一个返回值
// 函数声明为 internal 内联函数，防止部署时单独部署
library SimpleMock {
    function simpleVRF() internal pure returns (uint256) {
        return 1234567890;
    }
}
