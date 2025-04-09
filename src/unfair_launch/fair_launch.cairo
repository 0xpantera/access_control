use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20MintingAndBurning<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn burn(ref self: TContractState, user: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
pub trait IFairLaunch<TContractState> {
    fn participate(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, user: ContractAddress, amount: u256);
}

#[starknet::contract]
mod FairLaunch {
    
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    // Components and Implementations
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl AccessControlImpl = AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    // Roles
    const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
    const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
    const BURNER_ROLE: felt252 = selector!("BURNER_ROLE");
    const PUBLIC_ROLE: felt252 = selector!("BURNER_ROLE");

    // The amount of ETH can be exchanged to USDT, Minting tokens cose 0.1 ETH
    const FIXED_ETH_AMOUNT: u256 = 100000000000000000;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        eth: IERC20Dispatcher
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, eth: ContractAddress) {
        let name = "FairLaunchToken";
        let symbol = "FLT";
        self.erc20.initializer(name, symbol);
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(MINTER_ROLE, owner);
        self.accesscontrol._grant_role(BURNER_ROLE, owner);
        self.accesscontrol._grant_role(ADMIN_ROLE, owner);
        self.eth.write(IERC20Dispatcher { contract_address: eth });
    }
    
    #[abi(embed_v0)]
    impl ERC20MintingBurningImpl of super::IERC20MintingAndBurning<ContractState> {

        // Only the Minter role can mint tokens
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            self.erc20.mint(recipient, amount);
            true
        }

        // Only the Burner role can burn tokens
        fn burn(ref self: ContractState, user: ContractAddress, amount: u256) -> bool {
            self.accesscontrol.assert_only_role(BURNER_ROLE);
            self.erc20.burn(user, amount);
            true
        }
    }

    #[abi(embed_v0)]
    impl FairLaunchImpl of super::IFairLaunch<ContractState> {
        
        // Participate in the launch by paying the needed amount of ETH
        fn participate(ref self: ContractState, amount: u256) {
            assert(amount >= FIXED_ETH_AMOUNT, 'Amount is too low');
            self.eth.read().transfer_from(get_caller_address(), get_contract_address(), amount);
            self.accesscontrol._grant_role(PUBLIC_ROLE, get_caller_address());
        }

        // Withdraw the ETH from the contract
        fn withdraw(ref self: ContractState, user: ContractAddress, amount: u256) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.eth.read().transfer(user, amount);
        }
    }
}
