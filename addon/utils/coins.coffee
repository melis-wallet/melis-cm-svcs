
SATOSHI = 100000000.0


EXPLORERS =
  main: [
    { id: 'biteasy',  label: 'Biteasy', url: 'https://www.biteasy.com/blockchain/transactions/%h'}
    { id: 'blockcypher',  label: 'Blockcypher', url: 'https://live.blockcypher.com/btc/tx/%h/'}
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

ABC_EXPLORERS =
  main: [
    { id: 'blockchair',  label: 'Blockchair', url: 'https://blockchair.com/bitcoin-abc/transaction/%h'}
  ]

  test: [
  ]

  regtest: [
    { id: 'melis', label: 'melis.io', url: 'https://localhost/test/%h'}
    { id: 'melis2',  label: 'regtest.melis.io', url: 'https://localhost/test2/%h'}    
  ]


LTC_EXPLORERS =
  main: [
    { id: 'blockcypher',  label: 'Blockcypher', url: 'https://live.blockcypher.com/ltc/tx/%h/'}
    { id: 'chainso', label: 'chain.so', url: 'https://chain.so/tx/LTC/%h'}
    { id: 'litecore', label: 'Litecore', url: 'https://insight.litecore.io/tx/%h'}
  ]

  test: [
    { id: 'chainso', label: 'chain.so', url: 'https://chain.so/tx/LTCTEST/%h'}
    { id: 'litecore', label: 'Litecore', url: 'https://testnet.litecore.io/tx/%h'}
  ]

  regtest: [
    { id: 'melis', label: 'melis.io', url: 'https://localhost/test/%h'}
    { id: 'melis2',  label: 'regtest.melis.io', url: 'https://localhost/test2/%h'}
  ]


GRS_EXPLORERS =
  main: [
    { id: 'cryptoid',  label: 'Cryptoid', url: ' https://chainz.cryptoid.info/grs/tx.dws?%h'}
    { id: 'groestlsight',  label: 'Groestlsight', url: 'https://groestlsight.groestlcoin.org/tx/%h'}
  ]

  test: [
     { id: 'cryptoid',  label: 'Cryptoid', url: 'https://chainz.cryptoid.info/grs-test/tx.dws?%h.htm'}
     { id: 'groestlsight',  label: 'Groestlsight', url: ' https://groestlsight-test.groestlcoin.org/tx/%h'}
  ]

  regtest: [
    { id: 'melis', label: 'melis.io', url: 'https://localhost/test/%h'}
    { id: 'melis2',  label: 'regtest.melis.io', url: 'https://localhost/test2/%h'}
  ]

BSV_EXPLORERS =
  main: [
    { id: 'bchsvexploere',  label: 'BCHSV Explorer', url: 'https://bchsvexplorer.com/tx/%h'}
    { id: 'whatsonchain', label: 'whatsonchain', url: 'https://whatsonchain.com/tx/%h'}
  ]

  test: [
    { id: 'bitcoincloud',  label: 'BitcoinCloud', url: 'https://testnet.bitcoincloud.net/tx/%h'}
  ]

  regtest: [
    { id: 'melis', label: 'melis.io', url: 'https://localhost/test/%h'}
    { id: 'melis2',  label: 'regtest.melis.io', url: 'https://localhost/test2/%h'}
  ]

DOGE_EXPLORERS =
  main: [
    { id: 'chainso',  label: 'chain.so', url: 'https://chain.so/tx/DOGE/%h'}
  ]

  test: [
    { id: 'chainso',  label: 'chain.so', url: 'https://chain.so/tx/DOGETEST/%h'}
  ]

  regtest: [
    { id: 'melis', label: 'melis.io', url: 'https://localhost/test/%h'}
    { id: 'melis2',  label: 'regtest.melis.io', url: 'https://localhost/test2/%h'}
  ]



BTC_Subunits = [
  { id: 'BTC', divider: SATOSHI, symbol: 'BTC', precision: 4 }
  { id: 'mBTC', divider: 100000.0, symbol: 'mBTC', ratio: '0.001 btc', precision: 2 }
  { id: 'bits', divider: 100.0, symbol: 'bits', ratio: '0.000001 btc', precision: 0 }
]

BCH_Subunits = [
  { id: 'BCH', divider: SATOSHI, symbol: 'BCH', precision: 4 }
  { id: 'mBCH', divider: 100000.0, symbol: 'mBCH', ratio: '0.001 bch', precision: 2 }
  { id: 'bits', divider: 100.0, symbol: 'bits', ratio: '0.000001 bch', precision: 0 }
]

ABC_Subunits = [
  { id: 'BCHA', divider: SATOSHI, symbol: 'BCHA', precision: 4 }
  { id: 'mBCHA', divider: 100000.0, symbol: 'mBCHA', ratio: '0.001 bcha', precision: 2 }
  { id: 'bits', divider: 100.0, symbol: 'bits', ratio: '0.000001 bcha', precision: 0 }
]

LTC_Subunits = [
  { id: 'LTC', divider: SATOSHI, symbol: 'LTC', precision: 2 }
  { id: 'mLTC', divider: 100000.0, symbol: 'mLTC', ratio: '0.001 ltc', precision: 2 }
]

GRS_Subunits = [
  { id: 'GRS', divider: SATOSHI, symbol: 'GRS', precision: 2 }
  { id: 'mGRS', divider: 100000.0, symbol: 'mGRS', ratio: '0.001 grs', precision: 2 }
  { id: 'groestls', divider: 100.0, symbol: 'groestls', ratio: '0.000001 grs', precision: 0 }
]

BSV_Subunits = [
  { id: 'BSV', divider: SATOSHI, symbol: 'BSV', precision: 4 }
  { id: 'mBSV', divider: 100000.0, symbol: 'mBSV', ratio: '0.001 bsv', precision: 2 }
  { id: 'bits', divider: 100.0, symbol: 'bits', ratio: '0.000001 bsv', precision: 0 }
]

DOGE_Subunits = [
  { id: 'DOGE', divider: SATOSHI, symbol: 'DOGE', precision: 0 }
  { id: 'mDOGE', divider: 100000.0, symbol: 'mDOGE', ratio: '0.001 doge', precision: 0 }
  { id: 'kDOGE', divider: (SATOSHI * 1000.0), symbol: 'kDOGE', ratio: '1000 doge', precision: 2 }
]



BTC_Features = { rbf: true,  unconfirmed: true, defaultUncf: false }
BCH_Features = { rbf: false, unconfirmed: true, defaultUncf: false , altaddrs: true, defaltaddr: true }
ABC_Features = { rbf: false, unconfirmed: true, defaultUncf: false , altaddrs: true, defaltaddr: true }
LTC_Features = { rbf: false, unconfirmed: true, defaultUncf: false }
GRS_Features = { rbf: false, unconfirmed: true, defaultUncf: true }
BSV_Features = { rbf: false, unconfirmed: true, defaultUncf: true, altaddrs: true, defaltaddr: true }
DOGE_Features = { rbf: false, unconfirmed: true, defaultUncf: true }

SupportedCoins = [
  {unit: 'BTC', tsym: 'BTC', label: 'btc', symbol: 'BTC', subunits: BTC_Subunits, dfSubunit: 'mBTC', scheme: 'bitcoin', features: BTC_Features, explorers: EXPLORERS.main }
  {unit: 'TBTC', tsym: 'BTC', label: 'tbtc', symbol: 'BTC', subunits: BTC_Subunits, dfSubunit: 'mBTC', scheme: 'bitcoin', features: BTC_Features, explorers: EXPLORERS.test }
  {unit: 'RBTC', tsym: 'BTC', label: 'rbtc', symbol: 'BTC', subunits: BTC_Subunits, dfSubunit: 'mBTC', scheme: 'bitcoin', features: BTC_Features, explorers: EXPLORERS.regtest }

  {unit: 'BCH', tsym: 'BCH', label: 'bch', symbol: 'BCH', subunits: BCH_Subunits, dfSubunit: 'mBCH', scheme: 'bitcoincash', prefix: 'bitcoincash', features: BCH_Features, explorers: BCH_EXPLORERS.main}  
  {unit: 'TBCH', tsym: 'BCH', label: 'tbch', symbol: 'BCH', subunits: BCH_Subunits, dfSubunit: 'mBCH', scheme: 'bchtest', prefix: 'bchtest', features: BCH_Features, explorers: BCH_EXPLORERS.test}
  {unit: 'RBCH', tsym: 'BCH', label: 'rbch', symbol: 'BCH', subunits: BCH_Subunits, dfSubunit: 'mBCH', scheme: 'bchreg', prefix: 'bchreg', features: BCH_Features, explorers: BCH_EXPLORERS.regtest}

  {unit: 'ABC', tsym: 'ABC', label: 'abc', symbol: 'BCHA', subunits: ABC_Subunits, dfSubunit: 'mBCHA', scheme: 'bitcoincash', prefix: 'bitcoincash', featureSs: ABC_Features, explorers: ABC_EXPLORERS.main}
  {unit: 'TABC', tsym: 'ABC', label: 'tabc', symbol: 'BCHA', subunits: ABC_Subunits, dfSubunit: 'mBCHA', scheme: 'bchtest', prefix: 'bchtest', features: ABC_Features, explorers: ABC_EXPLORERS.test}
  {unit: 'RABC', tsym: 'ABC', label: 'rabc', symbol: 'BCHA', subunits: ABC_Subunits, dfSubunit: 'mBCHA', scheme: 'bchreg', prefix: 'bchreg', features: ABC_Features, explorers: ABC_EXPLORERS.regtest}
  
  {unit: 'LTC', tsym: 'LTC', label: 'ltc', symbol: 'LTC', subunits: LTC_Subunits, dfSubunit: 'mLTC', features: LTC_Features, explorers: LTC_EXPLORERS.main}
  {unit: 'TLTC', tsym: 'LTC', label: 'tltc', symbol: 'LTC', subunits: LTC_Subunits, dfSubunit: 'mLTC', features: LTC_Features, explorers: LTC_EXPLORERS.test}
  {unit: 'RLTC', tsym: 'LTC', label: 'rltc', symbol: 'LTC', subunits: LTC_Subunits, dfSubunit: 'mLTC', features: LTC_Features, explorers: LTC_EXPLORERS.regtest}

  {unit: 'GRS', tsym: 'GRS', label: 'grs', symbol: 'GRS', subunits: GRS_Subunits, dfSubunit: 'GRS', scheme: 'groestlcoin', features: GRS_Features, explorers: GRS_EXPLORERS.main}
  {unit: 'TGRS', tsym: 'GRS', label: 'tgrs', symbol: 'GRS', subunits: GRS_Subunits, dfSubunit: 'GRS', scheme: 'groestlcoin', features: GRS_Features, explorers: GRS_EXPLORERS.test}
  {unit: 'RGRS', tsym: 'GRS', label: 'rgrs', symbol: 'GRS', subunits: GRS_Subunits, dfSubunit: 'GRS', scheme: 'groestlcoin', features: GRS_Features, explorers: GRS_EXPLORERS.regtest}

  {unit: 'BSV', tsym: 'BSV', label: 'bsv', symbol: 'BSV', subunits: BSV_Subunits, dfSubunit: 'mBSV',  scheme: 'bitcoincash', prefix: 'bitcoincash',  features: BSV_Features, explorers: BSV_EXPLORERS.main }
  {unit: 'TBSV', tsym: 'BSV', label: 'tbsv', symbol: 'BSV', subunits: BSV_Subunits, dfSubunit: 'mBSV', scheme: 'bchtest', prefix: 'bchtest', features: BSV_Features, explorers: BSV_EXPLORERS.test }
  {unit: 'RBSV', tsym: 'BSV', label: 'rbsv', symbol: 'BSV', subunits: BSV_Subunits, dfSubunit: 'mBSV', scheme: 'bchreg', prefix: 'bchreg', features: BSV_Features, explorers: BSV_EXPLORERS.regtest }

  {unit: 'DOGE', tsym: 'DOGE', label: 'doge', symbol: 'DOGE', subunits: DOGE_Subunits, dfSubunit: 'DOGE', features: DOGE_Features, explorers: DOGE_EXPLORERS.main }
  {unit: 'TDOG', tsym: 'DOGE', label: 'tdog', symbol: 'DOGE', subunits: DOGE_Subunits, dfSubunit: 'DOGE', features: DOGE_Features, explorers: DOGE_EXPLORERS.test }
  {unit: 'RDOG', tsym: 'DOGE', label: 'rdog', symbol: 'DOGE', subunits: DOGE_Subunits, dfSubunit: 'DOGE', features: DOGE_Features, explorers: DOGE_EXPLORERS.regtest }

]


export { SupportedCoins }