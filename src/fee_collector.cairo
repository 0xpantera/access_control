#[starknet::interface]
pub trait IFeeCollector<TContractState> {
    fn get_fee(self: @TContractState) -> u128;
    fn set_fee(ref self: TContractState, fee: u128);
    fn collect_fees(ref self: TContractState);
}

// The contract FeeCollector is a contract which collects fees and allows the owner to set the fee.
// The contract has a storage which contains the owner, the token to collect fees from and the fee
// in basis points.
#[starknet::contract]
mod FeeCollector {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    const FEES_PRECISION: u128 = 10000; // 100%

    #[storage]
    struct Storage {
        owner: ContractAddress, // The owner of the contract
        token: IERC20Dispatcher, // The token to collect fees from
        fee_bps: u128 // The fee in basis points
    }

    // The constructor of the contract initializes the owner, the token and the fee.
    #[constructor]
    fn constructor(ref self: ContractState, token: ContractAddress, owner: ContractAddress) {
        self.token.write(IERC20Dispatcher { contract_address: token });
        self.owner.write(owner);
        self.fee_bps.write(0);
    }

    #[abi(embed_v0)]
    impl IFeeCollectorImpl of super::IFeeCollector<ContractState> {
        // Get the fee in basis points
        fn get_fee(self: @ContractState) -> u128 {
            self.fee_bps.read()
        }

        // Set the fee in basis points
        fn set_fee(ref self: ContractState, fee: u128) {
            assert(self.owner.read() == get_caller_address(), 'Not owner');
            // The fee should be less than or equal to 50%
            assert(fee <= FEES_PRECISION / 2, 'High Fee');
            self.fee_bps.write(fee);
        }

        // Collect the fees
        fn collect_fees(ref self: ContractState) {
            // Transfer the fee to the owner
            let balance = self.token.read().balance_of(get_contract_address());
            self.token.read().transfer(get_caller_address(), balance);
        }
    }
}
