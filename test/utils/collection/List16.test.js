const { expect } = require('chai')
const { expectRevert } = require('@openzeppelin/test-helpers')

const List16Test = artifacts.require('List16Test');

contract('List16Test', function (deployer) {
  describe('List16Test', function () {
    let list16

    beforeEach(async function () {
      list16 = await List16Test.new()
    })

    async function printRaw(contract, slots) {
      for (let i = 0 ; i < slots ; i ++) {
        let slot = await (contract.provider.getStorageAt(contract.address, i))
        console.log(slot)
      }
    }

    it('init length', async () => {
      expect(await list16.length()).to.be.bignumber.equal('0')
    })

    it('increase length', async () => {
      await list16.setLength(11)
      expect(await list16.length()).to.be.bignumber.equal('11')
      expect(await list16.get(9)).to.be.bignumber.equal('0')
    })

    it('can set length to the same value', async () => {
      await list16.add(7)
      await list16.setLength(1)
      expect(await list16.length()).to.be.bignumber.equal('1')
      expect(await list16.get(0)).to.be.bignumber.equal('7')
    })

    it('cannot decrease length', async () => {
      await list16.add(7)
      await list16.add(7)
      await expectRevert(list16.setLength(1), 'List16Lib: setLength A')
    })

    it('multiple add', async () => {
      for (let i = 0 ; i < 33 ; i++) {
        await list16.addAndTestPos(i + 256, i)
        expect(await list16.length()).to.be.bignumber.equal((i + 1).toString())
      }
      for (let i = 0 ; i < 33 ; i++) {
        expect(await list16.get(i)).to.be.bignumber.equal((i + 256).toString())
      }
    })

    it('single remove', async () => {
      await list16.add(1)
      await list16.remove(0)
      expect(await list16.length()).to.be.bignumber.equal('0')
    })

    it('multiple remove', async () => {
      for (let i = 0 ; i < 43 ; i++) {
        await list16.add(i + 256)
      }
      await list16.remove(0)
      expect(await list16.length()).to.be.bignumber.equal('42')
      expect(await list16.get(0)).to.be.bignumber.equal((42 + 256).toString())

      await list16.remove(15)
      expect(await list16.length()).to.be.bignumber.equal('41')
      expect(await list16.get(15)).to.be.bignumber.equal((41 + 256).toString())

      await list16.remove(18)
      expect(await list16.length()).to.be.bignumber.equal('40')
      expect(await list16.get(18)).to.be.bignumber.equal((40 + 256).toString())

      await list16.remove(35)
      expect(await list16.length()).to.be.bignumber.equal('39')
      expect(await list16.get(35)).to.be.bignumber.equal((39 + 256).toString())

      await list16.remove(38)
      expect(await list16.length()).to.be.bignumber.equal('38')
      expect(await list16.get(37)).to.be.bignumber.equal((37 + 256).toString())
    })

    it('remove all', async () => {
      for (let i = 0 ; i < 33 ; i++) {
        await list16.add(i + 256)
      }
      for (let i = 32 ; i >= 0 ; i--) {
        await list16.remove(Math.floor(Math.random() * i))
      }
      expect(await list16.length()).to.be.bignumber.equal('0')
    })

    it('invalid get', async () => {
      await list16.add(0)
      await expectRevert(list16.get(1), 'List16Lib: getPos A')
    })

    it('invalid remove', async () => {
      await list16.add(0)
      await expectRevert(list16.remove(1), 'List16Lib: removePos A')
    })

    it('set element', async () => {
      await list16.add(1)
      await list16.add(2)
      await list16.add(3)
      await list16.add(4)
      await list16.set(1, 5)
      expect(await list16.length()).to.be.bignumber.equal('4')
      expect(await list16.get(0)).to.be.bignumber.equal('1')
      expect(await list16.get(1)).to.be.bignumber.equal('5')
      expect(await list16.get(2)).to.be.bignumber.equal('3')
      expect(await list16.get(3)).to.be.bignumber.equal('4')
    })

    it('set element at the end', async () => {
      await list16.add(1)
      await list16.add(2)
      await list16.add(3)
      await list16.add(4)
      await list16.set(3, 5)
      expect(await list16.length()).to.be.bignumber.equal('4')
      expect(await list16.get(0)).to.be.bignumber.equal('1')
      expect(await list16.get(1)).to.be.bignumber.equal('2')
      expect(await list16.get(2)).to.be.bignumber.equal('3')
      expect(await list16.get(3)).to.be.bignumber.equal('5')
    })
  })
})
