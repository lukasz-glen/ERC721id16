const {
  shouldBehaveLikeERC721,
  shouldBehaveLikeERC721Metadata,
} = require('./ERC721S.behavior');
const { runERC721benchmark } = require('./ERC721Benchmark.behavior');

const ERC721Mock = artifacts.require('ERC721MiniAMock');

contract('ERC721', function (accounts) {
  const name = 'Non Fungible Token';
  const symbol = 'NFT';

  beforeEach(async function () {
    this.token = await ERC721Mock.new(name, symbol);
  });

  shouldBehaveLikeERC721('ERC721', ...accounts);
  shouldBehaveLikeERC721Metadata('ERC721', name, symbol, ...accounts);
//  runERC721benchmark(...accounts)
});
