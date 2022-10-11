<h1>Exposure Proof of Concept Web3</h1>
<p>This repo is the proof of concept version of the Exposure Permissioned DeFi network. All code is for
demonstration purposes and should not be used for prod.<p>
<h2>Backend directory</h2>
<p>A script that fulfills swap requests, updates mainnet oracles, and relays mainnet pricing data to the subnet.</p>
<h3>Tests with jest</h3>
<p>npm test --runInBand<br/>--runInBand is required to run tests sequentially (avoid nonce errors)</p>
<h2>Truffle directory</h2>
<p>All PoC contracts and their tests to ensure they are in working order.</p>
<h3>Truffle Testing</h3>
<p>
1. Start a ganache network on 127.0.0.1:8545<br/>
2. run `truffle migrate`<br/>
3. run `truffle test`
</p>

