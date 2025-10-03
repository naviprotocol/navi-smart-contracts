module lending_core::account {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use lending_core::error::{Self};

    friend lending_core::lending;

    struct AccountCap has key, store {
        id: UID,
        owner: address
    }

    public(friend) fun create_account_cap(ctx: &mut TxContext): AccountCap {
        let id = object::new(ctx);
        let owner = object::uid_to_address(&id);
        AccountCap { id, owner}
    }

    public(friend) fun create_child_account_cap(parent_account_cap: &AccountCap, ctx: &mut TxContext): AccountCap {
        let owner = parent_account_cap.owner;
        assert!(object::uid_to_address(&parent_account_cap.id) == owner, error::required_parent_account_cap());

        AccountCap {
            id: object::new(ctx),
            owner: owner
        }
    }

    public(friend) fun delete_account_cap(cap: AccountCap) {
        let AccountCap { id, owner: _} = cap;
        object::delete(id)
    }

    public fun account_owner(cap: &AccountCap): address {
        cap.owner
    }
}