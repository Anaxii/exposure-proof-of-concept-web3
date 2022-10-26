import {Network} from "./Network";
import {dbInsert, dbQueryAll} from "../Database";

const {ethers} = require("ethers");

export default class Mainnet extends Network {

    constructor(config: NetworkInterface, eventHandler: any, privateKey: string) {
        super(config, eventHandler, privateKey)
        this.monitor()
    }

    private async monitor() {
        const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
        try {
            contract.on("BridgeToSubnet", (user: any, asset: any, amount: any, _bridgeRequestID: any, assetName: any, assetSymbol: any, event: any) => {
                this.eventHandler.emit('BridgeToSubnet', {
                    network: this.config,
                    user,
                    asset,
                    amount: amount.toString(),
                    _bridgeRequestID: _bridgeRequestID.toString(),
                    assetName,
                    assetSymbol
                });
            });
            let baskets: any = await dbQueryAll("SELECT * FROM baskets", null)
            for (const i in baskets) {
                contract.on("UpdateSubnet", (event: any) => {
                    this.eventHandler.emit('NewPendingBasketTradesComplete', {
                        network: this.config,
                        basket: baskets[i].contract_address,
                    });
                });
            }
        } catch (err: any) {
            console.log("Critical error", this.config, err)
            process.exit()
        }
    }

    async bridgeToSubnet(amount: string, address: string) {
        const signer = new ethers.Wallet(this.privateKey, this.provider)
        try {
            let contract = new ethers.Contract(address, this.abi, this.provider);
            const tokenContract = contract.connect(signer)
            let tx = tokenContract.approve(this.config.bridge_address, amount)
            await tx.wait(2)

            contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            const bridgeContract = contract.connect(signer)
            tx = await bridgeContract.bridgeToSubnet(amount, address)
            await tx.wait(2)

            console.log(`Send bridge request on mainnet for token ${address}`)
            return true
        } catch (err: any) {
            return false
        }
    }

    async bridgeToMainnet(asset: string, user: string, amount: string, _bridgeRequestID: string, symbol: string) {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)
            let tx = await contractWithSigner.bridgeToMainnet(asset, user, amount, _bridgeRequestID)
            await tx.wait(2)
            console.log(`Bridged ${amount} (1e18) ${symbol} to ${this.config.name} (mainnet) for ${user} (requestID: ${_bridgeRequestID})`)
            return true
        } catch (err: any) {
            console.log(err)
            return false
        }
    }

    async updatePrices(pair: string[], asset: string[], quote: string[]) {
        try {
            const contract = new ethers.Contract(this.config.oracle, this.abi, this.provider);
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)
            let tx = await contractWithSigner.updateMultiple(pair, asset, quote)
            await tx.wait(2)
            console.log(`Updated some mainnet prices (batched)`)
            return true
        } catch (err: any) {
            console.log(err)
            return false
        }
    }

    async getPairAddress(router: string, token: string, quote: string) {
        try {
            const routerContract = new ethers.Contract(router, this.abi, this.provider);
            let factory = await routerContract.factory()

            const factoryContract = new ethers.Contract(factory, this.abi, this.provider);
            return await factoryContract.getPair(token, quote)
        } catch {
                return ""
        }
    }

    async getSubnetProductAddress(product: string) {
        try {
            const bridge = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            return await bridge.subnetProductAssetsAddress.call(product)
        } catch {
                return ""
        }
    }

    async sync(startBlock: any) {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            let endBlock = await this.getBlock();
            endBlock = endBlock.number
            let allEvents: any[] = [];

            for (let i = startBlock; i < endBlock; i += 5000) {
                const _startBlock = i;
                const _endBlock = Math.min(endBlock, i + 4999);
                const events = await contract.queryFilter("BridgeToSubnet", _startBlock, _endBlock);
                allEvents = [...allEvents, ...events]
            }
            return allEvents
        } catch (err: any) {
            console.log("Critical error", this.config, err)
            process.exit()
        }
    }

    async verify(_hashedMessage: string, _v: any, _r: string, _s: string, account: string, email: string) {
        try {
            let contract = new ethers.Contract("0xF686F5D7165e8Ce1C606978F424a2DBd4a37e122", this.abi, this.provider);
            let addy = await contract.VerifyMessage.call(null, _hashedMessage, _v, _r, _s)
            if (addy == account) {

            }
            contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)
            await contractWithSigner.setAllowed(account, true)
            await dbInsert(`INSERT INTO accounts(account_email, account_address)
                         VALUES (?, ?)`, [email, account])        } catch (err: any) {
            console.log("verify", account, err)
        }
    }

}
