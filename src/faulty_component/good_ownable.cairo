#[starknet::component]
pub mod OwnableComponent {
    use core::num::traits::Zero;
    use starknet::storage::{StoragePointerWriteAccess, StoragePointerReadAccess};
    use openzeppelin::access::ownable::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    pub struct Storage {
        Ownable_owner: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OwnershipTransferred: OwnershipTransferred
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    pub mod Errors {
        pub const NOT_OWNER: felt252 = 'Caller is not the owner';
        pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        pub const ZERO_ADDRESS_OWNER: felt252 = 'New owner is the zero address';
    }

    #[embeddable_as(OwnableImpl)]
    impl Ownable<TContractState, +HasComponent<TContractState>> of interface::IOwnable<ComponentState<TContractState>> {
        /// Returns the address of the current owner.
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Ownable_owner.read()
        }

        /// Transfers ownership of the contract to a new address.
        ///
        /// Requirements:
        ///
        /// - `new_owner` is not the zero address.
        /// - The caller is the contract owner.
        ///
        /// Emits an `OwnershipTransferred` event.
        fn transfer_ownership(ref self: ComponentState<TContractState>, new_owner: ContractAddress) {
            self.assert_only_owner();
            assert(!new_owner.is_zero(), Errors::ZERO_ADDRESS_OWNER);
            self._transfer_ownership(new_owner);
        }

        /// Leaves the contract without owner. It will not be possible to call `assert_only_owner`
        /// functions anymore. Can only be called by the current owner.
        ///
        /// Requirements:
        ///
        /// - The caller is the contract owner.
        ///
        /// Emits an `OwnershipTransferred` event.
        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            self.assert_only_owner();
            self._transfer_ownership(Zero::zero());
        }
    }

    /// Adds camelCase support for `IOwnable`.
    #[embeddable_as(OwnableCamelOnlyImpl)]
    impl OwnableCamelOnly<TContractState, +HasComponent<TContractState>> of interface::IOwnableCamelOnly<ComponentState<TContractState>> {
        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            self.transfer_ownership(newOwner);
        }

        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            self.renounce_ownership();
        }
    }

    #[generate_trait]
    pub impl InternalImpl<TContractState, +HasComponent<TContractState>> of InternalTrait<TContractState> {
        /// Sets the contract's initial owner.
        ///
        /// This function should be called at construction time.
        fn initializer(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }

        /// Panics if called by any account other than the owner. Use this
        /// to restrict access to certain functions to the owner.
        fn assert_only_owner(self: @ComponentState<TContractState>) {
            let owner: ContractAddress = self.Ownable_owner.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(caller == owner, Errors::NOT_OWNER);
        }

        /// Transfers ownership of the contract to a new address.
        ///
        /// Internal function without access restriction.
        ///
        /// Emits an `OwnershipTransferred` event.
        fn _transfer_ownership(ref self: ComponentState<TContractState>, new_owner: ContractAddress) {
            let previous_owner: ContractAddress = self.Ownable_owner.read();
            self.Ownable_owner.write(new_owner);
            self.emit(OwnershipTransferred { previous_owner: previous_owner, new_owner: new_owner });
        }
    }
}