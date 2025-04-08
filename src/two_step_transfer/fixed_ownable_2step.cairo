use starknet::ContractAddress;

#[starknet::interface]
pub trait IFixedOwnableTwoStep<TState> {
    fn owner(self: @TState) -> ContractAddress;
    fn pending_owner(self: @TState) -> ContractAddress;
    fn accept_ownership(ref self: TState);
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);
}

#[starknet::interface]
pub trait IFixedOwnableTwoStepCamelOnly<TState> {
    fn pendingOwner(self: @TState) -> ContractAddress;
    fn acceptOwnership(ref self: TState);
    fn transferOwnership(ref self: TState, newOwner: ContractAddress);
    fn renounceOwnership(ref self: TState);
    fn initializerTwoStep(ref self: TState, owner: ContractAddress);
}

#[starknet::component]
pub mod FixedOwnableTwoStepComponent {
    use core::num::traits::zero::Zero;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        Ownable_owner: ContractAddress,
        Pending_owner: ContractAddress
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

    mod Errors {
        pub const NOT_OWNER: felt252 = 'Caller is not the owner';
        pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        pub const ZERO_ADDRESS_OWNER: felt252 = 'New owner is the zero address';
    }

    #[embeddable_as(Ownable2StepImpl)]
    impl Ownable2Step<
        TContractState, +HasComponent<TContractState>
    > of super::IOwnableTwoStep<ComponentState<TContractState>> {
        
        /// Returns the address of the current owner.
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Ownable_owner.read()
        }
        // Returns the address of the pending owner.
        fn pending_owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Pending_owner.read()
        }

        /// Add a new pending owner to the contract.
        ///
        /// Requirements:
        ///
        /// - `new_owner` is not the zero address.
        /// - The caller is the contract owner.
        fn transfer_ownership(ref self: ComponentState<TContractState>, new_owner: ContractAddress) {
            self.assert_only_owner();
            assert(!new_owner.is_zero(), Errors::ZERO_ADDRESS_OWNER);
            self.Pending_owner.write(new_owner);
        }

        /// Transfers ownership of the contract to the pending owner
        ///
        /// Requirements:
        /// 
        /// - The caller is the pending owner.
        /// Emits an `OwnershipTransferred` event.
        fn accept_ownership(ref self: ComponentState<TContractState>) {
            let pending_owner: ContractAddress = self.Pending_owner.read();
            let caller = get_caller_address();
            assert(caller == pending_owner, Errors::NOT_OWNER);
            self._transfer_ownership(pending_owner);
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

    /// Adds camelCase support for `IOwnableTwoStep`.
    #[embeddable_as(Ownable2StepCamelOnlyImpl)]
    impl Ownable2StepCamelOnly<
        TContractState, +HasComponent<TContractState>
    > of super::IOwnableTwoStepCamelOnly<ComponentState<TContractState>> {
        fn pendingOwner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Pending_owner.read()
        }

        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            self.transfer_ownership(newOwner);
        }

        fn acceptOwnership(ref self: ComponentState<TContractState>) {
            self.accept_ownership();
        }

        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            self.renounce_ownership();
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Sets the contract's initial owner.
        ///
        /// This function should be called at construction time.
        fn _initializer_two_step(ref self: ComponentState<TContractState>, owner: ContractAddress) {
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
            self.Pending_owner.write(Zero::zero());
            self.emit(OwnershipTransferred { previous_owner: previous_owner, new_owner: new_owner });
        }
    }
}
