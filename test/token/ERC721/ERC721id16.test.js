const {
  shouldBehaveLikeERC721,
  shouldBehaveLikeERC721Metadata,
  shouldBehaveLikeERC721Enumerable,
} = require('./ERC721.behavior');
const { runERC721benchmark } = require('./ERC721Benchmark.behavior');

const ERC721Mock = artifacts.require('ERC721id16Mock');

contract('ERC721id16Mock', function (accounts) {
  const name = 'Non Fungible Token';
  const symbol = 'NFT';

  beforeEach(async function () {
    this.token = await ERC721Mock.new(name, symbol);
  });

  shouldBehaveLikeERC721('ERC721id16', ...accounts);
  shouldBehaveLikeERC721Metadata('ERC721id16', name, symbol, ...accounts);
  shouldBehaveLikeERC721Enumerable('ERC721id16', ...accounts);
//  runERC721benchmark(...accounts)
});
