# BTLEPlus Serial Service Protocol

The BTLE+ Serial Service protocol is a binary protocol used to exchange data between two BTLE peers - a central and a peripheral.

This document describes the format and illustrates the messages and their control flow required.

## Terms

MTU - Maximum transmission unit. Default is 20 bytes.

Packet - A packet is the smallest amount of data transferrable between peers. A packet's max size in bytes is the MTU.

Window Size - The number of open buffers to send or receive data. Each buffer's size is MTU.

Part - A part is the entire window of bytes sent or received. This can also be less than the entire window if the message is even smaller.

## Protocol Messages

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

Protocol message fields are stored in network order (big endian).

Sizes are in bytes:

````
Ack:            [protocolType:1]
PeerInfo:       [protocolType:1, mtu:2, windowSize:1]
NewMessage:     [protocolType:1, messageType:1, messageId: 1, expectedSize:8]
NewFileMessage: [protocolType:1, messageType:1, messageId: 1, expectedSize:8]
EndMessage:     [protocolType:1, endMessageWindowSize:1]
EndPart:        [protocolType:1, endPartWindowSize:1]
Resend:         [protocolType:1]
Data:           [protocolType:1, packetCount:1, data:18]
TakeTurn:       [protocolType:1]
Abort:          [protocolType:1]
````

## Responsibilities

By default the central is in control and initiates messages. The central must offer the peripehral a chance to send it's messages by sending TakeTurn messages. See the flow examples below to see how the message exchange works.

## Control Flow Examples

#### Peer Info

At first connection, central sends peer info, and peripheral accepts.

|      Central | Peripheral |
|-------------:|------------|
|  PeerInfo -> |            |
|              | <- Ack     |

If the peripheral can't accept the sizes sent by the central, it responds with it's own acceptable sizes for the central to use. In this example the peer info response is considered the ACK and the central must accept it.

|      Central | Peripheral   |
|-------------:|--------------|
|  PeerInfo -> |              |
|              | <- Peer Info |

#### New Message Control Flow

A single part is transferred. The message was <= a single packet.

|        Central | Peripheral |
|---------------:|------------|
|  NewMessage -> |            |
|                | <- Ack     |
|        Data -> |            |
|  EndMessage -> |            |
|                | <- Ack     |

Multiple parts are transferred.

|        Central | Peripheral |
|---------------:|------------|
|  NewMessage -> |            |
|                | <- Ack     |
|        Data -> |            |
|        Data -> |            |
|    End Part -> |            |
|                | <- Ack     |
|        Data -> |            |
|        Data -> |            |
|  EndMessage -> |            |
|                | <- Ack     |

#### Resend Control Flow

|        Central | Peripheral |
|---------------:|------------|
|  NewMessage -> |            |
|                | <- Ack     |
|        Data -> |            |
|        Data -> |            |
| End Message -> |            |
|                | <- Resend  |
|        Data -> |            |
| End Message -> |            |
|                | <- Ack     |


#### Take Turn Flow

Both central and peripheral need to allow each other to send their queued messages.

By default the central is the controller of turns, it must offer the peripheral a turn to send it's messages.

If the peripheral has messages, it responds with an ACK and takes control.

|     Central | Peripheral |
|------------:|------------|
| TakeTurn -> |            |
|             | <- Ack     |

If the peripheral doesn't have any messages, it will respond with it's own TakeTurn message, and the central must accept and take control. In this case the central either has more messages, or is responsible for sending TakeTurn again when it deems necessary.

|     Central | Peripheral   |
|------------:|--------------|
| TakeTurn -> |              |
|             | <- Take Turn |
|      Ack -> |              |

## Aborting

Aborting happens when there's an internal inconsistency on either side. Abort simply means reset the current message if any to prepare to receive more data, or send more data.

If there's currently no message being transferred, then the peers must completely reset, and start at the PeerInfo negotiation step.
