certoraRun src/core/Grappa.sol:Grappa \
    --verify Grappa:certora/Grappa.spec \
    --solc_allow_path src \
    --optimistic_loop \
    --packages  solmate=lib/solmate/src \
                openzeppelin=lib/openzeppelin-contracts/contracts \
                openzeppelin-upgradeable=lib/openzeppelin-contracts-upgradeable/contracts \
                array-lib=lib/array-lib/src
                