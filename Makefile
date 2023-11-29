-include .env


build:
	forge build
deploySepolia:
	@forge script script/delpoyDSCEnigne.s.sol:deployDSCEnigne --rpc-url ${SEPOLIA_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deployAnvil:
	@forge script script/delpoyDSCEnigne.s.sol:deployDSCEnigne  --private-key ${DEFAULT_ANVIL_PRIVATE_KEY} --broadcast -vvvv
