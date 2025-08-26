// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {FairTicket, SimpleMock} from "../src/FairTicket.sol";
import {Project, Participant, LotteryResult, ProjectStatus} from "../src/Model.sol";
import {FairTicketScript} from "../script/FairTicket.s.sol";

contract FairTicketTest is Test {
    FairTicket public fairTicket;

    // 测试地址
    address public owner;
    address public projectOwner1;
    address public projectOwner2;
    address public user1;
    address public user2;

    // 测试数据
    bytes32 public constant TEST_FINGERPRINT = keccak256("test_fingerprint");
    bytes32 public constant TEST_MERKLE_ROOT = keccak256("test_merkle_root");
    uint256 public constant TEST_TOTAL_SUPPLY = 100;

    function setUp() public {
        // 设置测试地址
        owner = address(this);
        projectOwner1 = makeAddr("projectOwner1");
        projectOwner2 = makeAddr("projectOwner2");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 部署合约
        fairTicket = new FairTicket(1);
    }

    // ========== 构造函数测试 ==========
    function test_Constructor() public {
        // 验证初始状态
        assertEq(fairTicket.s_globalId(), 1);
        assertEq(fairTicket.owner(), owner);
    }

    // ========== createProject 函数测试 ==========
    function test_CreateProject_Success() public {
        // 测试成功创建项目
        vm.expectEmit(true, true, false, true);
        emit FairTicket.ProjectCreated(1, TEST_FINGERPRINT);

        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        // 验证项目信息
        Project memory project = fairTicket.getProjectInfo(1);
        assertEq(project.id, 1);
        assertEq(project.fingerprint, TEST_FINGERPRINT);
        assertEq(project.owner, projectOwner1);
        assertEq(project.totalSupply, TEST_TOTAL_SUPPLY);
        assertTrue(project.projectStatus == ProjectStatus.NotStart);
        assertEq(project.merkleRoot, bytes32(0));

        // 验证全局ID递增
        assertEq(fairTicket.s_globalId(), 2);
    }

    function test_CreateProject_RevertIf_NotOwner() public {
        // 测试非owner调用失败
        vm.prank(user1);
        vm.expectRevert();
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
    }

    function test_CreateProject_RevertIf_TotalSupplyZero() public {
        // 测试总供应量为0时失败
        vm.expectRevert(FairTicket.TotalSupplyZero.selector);
        fairTicket.createProject(TEST_FINGERPRINT, projectOwner1, 0);
    }

    function test_CreateProject_MultipleProjects() public {
        // 测试创建多个项目
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.createProject(keccak256("second"), projectOwner2, 200);

        assertEq(fairTicket.s_globalId(), 3);

        Project memory project2 = fairTicket.getProjectInfo(2);
        assertEq(project2.id, 2);
        assertEq(project2.owner, projectOwner2);
        assertEq(project2.totalSupply, 200);
    }

    // ========== startProject 函数测试 ==========
    function test_StartProject_Success() public {
        // 先创建项目
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        // 测试开始项目
        vm.expectEmit(true, false, false, true);
        emit FairTicket.ProjectStarted(1);

        fairTicket.startProject(1);

        // 验证项目状态
        ProjectStatus status = fairTicket.getProjectStatus(1);
        assertTrue(status == ProjectStatus.InProgress);
    }

    function test_StartProject_RevertIf_ProjectNotFound() public {
        // 测试项目不存在时失败
        vm.expectRevert(FairTicket.ProjectNotFound.selector);
        fairTicket.startProject(999);
    }

    function test_StartProject_RevertIf_NotOwner() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        vm.prank(user1);
        vm.expectRevert();
        fairTicket.startProject(1);
    }

    function test_StartProject_RevertIf_AlreadyStarted() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.startProject(1);

        // 再次尝试开始已开始的项目
        vm.expectRevert(FairTicket.ProjectAlreadyStarted.selector);
        fairTicket.startProject(1);
    }

    function test_StartProject_RevertIf_ProjectFinished() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.startProject(1);
        fairTicket.finishProject(1);

        // 尝试开始已完成的项目
        vm.expectRevert(FairTicket.ProjectAlreadyStarted.selector);
        fairTicket.startProject(1);
    }

    // ========== finishProject 函数测试 ==========
    function test_FinishProject_Success() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.startProject(1);

        vm.expectEmit(true, false, false, true);
        emit FairTicket.ProjectFinished(1);

        fairTicket.finishProject(1);

        ProjectStatus status = fairTicket.getProjectStatus(1);
        assertTrue(status == ProjectStatus.Finished);
    }

    function test_FinishProject_RevertIf_ProjectNotFound() public {
        vm.expectRevert(FairTicket.ProjectNotFound.selector);
        fairTicket.finishProject(999);
    }

    function test_FinishProject_RevertIf_NotOwner() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.startProject(1);

        vm.prank(user1);
        vm.expectRevert();
        fairTicket.finishProject(1);
    }

    function test_FinishProject_RevertIf_NotInProgress() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        // 尝试结束未开始的项目
        vm.expectRevert(FairTicket.ProjectNotInProgress.selector);
        fairTicket.finishProject(1);
    }

    // ========== lottery 函数测试 ==========
    function test_Lottery_Success() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.startProject(1);
        fairTicket.finishProject(1);

        vm.expectEmit(true, false, false, true);
        emit FairTicket.MagicNumberPublished(1, 1234567890);

        fairTicket.lottery(1);

        LotteryResult memory result = fairTicket.getLotteryResult(1);
        assertEq(result.projectId, 1);
        assertEq(result.magicNumber, 1234567890);
    }

    function test_Lottery_RevertIf_ProjectNotFound() public {
        vm.expectRevert(FairTicket.ProjectNotFound.selector);
        fairTicket.lottery(999);
    }

    function test_Lottery_RevertIf_NotOwner() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.startProject(1);
        fairTicket.finishProject(1);

        vm.prank(user1);
        vm.expectRevert();
        fairTicket.lottery(1);
    }

    function test_Lottery_RevertIf_ProjectNotFinished() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.startProject(1);

        vm.expectRevert(FairTicket.ProjectNotFinished.selector);
        fairTicket.lottery(1);
    }

    function test_Lottery_RevertIf_ProjectNotStarted() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        vm.expectRevert(FairTicket.ProjectNotFinished.selector);
        fairTicket.lottery(1);
    }

    // ========== SetMerkleRoot 函数测试 ==========
    function test_SetMerkleRoot_Success() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        fairTicket.SetMerkleRoot(1, TEST_MERKLE_ROOT);

        Project memory project = fairTicket.getProjectInfo(1);
        assertEq(project.merkleRoot, TEST_MERKLE_ROOT);
    }

    function test_SetMerkleRoot_RevertIf_NotOwner() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        vm.prank(user1);
        vm.expectRevert();
        fairTicket.SetMerkleRoot(1, TEST_MERKLE_ROOT);
    }

    function test_SetMerkleRoot_RevertIf_AlreadySet() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.SetMerkleRoot(1, TEST_MERKLE_ROOT);

        vm.expectRevert(FairTicket.MerkleRootAlreadySet.selector);
        fairTicket.SetMerkleRoot(1, keccak256("another_root"));
    }

    // ========== verifyMerkleProof 函数测试 ==========
    function test_VerifyMerkleProof_Success() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        // 设置简单的merkle root (用户地址的hash)
        bytes32 userHash = keccak256(abi.encodePacked(user1));
        fairTicket.SetMerkleRoot(1, userHash);

        // 空proof数组，因为这是leaf node
        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user1);
        bool result = fairTicket.verifyMerkleProof(1, proof);
        assertTrue(result);
    }

    function test_VerifyMerkleProof_RevertIf_InvalidProof() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.SetMerkleRoot(1, TEST_MERKLE_ROOT);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256("invalid");

        vm.prank(user1);
        vm.expectRevert();
        fairTicket.verifyMerkleProof(1, proof);
    }

    // ========== getProjectParticipants 函数测试 ==========
    function test_GetProjectParticipants_EmptyList() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        vm.expectRevert(FairTicket.OffsetOutOfBounds.selector);
        fairTicket.getProjectParticipants(1, 0, 10);
    }

    function test_GetProjectParticipants_WithParticipants() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        // 手动添加参与者到存储中（这需要修改合约或添加函数）
        // 由于当前合约没有添加参与者的函数，我们测试边界情况

        // 测试offset越界
        vm.expectRevert(FairTicket.OffsetOutOfBounds.selector);
        fairTicket.getProjectParticipants(1, 0, 10);
    }

    // ========== Getter 函数测试 ==========
    function test_GetProjectInfo() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        Project memory project = fairTicket.getProjectInfo(1);
        assertEq(project.id, 1);
        assertEq(project.fingerprint, TEST_FINGERPRINT);
        assertEq(project.owner, projectOwner1);
        assertEq(project.totalSupply, TEST_TOTAL_SUPPLY);
        assertTrue(project.projectStatus == ProjectStatus.NotStart);
        assertEq(project.merkleRoot, bytes32(0));
    }

    function test_GetProjectInfo_NonexistentProject() public {
        Project memory project = fairTicket.getProjectInfo(999);
        assertEq(project.id, 0);
        assertEq(project.fingerprint, bytes32(0));
        assertEq(project.owner, address(0));
        assertEq(project.totalSupply, 0);
        assertTrue(project.projectStatus == ProjectStatus.NotStart);
        assertEq(project.merkleRoot, bytes32(0));
    }

    function test_GetProjectStatus() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        ProjectStatus status = fairTicket.getProjectStatus(1);
        assertTrue(status == ProjectStatus.NotStart);

        fairTicket.startProject(1);
        status = fairTicket.getProjectStatus(1);
        assertTrue(status == ProjectStatus.InProgress);

        fairTicket.finishProject(1);
        status = fairTicket.getProjectStatus(1);
        assertTrue(status == ProjectStatus.Finished);
    }

    function test_GetLotteryResult() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        fairTicket.startProject(1);
        fairTicket.finishProject(1);
        fairTicket.lottery(1);

        LotteryResult memory result = fairTicket.getLotteryResult(1);
        assertEq(result.projectId, 1);
        assertEq(result.magicNumber, 1234567890);
    }

    function test_GetLotteryResult_NoLottery() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        LotteryResult memory result = fairTicket.getLotteryResult(1);
        assertEq(result.projectId, 0);
        assertEq(result.magicNumber, 0);
    }

    function test_GetParticipantInfo() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        Participant memory participant = fairTicket.getParticipantInfo(
            1,
            user1
        );
        assertEq(participant.addr, address(0));
        assertEq(participant.luckyNum, 0);
    }

    function test_GetProjectParticipantsAmount() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        uint256 amount = fairTicket.getProjectParticipantsAmount(1);
        assertEq(amount, 0);
    }

    // ========== SimpleMock 库测试 ==========
    function test_SimpleMock_SimpleVRF() public {
        // 直接调用库函数
        uint256 randomNumber = SimpleMock.simpleVRF();
        assertEq(randomNumber, 1234567890);
    }

    // ========== 修饰器测试 ==========
    function test_ProjectExist_Modifier() public {
        // 已在其他测试中覆盖
    }

    function test_ProjectOwnerOnly_Modifier() public {
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        // 这个修饰器在当前合约中定义了但没有被使用
        // 可以添加一个使用该修饰器的函数来测试
    }

    // ========== 边界情况和错误测试 ==========
    function test_EdgeCase_MaxValues() public {
        uint256 maxSupply = type(uint256).max;
        fairTicket.createProject(TEST_FINGERPRINT, projectOwner1, maxSupply);

        Project memory project = fairTicket.getProjectInfo(1);
        assertEq(project.totalSupply, maxSupply);
    }

    function test_EdgeCase_ZeroAddressOwner() public {
        // 测试零地址作为项目所有者
        fairTicket.createProject(
            TEST_FINGERPRINT,
            address(0),
            TEST_TOTAL_SUPPLY
        );

        Project memory project = fairTicket.getProjectInfo(1);
        assertEq(project.owner, address(0));
    }

    function test_EdgeCase_EmptyFingerprint() public {
        fairTicket.createProject(bytes32(0), projectOwner1, TEST_TOTAL_SUPPLY);

        Project memory project = fairTicket.getProjectInfo(1);
        assertEq(project.fingerprint, bytes32(0));
    }

    // ========== 状态转换完整流程测试 ==========
    function test_CompleteWorkflow() public {
        // 创建项目
        fairTicket.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        // 验证初始状态
        assertTrue(fairTicket.getProjectStatus(1) == ProjectStatus.NotStart);

        // 开始项目
        fairTicket.startProject(1);
        assertTrue(fairTicket.getProjectStatus(1) == ProjectStatus.InProgress);

        // 结束项目
        fairTicket.finishProject(1);
        assertTrue(fairTicket.getProjectStatus(1) == ProjectStatus.Finished);

        // 设置 Merkle Root
        fairTicket.SetMerkleRoot(1, TEST_MERKLE_ROOT);

        // 进行抽奖
        fairTicket.lottery(1);

        // 验证最终状态
        LotteryResult memory result = fairTicket.getLotteryResult(1);
        assertEq(result.projectId, 1);
        assertEq(result.magicNumber, 1234567890);
    }

    // ========== FairTicketScript 脚本合约测试 ==========

    function test_FairTicketScript_Deployment() public {
        // 部署脚本合约
        FairTicketScript script = new FairTicketScript();

        uint256 expectedOwnerPrivateKey = vm.envUint("PRIVATE_KEY");
        address expectedOwner = vm.addr(expectedOwnerPrivateKey);
        // 调用 run() 部署 FairTicket
        script.run();

        // 检查合约地址不为0
        assertTrue(address(script.fairTicket()) != address(0));

        // 检查合约 owner 是否符合预期
        address actualOwner = script.fairTicket().owner();
        assertEq(actualOwner, expectedOwner);
    }

    function test_FairTicketScript_setUp() public {
        // 部署脚本合约
        FairTicketScript script = new FairTicketScript();
        // 调用 setUp()，应无异常
        script.setUp();
        // 仅验证 setUp 可正常调用
        assertTrue(true);
    }
}

// 测试辅助合约，用于测试包含参与者的场景
contract TestFairTicket is FairTicket {
    constructor(uint256 _globalId) FairTicket(_globalId) {}

    // 添加一个函数来手动添加参与者，仅用于测试
    function addParticipant(
        uint256 projectId,
        address participant,
        uint256 luckyNum
    ) external {
        Participant memory newParticipant = Participant({
            addr: participant,
            luckyNum: luckyNum
        });
        s_projectid_participants[projectId].push(newParticipant);
        s_projectid_paddr_participant[projectId][participant] = newParticipant;
    }

    // 添加一个使用 ProjectOwnerOnly 修饰器的测试函数
    function onlyProjectOwnerTest(
        uint256 projectId
    ) external projectOwnerOnly(projectId) {
        // 这个函数只是为了测试修饰器
    }

    // 添加一个使用 projectInProgress 修饰器的测试函数
    function projectInProgressTest(
        uint256 projectId
    ) external projectInProgress(projectId) {
        // 这个函数只是为了测试修饰器
    }
}

// 扩展测试，用于测试辅助合约
contract FairTicketTestExtended is Test {
    TestFairTicket public testContract;

    address public owner;
    address public projectOwner1;
    address public user1;
    address public user2;

    bytes32 public constant TEST_FINGERPRINT = keccak256("test_fingerprint");
    uint256 public constant TEST_TOTAL_SUPPLY = 100;

    function setUp() public {
        owner = address(this);
        projectOwner1 = makeAddr("projectOwner1");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        testContract = new TestFairTicket(1);
    }

    // 测试 getProjectParticipants 的所有分支
    function test_GetProjectParticipants_AllBranches() public {
        testContract.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        // 添加一些参与者
        testContract.addParticipant(1, user1, 123);
        testContract.addParticipant(1, user2, 456);

        // 测试正常分页
        Participant[] memory participants = testContract.getProjectParticipants(
            1,
            0,
            1
        );
        assertEq(participants.length, 1);
        assertEq(participants[0].addr, user1);
        assertEq(participants[0].luckyNum, 123);

        // 测试获取所有参与者
        participants = testContract.getProjectParticipants(1, 0, 2);
        assertEq(participants.length, 2);

        // 测试limit超过实际数量的情况 - 这会触发未覆盖的分支
        participants = testContract.getProjectParticipants(1, 0, 10);
        assertEq(participants.length, 2);

        // 测试offset + limit > totalParticipants - 这会触发另一个未覆盖的分支
        participants = testContract.getProjectParticipants(1, 1, 10);
        assertEq(participants.length, 1);
        assertEq(participants[0].addr, user2);
    }

    // 测试 ProjectOwnerOnly 修饰器
    function test_ProjectOwnerOnly_Modifier() public {
        testContract.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );

        // 项目所有者调用应该成功
        vm.prank(projectOwner1);
        testContract.onlyProjectOwnerTest(1);

        // 非项目所有者调用应该失败
        vm.prank(user1);
        vm.expectRevert(FairTicket.OnlyProjectOwner.selector);
        testContract.onlyProjectOwnerTest(1);
    }

    // 测试 projectInProgress 修饰器
    function test_ProjectInProgress_Modifier() public {
        testContract.createProject(
            TEST_FINGERPRINT,
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        testContract.startProject(1);

        // 项目进行中时应该成功
        testContract.projectInProgressTest(1);

        // 项目结束后应该失败
        testContract.finishProject(1);
        vm.expectRevert(FairTicket.ProjectNotInProgress.selector);
        testContract.projectInProgressTest(1);

        // 创建另一个项目但不开始，应该失败
        testContract.createProject(
            keccak256("test2"),
            projectOwner1,
            TEST_TOTAL_SUPPLY
        );
        vm.expectRevert(FairTicket.ProjectNotInProgress.selector);
        testContract.projectInProgressTest(2);
    }
}
