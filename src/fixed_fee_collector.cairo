#[starknet::interface]
pub trait IFixedFeeCollector<TContractState> {
    fn get_fee(self: @TContractState) -> u128;
    fn set_fee(ref self: TContractState, fee: u128);
    fn collect_fees(ref self: TContractState);
}

mod Errors {
    pub const NOT_OWNER: felt252 = 'must be contract owner';
}

// The contract FeeCollector is a contract which collects fees and allows the owner to set the fee.
// The contract has a storage which contains the owner, the token to collect fees from and the fee
// in basis points.
#[starknet::contract]
mod FixedFeeCollector {
    use super::Errors;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    const FEES_PRECISION: u128 = 10000; // 100%

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        token: IERC20Dispatcher, // The token to collect fees from
        fee_bps: u128 // The fee in basis points
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    // The constructor of the contract initializes the owner, the token and the fee.
    #[constructor]
    fn constructor(ref self: ContractState, token: ContractAddress, owner: ContractAddress) {
        self.token.write(IERC20Dispatcher { contract_address: token });
        self.ownable.initializer(owner);
        self.fee_bps.write(0);
    }
    

    #[abi(embed_v0)]
    impl IFixedFeeCollectorImpl of super::IFixedFeeCollector<ContractState> {
        // Get the fee in basis points
        fn get_fee(self: @ContractState) -> u128 {
            self.fee_bps.read()
        }

        // Set the fee in basis points
        fn set_fee(ref self: ContractState, fee: u128) {
            self.ownable.assert_only_owner();
            // The fee should be less than or equal to 50%
            assert(fee <= FEES_PRECISION / 2, 'High Fee');
            self.fee_bps.write(fee);
        }

        // Collect the fees
        fn collect_fees(ref self: ContractState) {
            self.ownable.assert_only_owner();
            // Transfer the fee to the owner
            let balance = self.token.read().balance_of(get_contract_address());
            self.token.read().transfer(get_caller_address(), balance);
        }
    }
}