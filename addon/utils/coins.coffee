
SATOSHI = 100000000.0


EXPLORERS =
  main: [
    { id: 'biteasy',  label: 'Biteasy', url: 'https://www.biteasy.com/blockchain/transactions/%h'}
    { id: 'blockcypher:',  label: 'Blockcypher', url: 'https://live.blockcypher.com/btc/tx/%h/'}
    { id: 'blockchain', label: 'Blockchain.info', url: 'https://blockchain.info/tx/%h'}
    { id: 'blocktrail', label: 'BlockTrail', url: 'https://www.blocktrail.com/BTC/tx/%h'}
    { id: 'chainso', label: 'chain.so', url: 'https://chain.so/tx/BTC/%h'}
    { id: 'blockchair', label: 'blockchair.com', url: 'https://blockchair.com/bitcoin/transaction/%h'}
  ]

  test: [
    { id: 'blocktrail',  label: 'BlockTrail', url: 'https://www.blocktrail.com/tBTC/tx/%h'}
  ]

  regtest: [
    { id: 'melis', label: 'melis.io', url: 'https://localhost/test/%h'}
    { id: 'melis2',  label: 'regtest.melis.io', url: 'https://localhost/test2/%h'}
  ]

BCH_EXPLORERS =
  main: [
    { id: 'blockchair',  label: 'Blockchair', url: 'https://blockchair.com/bitcoin-cash/transaction/%h'}
    { id: 'bitpay',  label: 'Bitpay', url: 'https://bch-insight.bitpay.com/tx/%h'}
    { id: 'btccom',  label: 'BTC.com', url: 'https://bch.btc.com/%h'}
  ]

  test: [
    { id: 'blocktrail',  label: 'Blocktrail', url: 'https://www.blocktrail.com/tBCC/tx/%h'}
  ]

  regtest: [
    { id: 'melis', label: 'melis.io', url: 'https://localhost/test/%h'}
    { id: 'melis2',  label: 'regtest.melis.io', url: 'https://localhost/test2/%h'}
  ]

BTC_Subunits = [
  { id: 'BTC', divider: SATOSHI, symbol: 'BTC' }
  { id: 'mBTC', divider: 100000.0, symbol: 'mBTC', ratio: '0.001 btc' }
  { id: 'bits', divider: 100.0, symbol: 'bits', ratio: '0.000001 btc' }
]

BCH_Subunits = [
  { id: 'BCH', divider: SATOSHI, symbol: 'BCH' }
  { id: 'mBCH', divider: 100000.0, symbol: 'mBCH', ratio: '0.001 bch' }
  { id: 'bits', divider: 100.0, symbol: 'bits', ratio: '0.000001 bch' }
]

BTC_Features = { rbf: true }
BCH_Features = { rbf: false }

SupportedCoins = [
  {unit: 'BTC', tsym: 'BTC', label: 'btc', symbol: 'BTC', subunits: BTC_Subunits, dfSubunit: 'mBTC', features: BTC_Features, explorers: EXPLORERS.main }
  {unit: 'TBTC', tsym: 'BTC', label: 'tbtc', symbol: 'BTC', subunits: BTC_Subunits, dfSubunit: 'mBTC', features: BTC_Features, explorers: EXPLORERS.test }
  {unit: 'RBTC', tsym: 'BTC', label: 'rbtc', symbol: 'BTC', subunits: BTC_Subunits, dfSubunit: 'mBTC', features: BTC_Features, explorers: EXPLORERS.regtest }
  {unit: 'BCH', tsym: 'BCH', label: 'bch', symbol: 'BCH', subunits: BCH_Subunits, dfSubunit: 'mBCH', features: BCH_Features, explorers: BCH_EXPLORERS.main}
  {unit: 'TBCH', tsym: 'BCH', label: 'tbch', symbol: 'BCH', subunits: BCH_Subunits, dfSubunit: 'mBCH', features: BCH_Features, explorers: BCH_EXPLORERS.test}
  {unit: 'RBCH', tsym: 'BCH', label: 'rbch', symbol: 'BCH', subunits: BCH_Subunits, dfSubunit: 'mBCH', features: BCH_Features, explorers: BCH_EXPLORERS.regtest}
]


export { SupportedCoins }