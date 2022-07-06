const {calculateCreate2} = require('eth-create2-calculator')
const crypto = require('crypto')

// exclude "node" and "file name"
const myArgs = process.argv.slice(2);
const [deployer, bytecodeHash, zeroBytes] = myArgs;

let salt;

// how many 0s in the string
const zeros = Number(zeroBytes) * 2;

while (true) {
  salt = '0x' + crypto.randomBytes(32).toString('hex')
  const addr = calculateCreate2(deployer, salt, bytecodeHash)
  const leadingBytes = addr.slice(2, 2 + zeros);
  if (leadingBytes === "0".repeat(zeros))   break
  
}

// print the result so ffi can read it
console.log(salt)