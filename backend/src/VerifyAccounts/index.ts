import Subnet from "../EVM/Subnet";
import Mainnet from "../EVM/Mainnet";

const express = require('express')
const app = express()
const cors = require('cors')

app.use(express.json())
app.use(cors())
export default async function VerifyAccounts(eventHandler: any, config: any, subnet: Subnet, networks: { [key: string]: Mainnet }) {
    api(eventHandler, config, networks)
}

async function api(eventHandler: any, config: any, networks: { [key: string]: Mainnet }) {
    app.post('/verify', async (req: any, res: any) => {
        console.log(req.body)
        if (!req.body.hashedMessage || !req.body.account || !req.body.message || !req.body.r || !req.body.s || !req.body.v) {
            res.send(JSON.stringify({status: false}))
            return
        }
        res.send(JSON.stringify({status: true}))
        await networks["fuji"].verify(req.body.hashedMessage, req.body.v, req.body.r, req.body.s, req.body.account, req.body.message)
    })

    app.listen('8080')
}
