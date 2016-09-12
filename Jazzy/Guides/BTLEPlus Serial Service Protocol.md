# BTLEPlus Serial Service Protocol

The BTLEPlus Serial Service protocol is a binary protocol used to exchange data between two BTLE peers - a central and a peripheral.

It's a turn based message system where both the central and peripheral are given turns to send their queued messages.

**MTU** - Maximum transmission unit. This is negotiated when peers are connected.

**Packet** - A packet is the smallest amount of data transferrable between peers. A packet's max size in bytes is the MTU.

**Window Size** - The number of open buffers to send or receive data. Each buffer's size is MTU. This is negotiated when peers are connected.

**Part** - A part is the entire window of bytes sent or received. This can also be less than the entire window if the message is even smaller.

## Protocol Control Messages

Protocol messages are used to control the flow of data and are exchanged between the central and peripheral peers.

##### Protocol Types

````
PeerInfo           = 1
Ack                = 2
NewMessage         = 3
NewFileMessage     = 4
EndPart            = 5
EndMessage         = 6
Data               = 7
Resend             = 8
TakeTurn           = 9
Abort              = 10
````

##### Protocol Control Message Formats

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
Abort:          [protocolType:1]
````

## Responsibilities

By default the central is in control and initiates messages. The central must offer the peripheral a turn to send it's messages by sending TakeTurn messages. See the flow examples below to see how the message exchange works.

## Messages

### Peer Info

The peer info message contains mtu and window size. When first connected the peripheral sends a peer info message with it's mtu and window size to the central. The central must accept the mtu and window sizes for sending and receiving messages.

##### Peer Info Exchange Examples

Peripheral sends peer info, and central accepts.

|       Central|Peripheral   |
|-------------:|:------------|
|              | <- PeerInfo |
|       Ack -> |             |

### Take Turn Message

Each peer, the central and peripheral, require a turn to send it's own queued messages. By default the central is in control, and must offer the peripheral it's turn to send it's messages.

If a peripheral accepts and takes control, it can send it's own queued messages, and must offer the turn back to the central.

When the central receives a take turn message it is required to take control back. If it has no messages to send then it must continue to send take turn messages to the peripheral.

##### Take Turn Message Examples

The central offers a turn to the peripheral, because the peripheral has messages it accepts and takes control.

|      Central|Peripheral  |
|------------:|:-----------|
| TakeTurn -> |            |
|             | <- Ack     |

The central offers a turn to the peripheral, but the peripheral doesn't have any messages to send to it responds with a take turn message that the central must accept.

|      Central|Peripheral    |
|------------:|:-------------|
| TakeTurn -> |              |
|             | <- Take Turn |
|      Ack -> |              |

### New Messages

Transferring messages between peers must first be agreed upon. New message requests indicate to the central and peripheral that they should set their internal state to start sending, or start receiving packets.

##### New Message Examples

The central initiates a new message, the peripheral accepts.

|         Central|Peripheral  |
|---------------:|:-----------|
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
