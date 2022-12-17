const {
  shouldBehaveLikeERC721,
  shouldBehaveLikeERC721Metadata,
  shouldBehaveLikeERC721Enumerable,
} = require('./ERC721id16BatchMint.behavior');
const { runERC721benchmark } = require('./ERC721Benchmark.behavior');

const ERC721id16BatchMint = artifacts.require('ERC721id16BatchMint');

contract('ERC721id16BatchMint', function (accounts) {
  const name = 'Non Fungible Token';
  const symbol = 'NFT';

  beforeEach(async function () {
    var accounts_ = await web3.eth.getAccounts()
    // accounts_[0] is the deployer not present in accounts
    this.token = await ERC721id16BatchMint.new(20000, accounts_[0], name, symbol);
  });

  shouldBehaveLikeERC721('ERC721id16', ...accounts);
  shouldBehaveLikeERC721Metadata('ERC721id16', name, symbol, ...accounts);
  shouldBehaveLikeERC721Enumerable('ERC721id16', ...accounts);
//  runERC721benchmark(...accounts)
});
