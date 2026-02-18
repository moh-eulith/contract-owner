This repository contains examples of contracts with extra funcitonality used as World exchange 
account owners.

You must read, review and understand what these contracts do. Use at your own risk.

`SafeWhitelistModule` is a contract that can be used with a (gnosis) Safe as a module.
In this case, the safe address is the owner of funds.
The module allows creating operators and withdraw whitelists.
To use it, follow the initial setup steps.

Initial setup:
- Deploy a safe with you choice of multi-sig owners.
- Deploy this contract, specifying the Safe and exchange addresses, which are immutable.
- Add this contract as a module in the Safe UI.
- Via the Safe UI, make calls to the functions `addOperator(address)` and `addWhitelist(address)`

Usage:
- An operator can call `depositToExchange` and `withdrawTo` functions.
