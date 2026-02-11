module lending_core::account {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use lending_core::error::{Self};
    use std::ascii::{Self, String};
    use sui::table::{Self, Table};
    use sui::dynamic_field::{Self};

    friend lending_core::lending;

    struct AccountCap has key, store {
        id: UID,
        owner: address
    }

    // Display Field For Account Cap
    struct AccountField has store {
        account_name: String,
        account_description: String,
        last_update_time: String,
        market_balance: String,
    }

    // ==== dynamic field keys ====
    struct AccountFieldKey has copy, drop, store {}

    public(friend) fun create_account_cap(ctx: &mut TxContext): AccountCap {
        let id = object::new(ctx);
        let owner = object::uid_to_address(&id);
        AccountCap { id, owner}
    }

    // unused function
    public(friend) fun create_child_account_cap(parent_account_cap: &AccountCap, ctx: &mut TxContext): AccountCap {
        let owner = parent_account_cap.owner;
        assert!(object::uid_to_address(&parent_account_cap.id) == owner, error::required_parent_account_cap());

        AccountCap {
            id: object::new(ctx),
            owner: owner
        }
    }

    // unused function
    public(friend) fun delete_account_cap(cap: AccountCap) {
        let AccountCap { id, owner: _} = cap;
        object::delete(id)
    }

    public fun account_owner(cap: &AccountCap): address {
        cap.owner
    }

    public fun set_account_name(cap: &mut AccountCap, name: String) {
        let account_field = get_or_create_account_field(cap);
        account_field.account_name = name;
    }

    public fun set_account_description(cap: &mut AccountCap, description: String) {
        let account_field = get_or_create_account_field(cap);
        account_field.account_description = description;
    }

    public fun set_last_update_time(cap: &mut AccountCap, last_update_time: String) {
        let account_field = get_or_create_account_field(cap);
        account_field.last_update_time = last_update_time;
    }

    public fun set_market_balance(cap: &mut AccountCap, balance: String) {
        let account_field = get_or_create_account_field(cap);
        account_field.market_balance = balance;
    }

    fun get_or_create_account_field(cap: &mut AccountCap): &mut AccountField {
        if (!dynamic_field::exists_(&cap.id, AccountFieldKey {})) {
            dynamic_field::add(&mut cap.id, AccountFieldKey {}, AccountField {
                account_name: ascii::string(b""),
                account_description: ascii::string(b""),
                last_update_time: ascii::string(b""),
                market_balance: ascii::string(b"")
            });
        };
        dynamic_field::borrow_mut(&mut cap.id, AccountFieldKey {})
    }

    public fun get_account_info(cap: &AccountCap): (String, String, String, String) {
        let account_field: &AccountField = dynamic_field::borrow(&cap.id, AccountFieldKey {});
        (account_field.account_name, account_field.account_description, account_field.last_update_time, account_field.market_balance)
    }

    #[test_only]
    public fun create_account_cap_for_testing(ctx: &mut TxContext): AccountCap {
        create_account_cap(ctx)
    }

    #[test_only]
    public fun delete_account_cap_for_testing(cap: AccountCap) {
        delete_account_cap(cap)
    }
}