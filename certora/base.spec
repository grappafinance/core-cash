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
