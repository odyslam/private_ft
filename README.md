## Private Voting in Friend.Tech

Using [Semaphores](https://semaphore.pse.dev/), we can create polls that only people that have our Friend.Tech key can participate in.

## How to

- You create a poll **onchain**
- People join the poll **onchain**, using an Semaphore identity they have generated **offchain**. When joining the poll, the contract verifies that `msg.sender` owns at least a key`
- People can vote in the poll by supplying a proof that have generated **offchain**
- You end the poll **onchain**

**Disclaimer**: This is probably gameable as people can join a poll to vote in it and then sell their keys. As long as they have keys when joining a poll, they can vote in it.

## Install

1. `git clone https://github.com/private_ft`
2. `bun add @semaphore-protocol/contracts`

## Testing

Lol no, this is just a PoC

# License

MIT
