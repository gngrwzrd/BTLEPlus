//
//  BTLEPlusSerialServiceController.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 8/27/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
BTLEPlusSerialServiceControllerMode indicates which mode a
serial service controller is running in.
*/
@objc public enum BTLEPlusSerialServiceRunMode :UInt8 {
	/// Bluetooth LE Central - The client in BTLE.
	case Central = 1
	
	/// Bluetooth LE Peripheral - The server in BTLE.
	case Peripheral = 2
}

/**
BTLEPlusSerialServiceControllerDelegate is the protocol you implement to
receive events from a serial service controller.
*/
@objc public protocol BTLEPlusSerialServiceControllerDelegate {
	
	/**
	When the serial service controller needs to send
	data it asks the delegate to send it.
	
	- parameter controller:			BTLEPlusSerialServiceController
	- parameter wantsToSendData:	The data to send.
	*/
	func serialServiceController(controller:BTLEPlusSerialServiceController, wantsToSendData data:NSData)
	
	/**
	Whether or not the serial service can continue accepting
	and processing messages from it's peer.
	
	This is a hook that gets called everytime a new message is
	being requested by the peer.
	
	It allows you to communicate to the peer that it should wait
	and try again.
	
	This will continue to be called every time the peer retries
	sending it's messages.
	
	Returning **false** will send a wait message to the peer.
	
	Returning **true** will allow the serial service controller
	to accept and process more messages.
	
	- parameter controller:	BTLEPlusSerialServiceController
	
	- returns: Bool
	*/
	optional func serialServiceControllerCanAcceptMoreMessages(controller:BTLEPlusSerialServiceController) -> Bool
	
	/**
	Whether or not the serial service controller should offer
	a turn to the peer so it can send it's queued messages.
	
	This is intended to be used when some exceptional condition is
	happening and you don't want to offer a turn to the peer.
	But most of the time you should return true.
	
	- parameter controller:	BTLEPlusSerialServiceController
	
	- returns: Bool
	*/
	optional func serialServiceControllerShouldOfferTurnToPeer(controller:BTLEPlusSerialServiceController) -> Bool
	
	/**
	Called when a peer reset and dropped the current message.
	
	- parameter controller:							BTLEPlusSerialServiceController
	- parameter droppedMessageFromPeerReset:	The message that was dropped.
	*/
	optional func serialServiceController(controller:BTLEPlusSerialServiceController, droppedMessageFromPeerReset message:BTLEPlusSerialServiceMessage)
	
	/**
	Called when a reset was called locally which drops the
	current message.
	
	- parameter controller:	BTLEPlusSerialServiceController
	- parameter message:		The message that was dropped.
	*/
	optional func serialServiceController(controller:BTLEPlusSerialServiceController, droppedMessageFromReset message:BTLEPlusSerialServiceMessage)
	
	//TODO: I think this is how I can do file resume logic..
	//func serialServiceController(controller:BTLEPlusSerialServiceController, fileForWritingMessage message:BTLEPlusSerialServiceMessage) -> NSFileHandle
	//func serialServiceController(controller:BTLEPlusSerialServiceController, fileForReadingMessage message:BTLEPlusSerialServiceMessage) -> NSFileHandle
	
	/**
	When a message was entirely sent, and received by the peer.
	
	- parameter controller: BTLEPlusSerialServiceController
	- parameter message:    The message that was sent.
	*/
	optional func serialServiceController(controller:BTLEPlusSerialServiceController, sentMessage message:BTLEPlusSerialServiceMessage)
	
	/**
	When a message has been completely received.
	
	- parameter controller: BTLEPlusSerialServiceController
	- parameter message:    The message that was received.
	*/
	func serialServiceController(controller:BTLEPlusSerialServiceController, receivedMessage message:BTLEPlusSerialServiceMessage)
}

/**
The BTLEPlusSerialServiceController manages packet data for
the binary serial service protocol.

The controller handles creating and parsing data packets for
you, but it relies on you to transmit the data, and relies on
you to notify the controller when data is received.

The controller is agnostic of the transmission mechanism.

#### Transmitting Raw Data Packets

It's up to you to send the data, you must implement the
_serialServiceController(_wantsToSendData:)_ delegate method
to transmit data for the serial controller.

#### Receiving Raw Data Packets

When you receive raw data, you call _receive()_.

#### Sending Custom Messages

You send custom messages that contain user data with instances
of BTLEPlusSerialServiceMessage.

Call _send()_ and messages are queued to be sent.

If there is currently no activity it will attempt to send.

Only one message at a time is transmitted between peers.

#### Receiving Messages

Once an entire message has been received, it's passed to you as
a delegate callback.

*/
@objc public class BTLEPlusSerialServiceController : NSObject {
	
	//MARK: - Configuration
	
	/// The delegate object that you want to receive serial service events.
	public var delegate:BTLEPlusSerialServiceControllerDelegate?
	
	/// The delegate callback queue.
	private var delegateQueue:dispatch_queue_t
	
	/// The maximum data transmission length.
	///
	/// Changing this value triggers a peer information exchange and it's not
	/// recommended to change this value frequently.
	///
	/// When it's changed the controller sends the new mtu to it's peer. The peer can
	/// either accept and use the new mtu, or, if too large, the peer will send back
	/// it's smaller mtu which the controller is required to use.
	///
	/// Because of the peer information exchange, it's not guaranteed that the mtu
	/// you set will be used. If one of the peers requires a smaller mtu, that will
	/// be used instead.
	///
	/// The peer information exchange will not happen immediately, it happens
	/// after any messages being transmitted finish.
	public var mtu:BTLEPlusSerialServiceMTU_Type = BTLEPlusSerialServiceDefaultMTU
	
	/// The number of open buffers to send or receive. Total bytes availabe to
	/// send or receive is windowSize * mtu.
	///
	/// Changing this value triggers a peer information exchange and it's not
	/// recommended to change this value frequently.
	///
	/// When it's changed the controller sends the new windowSize to it's peer. The peer can
	/// either accept and use the new windowSize, or, if too large, the peer will send back
	/// it's smaller windowSize which the controller is required to use.
	///
	/// Because of the peer information exchange, it's not guaranteed that the windowSize
	/// you set will be used. If one of the peers requires a smaller windowSize, that will
	/// be used instead.
	///
	/// The peer information exchange will not happen immediately, it happens
	/// after any messages being transmitted finish.
	public var windowSize:BTLEPlusSerialServiceWindowSize_Type {
		get {
			return _windowSize
		} set(new) {
			if new > BTLEPlusSerialServiceMaxWindowSize {
				_windowSize = BTLEPlusSerialServiceMaxWindowSize
			} else {
				_windowSize = new
			}
		}
	}
	private var _windowSize:BTLEPlusSerialServiceWindowSize_Type = BTLEPlusSerialServiceDefaultWindowSize
	
	/// The repeat interval to offer turns to the peer.
	public var offerTurnInterval:NSTimeInterval = 1
	
	/// The timeout before resending any waiting control packets.
	public var resendTimeout:NSTimeInterval = 3
	
	/// When resume is called if this block is set it's called.
	private var resumeBlock:(()->Void)?
	
	/// Whether or not we're currently connected.
	private var isPaused = false
	
	/// Whether or not packet sending is paused, this is used as a way to immediately stop
	/// packet sending if the controller is paused while in the send packets loop.
	private var pausePackets = false
	
	/// Whether or not peer info has been discovered.
	private var hasDiscoverdPeerInfo = false
	
	/// The protocol messages that are allowed to be received. This is used instead
	/// of a state machine so that known responses to control messages are allowed,
	/// and responses to protocol messages that are out of order or incorrect are filtered
	/// out.
	private var acceptFilter:[BTLEPlusSerialServiceProtocolMessageType]! = [.PeerInfo,.Ack]
	
	/// Serial dispatch queue for processing activity.
	private var serialQueue:dispatch_queue_t
	
	/// Queue for sending user messages
	private var messageQueue:[BTLEPlusSerialServiceMessage]?
	
	/// The current message, either being sent or received.
	private var currentMessage:BTLEPlusSerialServiceMessage?
	
	/// Current control message that was sent.
	private var currentSendControl:BTLEPlusSerialServiceProtocolMessage?
	
	/// The current message receiver that's receiving data from the client or server.
	//private var currentReceiveMessage:BTLEPlusSerialServiceMessage?
	
	/// A timer to wait for responses like acks.
	private var resendCurrentControlTimer:NSTimer?
	
	/// The mode this controller is running as.
	private var mode:BTLEPlusSerialServiceRunMode = .Peripheral
	
	/// The mode for whoever's turn it is.
	private var turnMode:BTLEPlusSerialServiceRunMode = .Peripheral
	
	/// A timer that keeps track of when to offer the peer a turn.
	private var offerTurnTimer:NSTimer?
	
	//MARK: - Initializing a Serial Service Controller
	
	/**
	Initialize a serial service controller with it's run mode.
	
	- parameter mode:	The run mode for the serial service.
	
	- returns: BTLEPlusSerialServiceController
	*/
	public init(withRunMode mode:BTLEPlusSerialServiceRunMode) {
		self.mode = mode
		messageQueue = []
		serialQueue = dispatch_queue_create("com.btleplus.SerialServiceController", DISPATCH_QUEUE_SERIAL)
		delegateQueue = dispatch_get_main_queue()
		super.init()
	}
	
	/**
	Initialize a serial service with it's run mode and a custom delegate queue to receive
	callbacks on.
	
	- parameter mode: The run mode for the serial service.
	- parameter queue: A queue for delegate messages to callback on.
	
	- returns: BTLEPlusSerialServiceController
	*/
	public init(withRunMode mode:BTLEPlusSerialServiceRunMode, delegateQueue queue:dispatch_queue_t) {
		messageQueue = []
		self.mode = mode
		serialQueue = dispatch_queue_create("com.btleplus.SerialServiceController", DISPATCH_QUEUE_SERIAL)
		delegateQueue = queue
		super.init()
	}
	
	//MARK: - Timers
	
	/// Start the offer turn timer.
	func startOfferTurnTimer() {
		if self.offerTurnTimer != nil {
			return
		}
		print("startOfferTurnTimer")
		let timer = NSTimer(timeInterval: offerTurnInterval, target: self, selector: #selector(BTLEPlusSerialServiceController.offerTurnTimeout(_:)), userInfo: nil, repeats: true)
		self.offerTurnTimer = timer
		NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSDefaultRunLoopMode)
	}
	
	// Stops the offer turn timer
	func stopOfferTurnTimer() {
		self.offerTurnTimer?.invalidate()
		self.offerTurnTimer = nil
	}
	
	/// When offer turn timer expires.
	func offerTurnTimeout(timer:NSTimer) {
		dispatch_async(serialQueue) {
			if self.turnMode == self.mode {
				
				//ask the delegate if it's ok to offer a turn.
				if let askOfferTurn = self.delegate?.serialServiceControllerShouldOfferTurnToPeer {
					if !askOfferTurn(self) {
						self.startOfferTurnTimer()
						return
					}
				}
				
				if self.mode == .Central && self.currentMessage == nil && self.currentSendControl == nil {
					self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Reset])
				}
				
				if self.mode == .Peripheral && self.currentMessage == nil && self.currentSendControl == nil {
					self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Reset])
				}
			}
		}
	}
	
	/// Starts the wait timer.
	func startResendControlMessageTimer() {
		resendCurrentControlTimer?.invalidate()
		let timer = NSTimer(timeInterval: resendTimeout, target: self, selector: #selector(BTLEPlusSerialServiceController.resendControlMessageTimerTimeout(_:)), userInfo: nil, repeats: false)
		resendCurrentControlTimer = timer
		NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSDefaultRunLoopMode)
	}
	
	/// Stop the resend control timer.
	func stopResendControlMessageTimer() {
		resendCurrentControlTimer?.invalidate()
		resendCurrentControlTimer = nil
	}
	
	/// Wait timer timeout.
	func resendControlMessageTimerTimeout(timer:NSTimer?) {
		dispatch_async(serialQueue) {
			if let currentSendControl = self.currentSendControl {
				self.delegate?.serialServiceController(self, wantsToSendData: currentSendControl.data!)
			}
		}
	}
	
	//MARK: - Controlling the Serial Service
	
	/// Call this when you're connected to a peer and able to transmit data.
	///
	/// If the controller was previously paused, the controller will continue from
	/// where it was paused.
	public func resume() {
		dispatch_async(serialQueue) {
			print("resume: set isPaused = false")
			self.isPaused = false
			self.pausePackets = false
			if self.resumeBlock != nil {
				self.resumeBlock?()
			} else {
				self.startSending()
			}
		}
	}
	
	/// Call this when you're no longer connected to a peer and want to pause processing
	/// messages.
	///
	/// The current state of the controller is maintained and will continue where it
	/// left off when _resume()_ is called.
	public func pause() {
		//pausePackets is specifically left out of the serial queue so that the loop
		//in startSendingPackets will exit early if resume ever called while
		//that loop is running.
		pausePackets = true
		dispatch_async(serialQueue) {
			print("resume: set isPaused = true")
			self.isPaused = true
			self.currentMessage?.provider?.resendWindow()
			self.currentMessage?.receiver?.resetWindowForReceiving()
		}
	}
	
	/**
	Reset internal state of the controller.
	
	Any current messages being transmitted will be dropped. Messages already in the
	send queue will remain.
	
	You can optionally delete all messages in the local send queue.
	
	Calling this when running as a _Peripheral_ will notify the _Central_ to reset
	and drop the current message.
	
	Calling this when running as a _Central_ will notify the _Peripheral_ to reset
	and drop the current message.
	
	- parameter deleteAllMessages: Whether to delete the entire local send queue.
	*/
	public func reset(deleteAllMessages:Bool = false) {
		
		//this is left off of the serial queue so it will immediately stop packets
		//being sent if that loop is running on the serial queue.
		self.pausePackets = true
		
		dispatch_async(serialQueue) {
			self.internal_reset(deleteAllMessages, shouldSendReset: true, notifyDelegate: true, notifyDelegatePeerReset: false)
		}
	}
	
	/// Utility method for reset which resets local state. And optionall sends the reset message.
	func internal_reset(deleteAllMessages:Bool = false, shouldSendReset:Bool = true, notifyDelegate:Bool = true, notifyDelegatePeerReset:Bool = false) {
		
		if let cm = self.currentMessage {
			
			self.currentSendControl = nil
			self.stopResendControlMessageTimer()
			self.stopOfferTurnTimer()
			self.turnMode = .Peripheral
		
			if self.mode == .Central {
				self.messageQueue?.removeAtIndex(0)
			}
			
			self.currentMessage?.provider?.finishMessage()
			self.currentMessage = nil
			self.pausePackets = false
			
			if shouldSendReset {
				self.sendResetControlMessage()
			}
			
			if notifyDelegate {
				dispatch_async(self.delegateQueue, {
					self.delegate?.serialServiceController?(self, droppedMessageFromReset: cm)
				})
			}
			
			if notifyDelegatePeerReset {
				dispatch_async(self.delegateQueue, {
					self.delegate?.serialServiceController?(self, droppedMessageFromPeerReset: cm)
				})
			}
		}
		
		if deleteAllMessages {
			self.messageQueue = []
		}
		
		self.pausePackets = false
	}
	
	/// Get progress of current message.
	///
	/// If running as the central, this is the progress of bytes sent.
	///
	/// If running as the peripheral, this is the progress of bytes received
	/// based on expected message size.
	public var progress:Float {
		if self.mode == .Central {
			if let _provider = self.currentMessage?.provider {
				return _provider.progress()
			}
		}
		if self.mode == .Peripheral {
			if let _receiver = self.currentMessage?.receiver {
				return _receiver.progress()
			}
		}
		return -1
	}
	
	//MARK: Sending Data
	
	/**
	Queue a message to be sent.
	
	- parameter message:	The message to send.
	*/
	public func send(message:BTLEPlusSerialServiceMessage) {
		dispatch_async(serialQueue) {
			self.messageQueue?.append(message)
			self.startSending()
		}
	}
	
	/// Starts sending messages.
	func startSending() {
		resumeBlock = {
			print("resuming in startSending()")
			self.startSending()
		}
		
		if !self.hasDiscoverdPeerInfo && self.mode == .Peripheral {
			
			//if we're the peripheral the first thing to send is the
			//transfer information via peer info packet
			self.sendPeerInfoControlRequest(true, acceptFilter: [.PeerInfo,.Ack,.Reset])
			
		} else {
			
			if self.turnMode != self.mode {
				print("not our turn to send")
				return
			}
			
			if self.messageQueue?.count < 1 {
				return
			}
			
			if self.currentMessage != nil {
				return
			}
			
			print("my turn to send")
			self.currentMessage = self.messageQueue?[0]
			self.sendNewMessageControlRequest()
		}
	}
	
	/// Start sending packets from the current message.
	func startSendingPackets(fillNewWindow:Bool = true) {
		
		dispatch_async(serialQueue) {
			
			guard let provider = self.currentMessage?.provider else {
				return
			}
			
			//set resume block to continue from sendingPackets.
			self.resumeBlock = {
				print("resuming startSendingPackets(fillNewWindow: false)")
				self.startSendingPackets(true)
			}
			
			if self.pausePackets {
				return
			}
			
			self.acceptFilter = [.Resend,.Reset]
			var packet:NSData
			var message:BTLEPlusSerialServiceProtocolMessage
			
			if(fillNewWindow) {
				provider.mtu = self.mtu
				provider.windowSize = self.windowSize
				provider.fillWindow()
			}
			
			//set resume block to continue from sendingPackets.
			self.resumeBlock = {
				print("resuming startSendingPackets(fillNewWindow: false)")
				self.startSendingPackets(false)
			}
			
			if self.pausePackets {
				return
			}
			
			while provider.hasPackets() {
				
				if self.pausePackets {
					return
				}
				
				packet = provider.getPacket()
				message = BTLEPlusSerialServiceProtocolMessage(dataMessageWithData: packet)
				if let _data = message.data {
					print("sending packet data: ", _data.bleplus_base16EncodedString(uppercase:true))
					self.delegate?.serialServiceController(self, wantsToSendData: _data)
				}
			}
			
			if self.pausePackets {
				return
			}
			
			print(self.currentMessage?.provider?.progress())
			
			if provider.isEndOfMessage {
				self.sendEndMessageControlRequest(provider.endOfMessageWindowSize)
			} else {
				self.sendEndPartControlRequest(provider.windowSize)
			}
		}
	}
	
	/// Utility to send a control message. The filter and expectingAck parameters are important
	/// here as it's used in the resume block if we were to get paused.
	func sendControlMessage(message:BTLEPlusSerialServiceProtocolMessage, acceptFilter:[BTLEPlusSerialServiceProtocolMessageType], expectingAck:Bool = true) {
		dispatch_async(serialQueue) {
			if self.isPaused {
				return
			}
			
			guard let data = message.data else {
				return
			}
			
			print("sending control data: ", data.bleplus_base16EncodedString(uppercase:true))
			
			self.acceptFilter = acceptFilter
			self.currentSendControl = message
			self.delegate?.serialServiceController(self, wantsToSendData: data)
			
			self.resumeBlock = {
				print("resuming sendControlMessage (\(message))")
				self.sendControlMessage(message, acceptFilter: acceptFilter, expectingAck: expectingAck)
			}
			
			if expectingAck {
				self.startResendControlMessageTimer()
			} else {
				self.currentSendControl = nil
				self.stopResendControlMessageTimer()
			}
		}
	}
	
	//MARK: - Sending
	
	/// Send an ack
	func sendAck(acceptFilter:[BTLEPlusSerialServiceProtocolMessageType]) {
		let ack = BTLEPlusSerialServiceProtocolMessage(withType: .Ack)
		self.sendControlMessage(ack, acceptFilter: acceptFilter, expectingAck: false)
	}
	
	/// Sends a peer info control request.
	func sendPeerInfoControlRequest(expectingAck:Bool, acceptFilter:[BTLEPlusSerialServiceProtocolMessageType]) {
		let peerinfo = BTLEPlusSerialServiceProtocolMessage(peerInfoMessageWithMTU: self.mtu, windowSize: self.windowSize)
		self.sendControlMessage(peerinfo, acceptFilter: acceptFilter, expectingAck: expectingAck)
	}
	
	/// Sends a take turn control message.
	func sendTakeTurnControlMessage(expectingAck:Bool, acceptFilter:[BTLEPlusSerialServiceProtocolMessageType]) {
		let takeTurn = BTLEPlusSerialServiceProtocolMessage(withType: .TakeTurn)
		
		//if we're the central, set the turn mode to peripheral until we get control back.
		if self.mode == .Central {
			self.turnMode = .Peripheral
		}
		
		//if we're the peripheral, set the turn mode to central until we get control back.
		if self.mode == .Peripheral {
			self.turnMode = .Central
		}
		
		self.sendControlMessage(takeTurn, acceptFilter: acceptFilter, expectingAck: expectingAck)
	}
	
	/// Send a new message control request.
	func sendNewMessageControlRequest() {
		guard let currentMessage = self.currentMessage else {
			return
		}
		guard let provider = currentMessage.provider else {
			return
		}
		var newMessage:BTLEPlusSerialServiceProtocolMessage
		if provider.fileHandle != nil {
			newMessage = BTLEPlusSerialServiceProtocolMessage(newFileMessageWithExpectedSize: provider.messageSize, messageType: currentMessage.messageType, messageId: currentMessage.messageId)
		} else {
			newMessage = BTLEPlusSerialServiceProtocolMessage(newMessageWithExpectedSize: provider.messageSize, messageType: currentMessage.messageType, messageId: currentMessage.messageId)
		}
		self.sendControlMessage(newMessage, acceptFilter:[.Wait,.Ack,.Reset], expectingAck: true)
	}
	
	/// Send an end of message control request.
	func sendEndMessageControlRequest(windowSize:BTLEPlusSerialServiceWindowSize_Type) {
		let endMessage = BTLEPlusSerialServiceProtocolMessage(endMessageWithWindowSize: windowSize)
		self.sendControlMessage(endMessage, acceptFilter: [.Ack,.Resend,.Reset], expectingAck: true)
	}
	
	/// Send an end part message control request.
	func sendEndPartControlRequest(windowSize:BTLEPlusSerialServiceWindowSize_Type) {
		let endPart = BTLEPlusSerialServiceProtocolMessage(endPartWithWindowSize: windowSize)
		self.sendControlMessage(endPart, acceptFilter: [.Ack,.Resend,.Reset], expectingAck: true)
	}
	
	/// Sends a resend transfer control request.
	func sendResendControlMessage(resendFromPacket:BTLEPlusSerialServicePacketCounter_Type) {
		let resend = BTLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: resendFromPacket)
		self.sendControlMessage(resend, acceptFilter: [.Data,.EndMessage,.EndPart,.Reset])
	}
	
	/// Sends a wait control request.
	func sendWaitControlMessage(acceptFilter:[BTLEPlusSerialServiceProtocolMessageType]) {
		let wait = BTLEPlusSerialServiceProtocolMessage(withType: .Wait)
		self.sendControlMessage(wait, acceptFilter: acceptFilter, expectingAck: false)
	}
	
	/// Send a reset control message.
	func sendResetControlMessage() {
		let reset = BTLEPlusSerialServiceProtocolMessage(withType: .Reset)
		self.sendControlMessage(reset, acceptFilter: [.Ack,.Reset], expectingAck: true)
	}
	
	//MARK: - Receiving Data
	
	/**
	Handle raw serial service data.
	
	- parameter packet: Raw data received.
	*/
	public func receive(packet:NSData) {
		dispatch_async(serialQueue) {
			
			//If it's a valid message process it otherwise ignore it and the peer
			//should recover if it really should have been a valid packet.
			if let message = BTLEPlusSerialServiceProtocolMessage(withData: packet) {
				
				//Check if incoming message protocol type is allowed.
				if !self.acceptFilter.contains(message.protocolType) {
					print("filtered control type, now allowing:",message.data?.bleplus_base16EncodedString())
					return
				}
				
				self.stopResendControlMessageTimer()
				
				//clear the resume block as what it was set to is no longer valid. It will
				//be set again in one of the upcoming function calls.
				self.resumeBlock = nil
				
				//handle the message based on it's protocol type.
				switch message.protocolType {
				case .Ack:
					print("received ack:",packet.bleplus_base16EncodedString(uppercase:true))
					self.receivedAck(message)
				case .NewMessage:
					print("received new message:",packet.bleplus_base16EncodedString(uppercase:true))
					self.receivedNewMessageRequest(message)
				case .NewFileMessage:
					print("received new large:",packet.bleplus_base16EncodedString(uppercase:true))
					self.receivedNewLargeMessageRequest(message)
				case .EndPart:
					print("received end part:",packet.bleplus_base16EncodedString(uppercase:true))
					self.receivedEndPartMessage(message)
				case .EndMessage:
					print("received end message:",packet.bleplus_base16EncodedString(uppercase:true))
					self.receivedEndMessage(message)
				case .Resend:
					print("received resend:",packet.bleplus_base16EncodedString(uppercase:true))
					self.receivedResendMessage(message)
				case .PeerInfo:
					print("received peer info:",packet.bleplus_base16EncodedString(uppercase:true))
					self.receivedPeerInfoMessage(message)
				case .Data:
					print("received data message:",packet.bleplus_base16EncodedString(uppercase:true))
					self.receivedDataMessage(message)
				case .TakeTurn:
					print("received take turn message:",packet.bleplus_base16EncodedString(uppercase: true))
					self.receivedTakeTurnMessage(message)
				case .Wait:
					print("received wait message:",packet.bleplus_base16EncodedString(uppercase: true))
					self.receivedWaitMessage(message)
				case .Reset:
					print("received reset message:",packet.bleplus_base16EncodedString(uppercase: true))
					self.receivedResetMessage(message)
				default:
					break
				}
			}
		}
	}
	
	/// Received reset.
	func receivedResetMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		self.internal_reset(false, shouldSendReset: false, notifyDelegate: false, notifyDelegatePeerReset: true)
		
		if self.mode == .Peripheral {
			self.startOfferTurnTimer()
			self.sendAck([.TakeTurn,.Ack,.Reset])
		}
		
		if self.mode == .Central {
			self.sendAck([.TakeTurn,.Ack,.Reset])
		}
	}
	
	/// Received a wait message.
	func receivedWaitMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		self.startResendControlMessageTimer()
	}
	
	/// Received a peer info message.
	func receivedPeerInfoMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		
		//Only the central receives peer info messages. Upon connection the peripheral
		//sends it's transfer information.
		if self.mode == .Central {
			print("peer info message details: ",message.mtu,message.windowSize)
			self.mtu = message.mtu
			self.windowSize = message.windowSize
			self.sendAck([.TakeTurn,.NewMessage,.NewFileMessage,.Reset])
		}
		
	}
	
	/// Received a take turn message.
	func receivedTakeTurnMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		
		//if the peripheral received a take turn message, the peripheral by default
		//assumes control. The peripheral is in charge of offering turns to the
		//central to send it's messages.
		if self.mode == .Peripheral {
			self.currentSendControl = nil
			self.turnMode = .Peripheral
			self.sendAck([.Ack,.Reset])
			self.startSending()
			self.startOfferTurnTimer()
		}
		
		//if the central receives a take turn message, it must have messages
		//to assume control. If it doesn't have messages it gives control back
		//to the peripheral.
		if self.mode == .Central {
			
			if self.messageQueue?.count < 1 {
				
				//no messages, give control back to peripheral.
				self.turnMode = .Peripheral
				self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.NewMessage,.NewFileMessage,.Ack,.Reset])
				
			} else {
				
				//central has messages, ack to take control.
				self.turnMode = .Central
				self.sendAck([.Ack,.Reset])
				self.startSending()
				self.startOfferTurnTimer()
				
			}
		}
	}
	
	/// When a data message was received. Data messages are packet payloads
	/// that get appended to the current packet receiver.
	func receivedDataMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		if let payload = message.packetPayload {
			self.currentMessage?.receiver?.receivedData(payload)
		}
	}
	
	/// Received a new message request.
	func receivedNewMessageRequest(message:BTLEPlusSerialServiceProtocolMessage) {
		
		//check if we can accept more messages.
		if let shouldAcceptMore = self.delegate?.serialServiceControllerCanAcceptMoreMessages?(self) {
			if !shouldAcceptMore {
				sendWaitControlMessage([.TakeTurn,.NewMessage,.NewFileMessage,.Reset])
				return
			}
		}
		
		//If there's already a current receiver, there's an error so reset.
		if self.currentMessage != nil {
			
			//TODO: send reset
			return
			
		}
		
		//setup new receiver
		let windowSize = self.windowSize
		let messageSize = message.messageSize
		self.currentMessage = BTLEPlusSerialServiceMessage(withMessageType: message.messageType, messageId: message.messageId)
		self.currentMessage?.receiver = BTLEPlusSerialServicePacketReceiver(withWindowSize: windowSize, messageSize: messageSize)
		self.currentMessage?.receiver?.beginMessage()
		self.currentMessage?.receiver?.beginWindow()
		self.sendAck([.Data,.Resend,.EndMessage,.EndPart,.Reset])
	}
	
	/// Receieved a new large message.
	func receivedNewLargeMessageRequest(message:BTLEPlusSerialServiceProtocolMessage) {
		//check if we can accept more messages.
		if let shouldAcceptMore = self.delegate?.serialServiceControllerCanAcceptMoreMessages?(self) {
			if !shouldAcceptMore {
				sendWaitControlMessage([.TakeTurn,.NewMessage,.NewFileMessage,.Reset])
			}
		}
		
		if currentMessage != nil {
			print("SHOULD Reset")
			return
		}
		
		let tmpFileURL = BTLEPlusSerialServicePacketReceiver.getTempFileForWriting()
		guard let tmpFile = tmpFileURL else {
			return
		}
		
		//setup a new receiver
		let windowSize = self.windowSize
		let messageSize = message.messageSize
		self.currentMessage = BTLEPlusSerialServiceMessage(withMessageType: message.messageType, messageId: message.messageId)
		self.currentMessage?.receiver = BTLEPlusSerialServicePacketReceiver(withFileURLForWriting: tmpFile, windowSize: windowSize, messageSize: messageSize)
		self.sendAck([.Data,.Resend,.EndMessage,.EndPart,.Reset])
	}
	
	/// Received an end part.
	func receivedEndPartMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		guard let currentReceiver = self.currentMessage?.receiver else {
			return
		}
		currentReceiver.windowSize = message.windowSize
		currentReceiver.commitPacketData()
		if currentReceiver.needsPacketsResent {
			let packet = currentReceiver.resendFromPacket
			let resend = BTLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: packet)
			self.sendControlMessage(resend, acceptFilter: [.Data,.EndMessage,.EndPart,.Reset], expectingAck: false)
		} else {
			currentReceiver.beginWindow()
			self.sendAck([.Data,.EndMessage,.EndPart,.Reset])
		}
	}
	
	/// Received an end message.
	func receivedEndMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		guard let currentReceiver = self.currentMessage?.receiver else {
			return
		}
		
		currentReceiver.windowSize = message.windowSize
		currentReceiver.commitPacketData()
		
		if currentReceiver.needsPacketsResent {
			
			let packet = currentReceiver.resendFromPacket
			let resend = BTLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: packet)
			self.sendControlMessage(resend, acceptFilter: [.Data,.EndMessage,.EndPart,.Reset])
			
		} else {
			
			let cm = currentMessage
			cm?.data = cm?.receiver?.data
			cm?.fileURL = cm?.receiver?.fileURL
			
			self.currentMessage?.receiver?.finishMessage()
			self.currentMessage = nil
			self.sendAck([.TakeTurn,.NewMessage,.NewFileMessage,.Reset])
			
			dispatch_async(self.delegateQueue) {
				if let cm = cm {
					self.delegate?.serialServiceController(self, receivedMessage: cm)
				}
			}
		}
	}
	
	/// Received a resend control
	func receivedResendMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		guard let provider = self.currentMessage?.provider else {
			return
		}
		//TODO: fix resend from packet.
		//provider.resendFromPacket(message.resendFromPacket)
		provider.resendWindow()
		self.startSendingPackets(false)
	}
	
	/// Received an ack.
	func receivedAck(message:BTLEPlusSerialServiceProtocolMessage) {
		guard let csc = self.currentSendControl else {
			return
		}
		self.currentSendControl = nil
		switch csc.protocolType {
		case .NewMessage:
			self.receivedAckForNewMessage(message)
		case .NewFileMessage:
			self.receivedAckForNewFileMessage(message)
		case .EndPart:
			self.receivedAckForEndPart(message)
		case .EndMessage:
			self.receivedAckForEndMessage()
		case .PeerInfo:
			self.receivedAckForPeerInfo()
		case .TakeTurn:
			self.receivedAckForTakeTurn()
		case .Reset:
			self.receivedAckForReset()
		default:
			break
		}
	}
	
	// Ack a reset.
	func receivedAckForReset() {
		if self.mode == .Peripheral {
			self.acceptFilter = [.TakeTurn,.Ack,.Reset]
			self.startSending()
			self.startOfferTurnTimer()
		}
		
		if self.mode == .Central {
			self.acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Reset,.Ack]
		}
	}
	
	/// Ack a new message.
	func receivedAckForNewMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		self.startSendingPackets()
	}
	
	/// Ack a new file message.
	func receivedAckForNewFileMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		self.startSendingPackets()
	}
	
	/// Ack end part
	func receivedAckForEndPart(message:BTLEPlusSerialServiceProtocolMessage) {
		self.startSendingPackets()
	}
	
	/// Ack end message
	func receivedAckForEndMessage() {
		let cm = self.currentMessage
		dispatch_async(self.delegateQueue) {
			if let cm = cm {
				self.delegate?.serialServiceController?(self, sentMessage: cm)
			}
		}
		
		self.currentMessage?.provider?.finishMessage()
		self.currentMessage = nil
		self.messageQueue?.removeAtIndex(0)
		
		if self.turnMode == self.mode && self.messageQueue?.count < 1 {
			self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Reset])
			return
		}
		
		self.acceptFilter = [.TakeTurn,.Ack,.Reset]
		self.startSending()
	}
	
	/// When received an ack for take turn message
	func receivedAckForTakeTurn() {
		if self.mode == .Central {
			self.turnMode = .Peripheral
			self.acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Reset]
			self.stopOfferTurnTimer()
		}
		if self.mode == .Peripheral {
			self.turnMode = .Central
			self.acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Reset]
			self.stopOfferTurnTimer()
		}
	}
	
	/// When an ack was received for a peer info message.
	func receivedAckForPeerInfo() {
		if self.mode == .Peripheral {
			self.hasDiscoverdPeerInfo = true
			self.acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Reset]
			self.startOfferTurnTimer()
		}
	}
}
