# BTLEPlus Serial Service Protocol

The BTLEPlus Serial Service protocol is a binary protocol used to exchange data between two BTLE peers - a central and a peripheral.

It's a turn based message system where both the central and peripheral are given turns to send their queued messages.

**MTU** - Maximum transmission unit. This is negotiated when peers are connected.

**Packet** - A packet is the smallest amount of data transferrable between peers. A packet's max size in bytes is the MTU.

**Window Size** - The number of open buffers to send or receive data. Each buffer's size is MTU. This is negotiated when peers are connected.

**Part** - A part is the entire window of bytes sent or received. This can also be less than the entire window if the message is even smaller.

## Protocol Control Messages

Protocol messages are used to control the flow of data and are exchanged between the central and peripheral peers.

Protocol message fields are stored in network order - big endian.

Sizes are in bytes:

````
Ack:            [protocolType:1]
PeerInfo:       [protocolType:1, mtu:2, windowSize:1]
NewMessage:     [protocolType:1, messageType:2, messageId: 1, expectedSize:8]
NewFileMessage: [protocolType:1, messageType:2, messageId: 1, expectedSize:8]
EndMessage:     [protocolType:1, endMessageWindowSize:1]
EndPart:        [protocolType:1, endPartWindowSize:1]
Resend:         [protocolType:1]
Data:           [protocolType:1, packetCount:1, data:18]
TakeTurn:       [protocolType:1]
Reset:          [protocolType:1]
Abort:          [protocolType:1]
````

## Responsibilities

By default the peripheral is in control and initiates messages. The peripheral must offer the central a turn to send it's messages by sending TakeTurn control messages.

### PeerInfo Control Message

The peer info message contains mtu and window size. When first connected the peripheral sends a peer info message with it's mtu and window size to the central.

**The central must accept the mtu and window sizes for sending and receiving messages.**

##### PeerInfo Control Message Exchange Examples

Peripheral sends peer info, and central accepts.

|       Central|Peripheral   |
|-------------:|:------------|
|              | <- PeerInfo |
|       Ack -> |             |

### TakeTurn Control Message

Each peer, the central and peripheral, require a turn to send it's own queued messages. By default the peripheral is in control, and must offer the central it's turn to send it's messages.

If a central accepts and takes control, it can send it's own queued messages, and must offer the turn back to the peripheral.

When the peripheral receives a take turn message it is required to take control back. If it has no messages to send then it must continue to send take turn messages to the central.

##### TakeTurn Control Message Exchange Examples

The peripheral offers a turn to the central, the central has messages to send so it acknowledges the turn and can start sending it's messages.

|      Central|Peripheral   |
|------------:|:------------|
|             | <- TakeTurn |
|      Ack -> |             |

The peripheral offers a turn to the central, but the central doesn't have any messages to send so it responds with a take turn message that the peripheral must accept.

|      Central|Peripheral   |
|------------:|:------------|
|             | <- TakeTurn |
| TakeTurn -> |             |
|             | <- Ack      |

### NewMessage Control Message

Transferring user messages between peers must first be agreed upon. When a peer has it's turn, it can request to send it's next message.

###### NewMessage Control Message Exchange Examples

The central initiates a new message, the peripheral accepts.

|         Central|Peripheral  |
|---------------:|:-----------|
|  NewMessage -> |            |
|                | <- Ack     |

The peripheral requests a new message, the central accepts.

|         Central|Peripheral     |
|---------------:|:--------------|
|                | <- NewMessage |
|         Ack -> |               |

### Wait Control Message

If a peer won't allow a new message, it can indicate to the other peer that it should wait and try again.

###### Wait Control Message Exchange Examples

Here the central has it's turn, but the peripheral won't allow the new message and requires the central to wait longer.

After some time, the new message is tried again, and acknowledged so the central can send it's message.

|         Central|Peripheral  |
|---------------:|:-----------|
|  NewMessage -> |            |
|                | <- Wait    |
|         Ack -> |            |
| .............. |            |
|  NewMessage -> |            |
|                | <- Ack     |

### Data Messages

Once a new message has been acknowledged, the peer can start sending data packets.

##### Data Message Examples

Sending data messages happens in two ways.

|       Central |Peripheral  |
|--------------:|:-----------|
|       Data -> |            |
|       Data -> |            |
|       Data -> |            |
|    EndPart -> |            |
|               | <- Ack     |
|       Data -> |            |
|       Data -> |            |
|       Data -> |            |
| EndMessage -> |            |
|               | <- Ack     |

#### Resend Control Flow

|         Central|Peripheral  |
|---------------:|:-----------|
|  NewMessage -> |            |
|                | <- Ack     |
|        Data -> |            |
|        Data -> |            |
| End Message -> |            |
|                | <- Resend  |
|        Data -> |            |
| End Message -> |            |
|                | <- Ack     |

## Aborting

Aborting happens when there's an internal inconsistency on either side. Abort simply means reset the current message if any to prepare to receive more data, or send more data.

If there's currently no message being transferred, then the peers must completely reset, and start at the PeerInfo negotiation step.

## Complete Message Exchange Examples
