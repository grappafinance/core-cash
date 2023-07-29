/* ======================================= *
 *              Declarations
 * ======================================= */
methods {
    // ID to registered contracts
    function assets(uint8) external returns(address, uint8) envfree; 
    function engines(uint8) external returns(address) envfree;
    function oracles(uint8) external returns(address) envfree;
    // address to ID
    function assetIds(address) external returns(uint8) envfree;
    function engineIds(address) external returns(uint8) envfree;
    function oracleIds(address) external returns(uint8) envfree;

    function lastAssetId() external returns(uint8) envfree;
    function lastEngineId() external returns(uint8) envfree;
    function lastOracleId() external returns(uint8) envfree;
}

function asset_is_empty(uint8 id) returns bool {
    address addr; uint8 decimals;
    addr, decimals = assets(id);
    return addr == 0 && decimals == 0;
}

/* ======================================= *
 *               Invariants
 * ======================================= */

/**
 * Description: assets[0] must return address(0)
 */
invariant assetZeroIsEmpty() asset_is_empty(0) filtered { f -> f.selector != sig:upgradeToAndCall(address,bytes).selector }


/**
 * Description: engines[0] must return address(0)
 */
invariant engineZeroIsEmpty() engines(0) == 0 filtered { f -> f.selector != sig:upgradeToAndCall(address,bytes).selector }

/**
 * Description: oralces[0] must return address(0)
 */
invariant oracleZeroIsEmpty() engines(0) == 0 filtered { f -> f.selector != sig:upgradeToAndCall(address,bytes).selector }
