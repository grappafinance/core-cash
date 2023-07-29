import "base.spec";

/* ======================================= *
 *           Property functions
 * ======================================= */

function asset_is_empty(uint8 id) returns bool {
    address addr; uint8 decimals;
    addr, decimals = assets(id);
    return addr == 0 && decimals == 0;
}

function asset_id_map_match(uint8 id) returns bool {
    require id != 0;
    address addr;
    addr, _ = assets(id);
    return (addr != 0) => assetIds(addr) == id;
}

function oracle_id_map_match(uint8 id) returns bool {
    require id != 0;
    address oracle;
    oracle = oracles(id);
    return (oracle != 0) => oracleIds(oracle) == id;
}

function engine_id_map_match(uint8 id) returns bool {
    require id != 0;
    address engine;
    engine = engines(id);
    return (engine != 0) => engineIds(engine) == id;
}

function no_duplicate_assets(uint8 id1, uint8 id2) returns bool {
    require id1 != id2;
    address addr1; address addr2;
    addr1, _ = assets(id1);
    addr2, _ = assets(id2);
    return (addr1 != 0 && addr2 != 0) => addr1 != addr2;
}

function no_duplicate_oracles(uint8 id1, uint8 id2) returns bool {
    require id1 != id2;
    address addr1; address addr2;
    addr1 = oracles(id1);
    addr2 = oracles(id2);
    return (addr1 != 0 && addr2 != 0) => addr1 != addr2;
}

function no_duplicate_engines(uint8 id1, uint8 id2) returns bool {
    require id1 != id2;
    address addr1; address addr2;
    addr1 = engines(id1);
    addr2 = engines(id2);
    return (addr1 != 0 && addr2 != 0) => addr1 != addr2;
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


/**
 * Description: querying assets with [id], must return the address than can be queried with `assetIds` and result in id
 */
invariant assetIdMapMatches(uint8 id) asset_id_map_match(id) filtered { f -> f.selector != sig:upgradeToAndCall(address,bytes).selector }

/**
 * Description: querying engines with [id], must return the address than can be queried with `engineIds` and result in id
 */
invariant engineIdMapMatches(uint8 id) engine_id_map_match(id) filtered { f -> f.selector != sig:upgradeToAndCall(address,bytes).selector }

/**
 * Description: querying oracles with [id], must return the address than can be queried with `oracleIds` and result in id
 */
invariant oracleIdMapMatches(uint8 id) oracle_id_map_match(id) filtered { f -> f.selector != sig:upgradeToAndCall(address,bytes).selector }


/**
 * Description: cannot have two ids pointing to the same asset
 */
invariant noDuplicateAssets(uint8 id1, uint8 id2) no_duplicate_assets(id1, id2) filtered { f -> f.selector != sig:upgradeToAndCall(address,bytes).selector } {
    preserved {
        requireInvariant assetIdMapMatches(id1);
        requireInvariant assetIdMapMatches(id2);
    }
}

/**
 * Description: cannot have two ids pointing to the same oracle
 */
invariant noDuplicateOracles(uint8 id1, uint8 id2) no_duplicate_oracles(id1, id2) filtered { f -> f.selector != sig:upgradeToAndCall(address,bytes).selector } {
    preserved {
        requireInvariant oracleIdMapMatches(id1);
        requireInvariant oracleIdMapMatches(id2);
    }
}

/**
 * Description: cannot have two ids pointing to the same engine
 */
invariant noDuplicateEngines(uint8 id1, uint8 id2) no_duplicate_engines(id1, id2) filtered { f -> f.selector != sig:upgradeToAndCall(address,bytes).selector } {
    preserved {
        requireInvariant engineIdMapMatches(id1);
        requireInvariant engineIdMapMatches(id2);
    }
}