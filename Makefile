-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make fund ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean :; forge clean

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'Starting Anvil' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# Deploy for the SaleFactory contract
deploy-sale-factory:
	forge build
	forge script script/DeploySaleFactory.s.sol:DeploySaleFactory $(NETWORK_ARGS)


deploy-sale-factory-sepolia:
	forge build
	forge script script/DeploySaleFactory.s.sol:DeploySaleFactory --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv

deploy-sale-factory-mainnet:
	forge build
	forge script script/DeploySaleFactory.s.sol:DeploySaleFactory --rpc-url $(MAINNET_RPC_URL) --private-key $(MAINNET_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv


# Deploy for the mock tokens (USDT, USDC, ERC20)
deploy-mocks:
	forge build
	@forge script script/DeployMockUsdt.s.sol:DeployMockUsdt $(NETWORK_ARGS)
	@forge script script/DeployMockUsdc.s.sol:DeployMockUsdc $(NETWORK_ARGS)
	@forge script script/DeployMockErc20.s.sol:DeployMockErc20 $(NETWORK_ARGS)

deploy-mocks-sepolia:
	forge build
	forge script script/DeployMockUsdt.s.sol:DeployMockUsdt --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv
	forge script script/DeployMockUsdc.s.sol:DeployMockUsdc --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv
	forge script script/DeployMockErc20.s.sol:DeployMockErc20 --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv


# Test on forked Sepolia network
test-forked-sepolia:
	forge test --fork-url $(SEPOLIA_RPC_URL) -vvvv
