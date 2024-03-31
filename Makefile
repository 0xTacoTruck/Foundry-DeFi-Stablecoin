-include .env

fb:;	forge build

ft :; forge test 

fs :; forge snapshot

format :; forge fmt

install-std:
	@forge install foundry-rs/forge-std --no-commit

install-solmate:
	@forge install transmissions11/solmate --no-commit

install-oz-latest:
	@forge install OpenZeppelin/openzeppelin-contracts --no-commit

install-devtools:
	@forge install Cyfrin/foundry-devops --no-commit

install-cl:
	@forge install smartcontractkit/chainlink-brownie-contracts --no-commit

install-base-latest:
	@forge install foundry-rs/forge-std --no-commit && @forge install Cyfrin/foundry-devops --no-commit --no-commit && @forge install OpenZeppelin/openzeppelin-contracts --no-commit


# Install the Open Zeppelin Contracts that are the same version in the course v4.8.3
install-oz-project:
	@forge install OpenZeppelin/openzeppelin-contracts@v4.8.3 --no-commit

# Clean the repo
clean  :; forge clean

dp-sepolia:
	forge script script/DeployDSC.s.sol:DeployDSC --rpc-url $(SEPOLIA_ALCHEMY_RPC_URL) --private-key $(SEPOLIA_METAMASK_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""



anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_0_PRIVATE_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif



# Update Dependencies
update:; forge update

deploy:
	@forge script script/DeployDSC.s.sol:DeployDSC $(NETWORK_ARGS)





