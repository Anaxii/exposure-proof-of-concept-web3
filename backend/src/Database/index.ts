const sqlite3 = require('sqlite3').verbose();

export default async function initDatabase() {
    return new Promise(async (ok: any) => {
        let fresh = false
        let db = new sqlite3.Database('backend/storage/database.db', sqlite3.OPEN_READWRITE, async (err: any) => {
            if (err) {
                db = await setupDatabase()
                fresh = true
                console.error("Created new database");
            }
            await createTables(db, fresh)
            db.close()
            ok()
        });
    })
}

async function getDB() {
    return new sqlite3.Database('backend/storage/database.db', sqlite3.OPEN_READWRITE);
}

async function setupDatabase() {
    return new sqlite3.Database("backend/storage/database.db",
        sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE,
        (err: any) => {
            if (err) {
                console.log("Critical error: DB |", err)
                process.exit(1)
            }
        })
}

async function dbCreate(query: string, data: any) {
    let db = await getDB()
    return new Promise(async (ok: any) => {
        if (!data) {
            await db.run(query, (err: any) => {
                ok()
            })
        } else {
            await db.run(query, data, (err: any) => {
                ok()
            })
        }
    })
}

async function createTables(db: any, fresh: boolean) {
    await dbCreate("CREATE TABLE routers(network_name text, dex_name text, contract_address text)", null)
    if (fresh)
        await dbInsert(`INSERT INTO routers(network_name, dex_name, contract_address)
                         VALUES (?, ?, ?)`, ["fuji", "exposure", "0x2D99ABD9008Dc933ff5c0CD271B88309593aB921"])
    await dbCreate("CREATE TABLE tokens(network_name text, token_name text, contract_address text)", null)
    if (fresh)
        await dbInsert(`INSERT INTO tokens(network_name, token_name, contract_address)
                         VALUES (?, ?, ?)`, ["fuji", "WAVAX", "0x72187342BC71CAd08FcCC361ff8336A684dd6883"])
    await dbCreate("CREATE TABLE liquidity_tokens(network_name text, token_name text, contract_address text)", null)
    if (fresh)
        await dbInsert(`INSERT INTO liquidity_tokens(network_name, token_name, contract_address)
                         VALUES (?, ?, ?)`, ["fuji", "WAVAX", "0x72187342BC71CAd08FcCC361ff8336A684dd6883"])
    await dbCreate("CREATE TABLE dollar_coins(network_name text, token_name text, contract_address text)", null)
    if (fresh)
        await dbInsert(`INSERT INTO dollar_coins(network_name, token_name, contract_address)
                         VALUES (?, ?, ?)`, ["fuji", "USDC", "0x803871f6BB32a9C1230cdc182002f8e058791A9A"])
    await dbCreate("CREATE TABLE accounts(account_email text, account_address text)", null)
    await dbCreate("CREATE TABLE prices(token_name text PRIMARY KEY NOT NULL, price bigint, UNIQUE(token_name))", null)
    await dbCreate("CREATE TABLE mcaps(token_name text PRIMARY KEY NOT NULL, mcap bigint, UNIQUE(token_name))", null)
    await dbCreate("CREATE TABLE baskets(basket_name text PRIMARY KEY NOT NULL, contract_address text, UNIQUE(basket_name))", null)
    await dbCreate("CREATE TABLE pairs(network_name text, token_name text, quote_name text, dex_name text, pair_name text, pair_address text, token_address text, quote_address text)", null)
    if (fresh)
        await dbInsert(`INSERT INTO pairs(network_name, token_name, quote_name, dex_name, pair_name, pair_address,
                                           token_address, quote_address)
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                "fuji",
                "WAVAX",
                "USDC",
                "exposure",
                "WAVAX/USDC",
                "0x23Cb1c2582C23C7E45415E290580E7C7e5af7C0D",
                "0x72187342BC71CAd08FcCC361ff8336A684dd6883",
                "0x803871f6BB32a9C1230cdc182002f8e058791A9A",
            ])
}

export async function dbQueryAll(_query: string, data: any) {
    let db = await getDB()
    return new Promise((resolve) => {
        if (data) {
            db.all(_query, data, (err: any, row: any) => {
                db.close()
                if (err) {
                    console.log(err)
                    resolve([])
                }
                resolve(row)
            });
            return
        }
        db.all(_query, (err: any, row: any) => {
            db.close()
            if (err) {
                console.log(err)
                resolve([])
            }
            resolve(row)
        });
    })
}

export async function dbInsert(_query: string, data: any) {
    let db = await getDB()
    return new Promise(async (ok) => {
        await db.run(_query, data, (err: any) => {
            if (err)
                console.log(_query, err)
            ok(null)
            db.close()
        })
    })
}
