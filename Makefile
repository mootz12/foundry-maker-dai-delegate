# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build
test   :; forge test --fork-url ${ETH_RPC_URL}
trace   :; forge test -vvv --fork-url ${ETH_RPC_URL}
test-contract :; forge test -vv --fork-url ${ETH_RPC_URL} --match-contract $(contract)
trace-contract :; forge test -vvv --fork-url ${ETH_RPC_URL} --match-contract $(contract)
# local tests without fork
test-local  :; forge test
trace-local  :; forge test -vvv
clean  :; forge clean
snapshot :; forge snapshot