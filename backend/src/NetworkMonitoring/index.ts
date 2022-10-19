import Subnet from "../EVM/Subnet";
import Mainnet from "../EVM/Mainnet";
import {getJSON, writeJSON} from "../util";
import {checkTokenList} from "../Bridge";

const schedule = require('node-schedule');

export default async function NetworkMonitoring(
    eventHandler: any,
    config: Config,
    subnet: Subnet,
    networks: { [key: string]: Mainnet }
) {

    let state = getJSON("state.json")
    state = await sync(state, subnet, networks)
    writeJSON("state.json", state)

    for (let i = 0; i < state.queue.length; i++) {
        if (state.queue[i].method == "BridgeToSubnet") {
            await subnet.bridgeToSubnet(
                state.queue[i].asset,
                state.queue[i].user,
                state.queue[i].amount,
                state.queue[i]._bridgeRequestID,
                state.queue[i].assetName,
                state.queue[i].assetSymbol
            )
            await checkTokenList(state.queue[i].assetSymbol, state.queue[i].asset, state.queue[i].network.name, eventHandler)

        } else {
            await networks[state.queue[i].network.name].bridgeToMainnet(
                state.queue[i].asset,
                state.queue[i].user,
                state.queue[i].amount,
                state.queue[i]._bridgeRequestID,
                state.queue[i].assetName,
            )
        }
        state.queue.splice(i, 1)
        writeJSON("state.json", state)
        i--
    }

    const rule = new schedule.RecurrenceRule();
    rule.second = [0, [0, 15, 30, 45]];

    schedule.scheduleJob(rule, async () => {
        let sub = await subnet.getBlock()
        state.last_block.subnet = sub.number
        for (const i in networks) {
            sub = await networks[i].getBlock()
            state.last_block[i] = sub.number
        }
        writeJSON("state.json", state)
    });
}

async function sync(state: any, subnet: Subnet, networks: { [key: string]: Mainnet }) {
    let subnetQueue = await getQueue("BridgeToMainnet", state.last_block, [subnet])
    let mainnetQueue = await getQueue("BridgeToSubnet", state.last_block, networks)
    let queue = [...subnetQueue, ...mainnetQueue]

    for (let i = 0; i < queue.length; i++) {
        let net = ((queue[i].method == "BridgeToMainnet") ? subnet : networks[queue[i].network.name])
        if (await net.bridgeRequestIsComplete(queue[i]._bridgeRequestID)) {
            queue.splice(i, 1)
            i--
        }
    }
    state.queue = queue
    return state
}

async function getQueue(method: string, block: any, networks: any) {
    let queue: any[] = []
    for (const i in networks) {
        let _queue = await networks[i].sync(block[networks[i].config.name])
        for (const j in _queue) {
            queue.push(
                {
                    method: method,
                    network: networks[i].config,
                    asset: _queue[j].args.asset,
                    user: _queue[j].args.user,
                    _bridgeRequestID: _queue[j].args._bridgeRequestID.toString(),
                    amount: _queue[j].args.amount.toString(),
                    assetName: _queue[j].args.name_,
                    assetSymbol: _queue[j].args.symbol_
                }
            )
        }
    }
    return queue
}
