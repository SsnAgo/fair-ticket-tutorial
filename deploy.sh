#!/bin/bash
# 设置环境变量
source .env
# 运行 script 进行合约部署
forge script script/FairTicket.s.sol:FairTicketScript --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY --broadcast