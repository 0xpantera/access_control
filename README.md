# Access Control in Cairo Smart Contracts

This repository contains examples of common access control vulnerabilities and their corresponding fixes in Cairo-based smart contracts on StarkNet.

## Structure

The repository is organized into several modules, each focusing on a specific access control vulnerability:

- `missing_assert`: Demonstrates the risk of missing authorization checks in critical functions
- `faulty_component`: Shows how a flawed implementation of an ownable component can lead to privilege escalation
- `two_step_transfer`: Explores a vulnerability where a public initialization function in the ownership contract can be called by anyone to reset ownership
- `unfair_launch`: Illustrates how misconfigured access control roles can compromise security

## Vulnerabilities and Fixes

### Missing Authorization Checks

In `missing_assert/fee_collector.cairo`, the `collect_fees` function lacks an owner check, allowing anyone to withdraw funds. The fixed implementation in `fixed_fee_collector.cairo` properly checks that only the owner can collect fees.

### Faulty Ownable Component

The `faulty_component/bad_ownable.cairo` contains a flawed implementation where the `transfer_ownership` function doesn't verify the caller is the current owner. The corrected implementation in `good_ownable.cairo` adds the necessary checks.

### Two-Step Ownership Transfer

The `two_step_transfer/ownable_2step.cairo` contains a vulnerability in the `Ownable2StepCamelOnly` implementation where the `initializerTwoStep` function is publicly accessible and doesn't check the caller's identity, allowing an attacker to call it and reset ownership to themselves. The fixed implementation would restrict this function to be called only during initialization or by the current owner.

### Role-Based Access Control Issues

The `unfair_launch` module demonstrates how improper role configuration can lead to security issues, with `PUBLIC_ROLE` being mistakenly set to the same value as `BURNER_ROLE`.

## Testing

Each vulnerability has corresponding test files that demonstrate both the exploit and how the fixed implementation prevents it.

To run tests:

```shell
scarb test
```

## Key Takeaways

1. Always include authorization checks for sensitive operations
2. Use established design patterns like two-step ownership transfer
3. Be careful with role-based access control to avoid unintended privileges
4. Thoroughly test access control mechanisms with both legitimate and malicious scenarios

## Usage

This repository is intended for educational purposes, demonstrating common pitfalls in access control and how to avoid them when developing contracts on StarkNet.
