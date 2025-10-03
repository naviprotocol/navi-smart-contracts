module lending_ui::incentive_getter {
    use std::vector::{Self};
    use std::ascii::{String};
    use std::type_name::{Self};
    use sui::clock::{Self, Clock};

    use math::ray_math;
    use oracle::oracle::{Self, PriceOracle};
    use lending_core::pool::{Self};
    use lending_core::calculator::{Self as c};
    use lending_core::storage::{Self, Storage};
    use lending_core::incentive_v2::{Self as incentive, Incentive};

    const MsPerYear: u64 = 1000*60*60*24*365;

    struct IncentivePoolInfo has copy, drop {
        pool_id: address,
        funds: address,
        phase: u64,
        start_at: u64,
        end_at: u64,
        closed_at: u64,
        total_supply: u64,
        asset_id: u8,
        option: u8,
        factor: u256,
        distributed: u64,

        available: u256,
        total: u256,
    }

    public fun get_incentive_pools(clock: &Clock, incentive: &Incentive, storage: &mut Storage, asset: u8, option: u8, user: address): vector<IncentivePoolInfo> {
        let ret = vector::empty<IncentivePoolInfo>();
        let now = clock::timestamp_ms(clock);

        let (_, _, objs) = incentive::get_pool_from_asset_and_option(incentive, asset, option);
        let pool_length = vector::length(&objs);
        let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(storage, asset, user);

        let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(storage, asset);
        if (option == incentive::option_borrow()) {
            total_supply_balance = total_borrow_balance
        };

        while(pool_length > 0) {
            let pool_address = *vector::borrow(&objs, pool_length-1);
            let (
                id_address,
                phase,
                funds,
                start_at,
                end_at,
                closed_at,
                total_supply,
                option,
                asset_id,
                factor,
                _,
                distributed,
                _
            ) = incentive::get_pool_info(incentive, pool_address);

            let user_effective_amount = incentive::calculate_user_effective_amount(option, user_supply_balance, user_borrow_balance, factor);
            let (_, total_rewards_of_user) = incentive::calculate_one_from_pool(incentive, pool_address, now, total_supply_balance, user, user_effective_amount);

            let total_claimed_of_user = incentive::get_total_claimed_from_user(incentive, pool_address, user);

            vector::push_back(&mut ret, IncentivePoolInfo {
                pool_id: id_address,
                funds: funds,
                phase: phase,
                start_at: start_at,
                end_at: end_at,
                closed_at: closed_at,
                total_supply: total_supply, // total amont
                asset_id: asset_id,
                option: option,
                factor: factor,
                distributed: distributed,

                total: total_rewards_of_user,
                available: total_rewards_of_user - total_claimed_of_user,
            });

            pool_length = pool_length - 1;
        };

        ret
    }

    struct IncentiveAPYInfo has copy, drop {
        asset_id: u8,
        apy: u256,
        coin_types: vector<String>,
    }

    public fun get_incentive_apy(clock: &Clock, incentive: &Incentive, storage: &mut Storage, price_oracle: &PriceOracle, option: u8): vector<IncentiveAPYInfo> {
        let now = clock::timestamp_ms(clock);
        let ret = vector::empty<IncentiveAPYInfo>();

        let reserve_count = storage::get_reserves_count(storage); // get reserve count from storage
        while (reserve_count > 0) {
            let asset_id = reserve_count -1; // mark reserve count sub 1 as asset_id
            let (protocol_total_supply, protocol_total_borrow) = storage::get_total_supply(storage, asset_id); // get total supply from storage
            if (option == incentive::option_borrow()) { // if option is borrow, and then, let total_supply = total_borrow
                protocol_total_supply = protocol_total_borrow;
            };

            let oracle_id_of_asset = storage::get_oracle_id(storage, asset_id); // get oracle if from storage.reserve

            let objs = incentive::get_active_pools(incentive, asset_id, option, now); // get the active pool id, must start <= now <= end
            let pool_length = vector::length(&objs);
            if (pool_length == 0) {
                reserve_count = reserve_count - 1;
                continue
            };
            
            let total_apy = 0;
            let _types = vector::empty<String>();
            while (pool_length > 0) {
                let pool_address = *vector::borrow(&objs, pool_length-1);
                let (
                    _,
                    _,
                    funds,
                    start_at,
                    end_at,
                    _,
                    total_supply,
                    _,
                    _,
                    _,
                    _,
                    _,
                    _
                ) = incentive::get_pool_info(incentive, pool_address);

                // let info = table::borrow(&incentive.pools, *pool_address);
                // let funds_info = table::borrow(&incentive.funds, funds);
                let (_, funds_oracle_id, funds_coin_type) = incentive::get_funds_info(incentive, funds);

                // Get the total_supply of the protocol pool and calculate the 
                let protocol_total_supply_on_usd = c::calculate_value(clock, price_oracle, protocol_total_supply, oracle_id_of_asset);

                ///////////////////////////////////////////////////////////////////////////////////
                // @devs Two things                                                              //
                // 1: Convert the token decimals to 9                                            //    
                // 2: Use the same token decimals as the protocol pool for USD price conversion  //
                ///////////////////////////////////////////////////////////////////////////////////
                let (_, _, decimal) = oracle::get_token_price(clock, price_oracle, funds_oracle_id);
                let normal_total_supply = pool::convert_amount(total_supply, decimal, 9);
                let total_incentive_amount_on_usd = c::calculate_value(clock, price_oracle, (normal_total_supply as u256), funds_oracle_id);

                ////////////////////////////////////////////////////////////////////////////////////////////////
                // @devs Calculate APY                                                                        //
                // Formula: APY = total_incentive_amount / duration * ms_per_year / total_supply of protocol  //
                ////////////////////////////////////////////////////////////////////////////////////////////////
                let apy = ray_math::ray_div(
                    ray_math::ray_mul(
                        ray_math::ray_div(
                            total_incentive_amount_on_usd,
                            ((end_at - start_at) as u256),
                        ),
                        (MsPerYear as u256)
                    ),
                    protocol_total_supply_on_usd,
                );

                total_apy = total_apy + apy;
                if (!vector::contains(&_types, &type_name::into_string(funds_coin_type))) {
                    vector::push_back(&mut _types, type_name::into_string(funds_coin_type))
                };

                pool_length = pool_length - 1;
            };

            vector::push_back(&mut ret, IncentiveAPYInfo {
                asset_id: asset_id,
                apy: total_apy,
                coin_types: _types,
            });

            reserve_count = reserve_count - 1;
        };

        ret
    }

    public fun get_incentive_apy_one(clock: &Clock, incentive: &Incentive, storage: &mut Storage, price_oracle: &PriceOracle, pool: address): IncentiveAPYInfo {
        let (
            _,
            _,
            funds,
            start_at,
            end_at,
            _,
            total_supply,
            option,
            asset_id,
            _,
            _,
            _,
            _
        ) = incentive::get_pool_info(incentive, pool);
        let (_, funds_oracle_id, funds_coin_type) = incentive::get_funds_info(incentive, funds);

        // let info = table::borrow(&incentive.pools, pool);
        // let funds_info = table::borrow(&incentive.funds, info.funds);

        let (protocol_total_supply, protocol_total_borrow) = storage::get_total_supply(storage, asset_id);
        if (option == incentive::option_borrow()) {
            protocol_total_supply = protocol_total_borrow;
        };

        // Get the total_supply of the protocol pool and calculate the 
        let protocol_total_supply_on_usd = c::calculate_value(
            clock,
            price_oracle,
            protocol_total_supply,
            storage::get_oracle_id(storage, asset_id)
        );

        ///////////////////////////////////////////////////////////////////////////////////
        // @devs Two things                                                              //
        // 1: Convert the token decimals to 9                                            //    
        // 2: Use the same token decimals as the protocol pool for USD price conversion  //
        ///////////////////////////////////////////////////////////////////////////////////
        let normal_total_supply = pool::convert_amount(total_supply, 6, 9);
        let total_incentive_amount_on_usd = c::calculate_value(clock, price_oracle, (normal_total_supply as u256), funds_oracle_id);

        ////////////////////////////////////////////////////////////////////////////////////////////////
        // @devs Calculate APY                                                                        //
        // Formula: APY = total_incentive_amount / duration * ms_per_year / total_supply of protocol  //
        ////////////////////////////////////////////////////////////////////////////////////////////////
        let apy = ray_math::ray_div(
            ray_math::ray_mul(
                ray_math::ray_div(
                    total_incentive_amount_on_usd,
                    ((end_at - start_at) as u256),
                ),
                (MsPerYear as u256)
            ),
            protocol_total_supply_on_usd,
        );

        let _types = vector::empty<String>();
        let ret = IncentiveAPYInfo {
            asset_id: asset_id,
            apy: apy,
            coin_types: vector::singleton(type_name::into_string(funds_coin_type)),
        };
        ret
    }

    struct IncentivePoolInfoByPhase has copy, drop {
        phase: u64,
        pools: vector<IncentivePoolInfo>,
    }

    const PoolStatusEnabled: u8 = 1;
    const PoolStatusClosed: u8 = 2;
    const PoolStatusNotStarted: u8 = 3;

    public fun get_incentive_pools_group_by_phase(clock: &Clock, incentive: &Incentive, storage: &mut Storage, status: u8, option: u8, user: address): vector<IncentivePoolInfoByPhase> {
        let ret = vector::empty<IncentivePoolInfoByPhase>();
        let now = clock::timestamp_ms(clock);

        let objs = incentive::get_pool_objects(incentive);
        let pool_length = vector::length(&objs);

        while (pool_length > 0) {
            let obj = *vector::borrow(&objs, pool_length-1);
            let (
                id_address,
                phase,
                funds,
                start_at,
                end_at,
                closed_at,
                total_supply,
                option_type,
                asset_id,
                factor,
                _,
                distributed,
                _
            ) = incentive::get_pool_info(incentive, obj);

            if (option != option_type) {
                pool_length = pool_length - 1;
                continue
            };

            if (
                (status == PoolStatusClosed && end_at >= now) ||
                (status == PoolStatusEnabled && (start_at >= now || end_at <= now)) || 
                (status == PoolStatusNotStarted && start_at <= now)
            ) {
                pool_length = pool_length - 1;
                continue
            };

            let (user_supply_balance, user_borrow_balance) = storage::get_user_balance(storage, asset_id, user);

            let (total_supply_balance, total_borrow_balance) = storage::get_total_supply(storage, asset_id);
            if (option == incentive::option_borrow()) {
                total_supply_balance = total_borrow_balance
            };

            let user_effective_amount = incentive::calculate_user_effective_amount(option, user_supply_balance, user_borrow_balance, factor);
            let (_, total_rewards_of_user) = incentive::calculate_one_from_pool(incentive, obj, now, total_supply_balance, user, user_effective_amount);
            let total_claimed_of_user = incentive::get_total_claimed_from_user(incentive, obj, user);

            let info = IncentivePoolInfo {
                pool_id: id_address,
                funds: funds,
                phase: phase,
                start_at: start_at,
                end_at: end_at,
                closed_at: closed_at,
                total_supply: total_supply, // total amont
                asset_id: asset_id,
                option: option,
                factor: factor,
                distributed: distributed,

                total: total_rewards_of_user,
                available: total_rewards_of_user - total_claimed_of_user,
            };

            insert_pools(&mut ret, &info);
            pool_length = pool_length - 1;
        };

        ret
    }

    fun insert_pools(pools: &mut vector<IncentivePoolInfoByPhase>, info: &IncentivePoolInfo) {
        let length = vector::length(pools);

        let is_exist = false;
        while (length > 0) {
            let element = vector::borrow_mut(pools, length-1);
            if (element.phase != info.phase) {
                length = length - 1;
                continue
            };

            vector::push_back(&mut element.pools, *info);
            is_exist = true;
            length = length - 1;
        };

        if (is_exist) {
            return
        };

        let new_info = IncentivePoolInfoByPhase {
            phase: info.phase,
            pools: vector::singleton(*info)
        };

        vector::push_back(pools, new_info)
    }

}