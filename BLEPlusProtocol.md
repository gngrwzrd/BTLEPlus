# BTLE Plus Serial Service Protocol

The BLEPlus serial protocol is a binary protocol used to exchange data
between two BTLE peers - a central and a peripheral.

This document describes the format and illustrates the messages and
their control flow required.

## Terms

MTU - Maximum transmission unit. Default is 20 bytes.

Packet - A packet is the smallest amount of data transferrable between peers.
A packet's max size in bytes is the MTU.

Window Size - The number of open buffers to send or receive data. Each buffer's
size is MTU.

Part - A part is the entire window of bytes sent or received. This can also
be less than the entire window if the message is even smaller.

## Protocol Messages

The protocol exchanges messages between central and peripheral. The first
byte in each message indicates the protocol message type.

##### Protocol Types

````
PeerInfo           = 1    
Ack                = 2    
NewMessage         = 3    
NewFileMessage     = 4    
EndPart            = 5
EndMessage         = 6       
Resend             = 7    
Data               = 8    
Abort              = 9    
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
Abort:          [protocolType:1]    
````

## Control Flow Examples

The central is always responsible for initiating messages with the peripheral.
The examples below illustrate the flow of messages.

#### Peer Info

Central sends peer info, and peripheral accepts.

|      Central | Peripheral |
|-------------:|------------|
|  PeerInfo -> |            |
|              | <- Ack     |

#### Peer Info

Central sends peer info, peripheral denies and sends it's acceptable
info. When the peripheral sends back a peer info, it's considered
an ACK in this case and the Central must use the provided MTU and
windowSize.

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

#### New Message Control Flow

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


#### Take Turn Sending Messages Flow

Both central and peripheral need to allow each other to send their queued messages.

If the peripheral has messages, and ACK is sent to the central to denote that it will start sending messages.

|     Central | Peripheral |
|------------:|------------|
| TakeTurn -> |            |
|             | <- Ack     |


If the peripheral doesn't have any queued messages, it will respond with another TakeTurn protocol message.

|     Central | Peripheral   |
|------------:|--------------|
| TakeTurn -> |              |
|             | <- Take Turn |
