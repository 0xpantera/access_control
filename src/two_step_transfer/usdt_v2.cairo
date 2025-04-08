use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20MintingAndBurning<TState> {
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn burn(ref self: TState, amount: u256) -> bool;
}

#[starknet::contract]
mod USDTTokenV2 {

    use access_control::two_step_transfer::ownable_2step::OwnableTwoStepComponent::InternalTrait;
    use access_control::two_step_transfer::ownable_2step::OwnableTwoStepComponent;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address};

    // Components
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableTwoStepComponent, storage: ownable_2step, event: OwnableEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl Ownable2Step = OwnableTwoStepComponent::Ownable2StepImpl<ContractState>;

    #[abi(embed_v0)]
    impl Ownable2StepCamelOnly = OwnableTwoStepComponent::Ownable2StepCamelOnlyImpl<ContractState>;
    impl OwnableTwoStepInternalImpl = OwnableTwoStepComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable_2step: OwnableTwoStepComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableTwoStepComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        let name = "USDTToken";
        let symbol = "USDT";
        self.erc20.initializer(name, symbol);
        self.ownable_2step.initializer_two_step(owner);
    }

    #[abi(embed_v0)]
    impl ERC20MintingBurningImpl of super::IERC20MintingAndBurning<ContractState> {
        
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.ownable_2step.assert_only_owner();
            self.erc20.mint(recipient, amount);
            true
        }

        fn burn(ref self: ContractState, amount: u256) -> bool {
            self.erc20.burn(get_caller_address(), amount);
            true
        }
    }
}
