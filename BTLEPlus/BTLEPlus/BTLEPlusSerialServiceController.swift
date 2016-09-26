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
	
	/**
	When a message was entirely sent, and received by the peer.
	
	- parameter controller: BTLEPlusSerialServiceController
	- parameter message:    The message that was sent.
	*/
	optional func serialServiceController(controller:BTLEPlusSerialServiceController, sentMessage message:BTLEPlusSerialServiceMessage)
	
	/**
	When message data is received via receive(), it is wrapped in protocol control data, you
	can use this as a hook to receive the unwrapped, raw user message data.
	
	- parameter controller: BTLEPlusSerialServiceController
	- parameter data:       NSData
	*/
	optional func serialServiceController(controller:BTLEPlusSerialServiceController, receivedUnwrappedData data:NSData)
	
	/**
	When a message has been completely received.
	
	- parameter controller: BTLEPlusSerialServiceController
	- parameter message:    The message that was received.
	*/
	optional func serialServiceController(controller:BTLEPlusSerialServiceController, receivedMessage message:BTLEPlusSerialServiceMessage)
	
	/// :nodoc:
	/// Used for testing resend messages.
	optional func serialServiceControllerShouldRespondWithResend(controller:BTLEPlusSerialServiceController) -> Bool
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
	var delegateQueue:dispatch_queue_t
	
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
	var _windowSize:BTLEPlusSerialServiceWindowSize_Type = BTLEPlusSerialServiceDefaultWindowSize
	
	/// When resume is called if this block is set it's called.
	var resumeBlock:(()->Void)?
	
	/// Whether or not we're currently connected.
	var isPaused = false
	
	/// Whether or not packet sending is paused, this is used as a way to immediately stop
	/// packet sending if the controller is paused while in the send packets loop.
	var pausePackets = false
	
	/// Whether or not peer info has been discovered.
	var hasDiscoverdPeerInfo = false
	
	/// The protocol messages that are allowed to be received. This is used instead
	/// of a state machine so that known responses to control messages are allowed,
	/// and responses to protocol messages that are out of order or incorrect are filtered
	/// out.
	var acceptFilter:[BTLEPlusSerialServiceProtocolMessageType]! = [.PeerInfo,.Ack]
	
	/// Serial dispatch queue for processing activity.
	var serialQueue:dispatch_queue_t
	
	/// Queue for sending user messages
	var messageQueue:[BTLEPlusSerialServiceMessage]?
	
	/// The current message, either being sent or received.
	var currentMessage:BTLEPlusSerialServiceMessage?
	
	/// Current control message that was sent.
	var currentSendControl:BTLEPlusSerialServiceProtocolMessage?
	
	/// The current message receiver that's receiving data from the client or server.
	//private var currentReceiveMessage:BTLEPlusSerialServiceMessage?
	
	/// A libdispatch timer.
	var offerTurnDispatchTimer:dispatch_source_t?
	
	/// The repeat interval to offer turns to the peer. The unit of time
	/// here is nanoseconds. libdispatch's timers require nanoseconds.
	/// You can use NSEC_PER_SECONDS to calculate this value.
	///
	/// Default value is 1 seconds.
	///
	/// Example: 2 seconds: 2 * NSEC_PER_SEC
	/// Example: .5 seconds: .5 * NSEC_PER_SEC
	/// Example: .25 seconds: .25 * NSEC_PER_SEC
	public var offerTurnInterval:UInt64 = NSEC_PER_SEC
	
	/// The timeout before resending any waiting control packets. The unit of time
	/// here is nanoseconds. libdispatch's timers require nanoseconds.
	/// You can use NSEC_PER_SECONDS to calculate this value.
	///
	/// Default value is 3 seconds.
	///
	/// Example: 2 seconds: 2 * NSEC_PER_SEC
	/// Example: .5 seconds: .5 * NSEC_PER_SEC
	/// Example: .25 seconds: .25 * NSEC_PER_SEC
	var resendTimeout:UInt64 = 3 * NSEC_PER_SEC
	
	/// A timer to wait for responses like acks.
	var resendCurrentControlTimer:dispatch_source_t?
	
	/// The mode this controller is running as.
	var mode:BTLEPlusSerialServiceRunMode = .Peripheral
	
	/// The mode for whoever's turn it is.
	var turnMode:BTLEPlusSerialServiceRunMode = .Peripheral
	
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
		if offerTurnDispatchTimer != nil {
			return
		}
		print("startOfferTurnTimer")
		offerTurnDispatchTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
		dispatch_source_set_timer(offerTurnDispatchTimer!, dispatch_walltime(nil, Int64(offerTurnInterval)), offerTurnInterval, 0)
		dispatch_source_set_event_handler(offerTurnDispatchTimer!) {
			self.offerTurnTimeout()
		}
		dispatch_resume(offerTurnDispatchTimer!)
	}
	
	// Stops the offer turn timer
	func stopOfferTurnTimer() {
		if let offerTurnDispatchTimer = offerTurnDispatchTimer {
			dispatch_source_cancel(offerTurnDispatchTimer)
			self.offerTurnDispatchTimer = nil
		}
	}
	
	/// When offer turn timer expires.
	func offerTurnTimeout() {
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
		if let resendCurrentControlTimer = resendCurrentControlTimer {
			dispatch_source_cancel(resendCurrentControlTimer)
		}
		print("startResendTimer")
		resendCurrentControlTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
		dispatch_source_set_timer(resendCurrentControlTimer!, dispatch_walltime(nil, Int64(resendTimeout)), resendTimeout, 0)
		dispatch_source_set_event_handler(resendCurrentControlTimer!) {
			self.resendTimerTimeout()
		}
		dispatch_resume(resendCurrentControlTimer!)
	}
	
	/// Stop the resend control timer.
	func stopResendControlMessageTimer() {
		if let resendCurrentControlTimer = resendCurrentControlTimer {
			dispatch_source_cancel(resendCurrentControlTimer)
		}
	}
	
	/// Wait timer timeout.
	func resendTimerTimeout() {
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
			self.isPaused = true
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
		pausePackets = true
		
		dispatch_async(serialQueue) {
			self.internal_reset(deleteAllMessages, shouldSendReset: true, notifyDelegate: true, notifyDelegatePeerReset: false)
		}
	}
	
	/// Utility method for reset which resets local state.
	/// And optionally sends the reset message.
	func internal_reset(deleteAllMessages:Bool = false, shouldSendReset:Bool = true, notifyDelegate:Bool = true, notifyDelegatePeerReset:Bool = false) {
		
		if let cm = currentMessage {
			
			currentSendControl = nil
			stopResendControlMessageTimer()
			stopOfferTurnTimer()
			turnMode = .Peripheral
		
			if mode == .Central {
				messageQueue?.removeAtIndex(0)
			}
			
			currentMessage?.provider?.finishMessage()
			currentMessage = nil
			pausePackets = false
			
			if shouldSendReset {
				sendResetControlMessage()
			}
			
			if notifyDelegate {
				dispatch_async(delegateQueue, {
					self.delegate?.serialServiceController?(self, droppedMessageFromReset: cm)
				})
			}
			
			if notifyDelegatePeerReset {
				dispatch_async(delegateQueue, {
					self.delegate?.serialServiceController?(self, droppedMessageFromPeerReset: cm)
				})
			}
		}
		
		if deleteAllMessages {
			messageQueue = []
		}
		
		pausePackets = false
	}
	
	/// Get progress of current message.
	///
	/// If running as the central, this is the progress of bytes sent.
	///
	/// If running as the peripheral, this is the progress of bytes received
	/// based on expected message size.
	public var progress:Float {
		if mode == .Central {
			if let _provider = currentMessage?.provider {
				return _provider.progress()
			}
		}
		if mode == .Peripheral {
			if let _receiver = currentMessage?.receiver {
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
		
		if !hasDiscoverdPeerInfo && mode == .Peripheral {
			
			//if we're the peripheral the first thing to send is the
			//transfer information via peer info packet
			sendPeerInfoControlRequest(true, acceptFilter: [.PeerInfo,.Ack,.Reset])
			
		} else {
			
			if turnMode != mode {
				print("not our turn to send")
				return
			}
			
			if messageQueue?.count < 1 {
				return
			}
			
			if currentMessage != nil {
				return
			}
			
			print("my turn to send")
			currentMessage = messageQueue?[0]
			sendNewMessageControlRequest()
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
				self.startSendingPackets(fillNewWindow)
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
				self.startSendingPackets(fillNewWindow)
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
		sendControlMessage(ack, acceptFilter: acceptFilter, expectingAck: false)
	}
	
	/// Sends a peer info control request.
	func sendPeerInfoControlRequest(expectingAck:Bool, acceptFilter:[BTLEPlusSerialServiceProtocolMessageType]) {
		let peerinfo = BTLEPlusSerialServiceProtocolMessage(peerInfoMessageWithMTU: mtu, windowSize: windowSize)
		sendControlMessage(peerinfo, acceptFilter: acceptFilter, expectingAck: expectingAck)
	}
	
	/// Sends a take turn control message.
	func sendTakeTurnControlMessage(expectingAck:Bool, acceptFilter:[BTLEPlusSerialServiceProtocolMessageType]) {
		let takeTurn = BTLEPlusSerialServiceProtocolMessage(withType: .TakeTurn)
		
		//if we're the central, set the turn mode to peripheral until we get control back.
		if mode == .Central {
			turnMode = .Peripheral
		}
		
		//if we're the peripheral, set the turn mode to central until we get control back.
		if mode == .Peripheral {
			turnMode = .Central
		}
		
		sendControlMessage(takeTurn, acceptFilter: acceptFilter, expectingAck: expectingAck)
	}
	
	/// Send a new message control request.
	func sendNewMessageControlRequest() {
		guard let currentMessage = currentMessage else {
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
		sendControlMessage(newMessage, acceptFilter:[.Wait,.Ack,.Reset], expectingAck: true)
	}
	
	/// Send an end of message control request.
	func sendEndMessageControlRequest(windowSize:BTLEPlusSerialServiceWindowSize_Type) {
		let endMessage = BTLEPlusSerialServiceProtocolMessage(endMessageWithWindowSize: windowSize)
		sendControlMessage(endMessage, acceptFilter: [.Ack,.Resend,.Reset], expectingAck: true)
	}
	
	/// Send an end part message control request.
	func sendEndPartControlRequest(windowSize:BTLEPlusSerialServiceWindowSize_Type) {
		let endPart = BTLEPlusSerialServiceProtocolMessage(endPartWithWindowSize: windowSize)
		sendControlMessage(endPart, acceptFilter: [.Ack,.Resend,.Reset], expectingAck: true)
	}
	
	/// Sends a resend transfer control request.
	func sendResendControlMessage(resendFromPacket:BTLEPlusSerialServicePacketCounter_Type) {
		let resend = BTLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: resendFromPacket)
		currentMessage?.receiver?.expectedPacket = resendFromPacket
		sendControlMessage(resend, acceptFilter: [.Data,.EndMessage,.EndPart,.Reset], expectingAck: false)
	}
	
	/// Sends a wait control request.
	func sendWaitControlMessage(acceptFilter:[BTLEPlusSerialServiceProtocolMessageType]) {
		let wait = BTLEPlusSerialServiceProtocolMessage(withType: .Wait)
		sendControlMessage(wait, acceptFilter: acceptFilter, expectingAck: false)
	}
	
	/// Send a reset control message.
	func sendResetControlMessage() {
		let reset = BTLEPlusSerialServiceProtocolMessage(withType: .Reset)
		sendControlMessage(reset, acceptFilter: [.Ack,.Reset], expectingAck: true)
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
		internal_reset(false, shouldSendReset: false, notifyDelegate: false, notifyDelegatePeerReset: true)
		
		if mode == .Peripheral {
			startOfferTurnTimer()
			sendAck([.TakeTurn,.Ack,.Reset])
		}
		
		if mode == .Central {
			sendAck([.TakeTurn,.Ack,.Reset])
		}
	}
	
	/// Received a wait message.
	func receivedWaitMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		startResendControlMessageTimer()
	}
	
	/// Received a peer info message.
	func receivedPeerInfoMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		
		//Only the central receives peer info messages. Upon connection the peripheral
		//sends it's transfer information.
		if mode == .Central {
			print("peer info message details: ",message.mtu,message.windowSize)
			mtu = message.mtu
			windowSize = message.windowSize
			sendAck([.TakeTurn,.NewMessage,.NewFileMessage,.Reset])
		}
		
	}
	
	/// Received a take turn message.
	func receivedTakeTurnMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		
		//if the peripheral received a take turn message, the peripheral by default
		//assumes control. The peripheral is in charge of offering turns to the
		//central to send it's messages.
		if mode == .Peripheral {
			currentSendControl = nil
			turnMode = .Peripheral
			sendAck([.Ack,.Reset])
			startSending()
			startOfferTurnTimer()
		}
		
		//if the central receives a take turn message, it must have messages
		//to assume control. If it doesn't have messages it gives control back
		//to the peripheral.
		if mode == .Central {
			
			if messageQueue?.count < 1 {
				
				//no messages, give control back to peripheral.
				turnMode = .Peripheral
				sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.NewMessage,.NewFileMessage,.Ack,.Reset])
				
			} else {
				
				//central has messages, ack to take control.
				turnMode = .Central
				sendAck([.Ack,.Reset])
				startSending()
				startOfferTurnTimer()
				
			}
		}
	}
	
	/// When a data message was received. Data messages are packet payloads
	/// that get appended to the current packet receiver.
	func receivedDataMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		if let payload = message.packetPayload {
			
			//tell delegate of payload data.
			self.delegate?.serialServiceController?(self, receivedUnwrappedData: payload)
			
			//tell receiver to receive data.
			currentMessage?.receiver?.receivedData(payload)
		}
	}
	
	/// Received a new message request.
	func receivedNewMessageRequest(message:BTLEPlusSerialServiceProtocolMessage) {
		
		//check if we can accept more messages.
		if let shouldAcceptMore = delegate?.serialServiceControllerCanAcceptMoreMessages?(self) {
			if !shouldAcceptMore {
				sendWaitControlMessage([.TakeTurn,.NewMessage,.NewFileMessage,.Reset])
				return
			}
		}
		
		//If there's already a current receiver, there's an error so reset.
		if currentMessage != nil {
			sendResetControlMessage()
			return
			
		}
		
		//setup new receiver
		let windowSize = self.windowSize
		let messageSize = message.messageSize
		currentMessage = BTLEPlusSerialServiceMessage(withMessageType: message.messageType, messageId: message.messageId)
		currentMessage?.receiver = BTLEPlusSerialServicePacketReceiver(withWindowSize: windowSize, messageSize: messageSize)
		currentMessage?.receiver?.beginMessage()
		currentMessage?.receiver?.beginWindow()
		sendAck([.Data,.Resend,.EndMessage,.EndPart,.Reset])
	}
	
	/// Receieved a new large message.
	func receivedNewLargeMessageRequest(message:BTLEPlusSerialServiceProtocolMessage) {
		//check if we can accept more messages.
		if let shouldAcceptMore = delegate?.serialServiceControllerCanAcceptMoreMessages?(self) {
			if !shouldAcceptMore {
				sendWaitControlMessage([.TakeTurn,.NewMessage,.NewFileMessage,.Reset])
				return
			}
		}
		
		if currentMessage != nil {
			print("SHOULD Reset")
			return
		}
		
		let tmpFileURL = NSFileManager.defaultManager().getTempFileForWriting()
		guard let tmpFile = tmpFileURL else {
			return
		}
		
		//setup a new receiver
		let windowSize = self.windowSize
		let messageSize = message.messageSize
		currentMessage = BTLEPlusSerialServiceMessage(withMessageType: message.messageType, messageId: message.messageId)
		currentMessage?.receiver = BTLEPlusSerialServicePacketReceiver(withFileURLForWriting: tmpFile, windowSize: windowSize, messageSize: messageSize)
		sendAck([.Data,.Resend,.EndMessage,.EndPart,.Reset])
	}
	
	/// Received an end part.
	func receivedEndPartMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		guard let currentReceiver = currentMessage?.receiver else {
			return
		}
		currentReceiver.windowSize = message.windowSize
		currentReceiver.commitPacketData()
		
		if let respondWithResend = delegate?.serialServiceControllerShouldRespondWithResend?(self) {
			if respondWithResend {
				sendResendControlMessage(currentReceiver.resendFromPacket)
				return
			}
		}
		
		if currentReceiver.needsPacketsResent {
			sendResendControlMessage(currentReceiver.resendFromPacket)
		} else {
			currentReceiver.beginWindow()
			sendAck([.Data,.EndMessage,.EndPart,.Reset])
		}
	}
	
	/// Received an end message.
	func receivedEndMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		guard let currentReceiver = currentMessage?.receiver else {
			return
		}
		
		currentReceiver.windowSize = message.windowSize
		currentReceiver.commitPacketData()
		
		if let respondWithResend = delegate?.serialServiceControllerShouldRespondWithResend?(self) {
			if respondWithResend {
				sendResendControlMessage(currentReceiver.resendFromPacket)
				return
			}
		}
		
		if currentReceiver.needsPacketsResent {
			sendResendControlMessage(currentReceiver.resendFromPacket)
		} else {
			
			let cm = currentMessage
			cm?.data = cm?.receiver?.data
			cm?.fileURL = cm?.receiver?.fileURL
			
			currentMessage?.receiver?.finishMessage()
			currentMessage = nil
			sendAck([.TakeTurn,.NewMessage,.NewFileMessage,.Reset])
			
			dispatch_async(delegateQueue) {
				if let cm = cm {
					self.delegate?.serialServiceController?(self, receivedMessage: cm)
				}
			}
		}
	}
	
	/// Received a resend control
	func receivedResendMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		guard let provider = currentMessage?.provider else {
			return
		}
		provider.resendFromPacket(message.resendFromPacket)
		startSendingPackets(false)
	}
	
	/// Received an ack.
	func receivedAck(message:BTLEPlusSerialServiceProtocolMessage) {
		guard let csc = currentSendControl else {
			return
		}
		currentSendControl = nil
		switch csc.protocolType {
		case .NewMessage:
			receivedAckForNewMessage(message)
		case .NewFileMessage:
			receivedAckForNewFileMessage(message)
		case .EndPart:
			receivedAckForEndPart(message)
		case .EndMessage:
			receivedAckForEndMessage()
		case .PeerInfo:
			receivedAckForPeerInfo()
		case .TakeTurn:
			receivedAckForTakeTurn()
		case .Reset:
			receivedAckForReset()
		default:
			break
		}
	}
	
	// Ack a reset.
	func receivedAckForReset() {
		if mode == .Peripheral {
			acceptFilter = [.TakeTurn,.Ack,.Reset]
			startSending()
			startOfferTurnTimer()
		}
		
		if mode == .Central {
			acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Reset,.Ack]
		}
	}
	
	/// Ack a new message.
	func receivedAckForNewMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		startSendingPackets()
	}
	
	/// Ack a new file message.
	func receivedAckForNewFileMessage(message:BTLEPlusSerialServiceProtocolMessage) {
		startSendingPackets()
	}
	
	/// Ack end part
	func receivedAckForEndPart(message:BTLEPlusSerialServiceProtocolMessage) {
		startSendingPackets()
	}
	
	/// Ack end message
	func receivedAckForEndMessage() {
		let cm = currentMessage
		dispatch_async(delegateQueue) {
			if let cm = cm {
				self.delegate?.serialServiceController?(self, sentMessage: cm)
			}
		}
		
		currentMessage?.provider?.finishMessage()
		currentMessage = nil
		messageQueue?.removeAtIndex(0)
		
		if turnMode == mode && messageQueue?.count < 1 {
			sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Reset])
			return
		}
		
		acceptFilter = [.TakeTurn,.Ack,.Reset]
		startSending()
	}
	
	/// When received an ack for take turn message
	func receivedAckForTakeTurn() {
		if mode == .Central {
			turnMode = .Peripheral
			acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Reset]
			stopOfferTurnTimer()
		}
		if mode == .Peripheral {
			turnMode = .Central
			acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Reset]
			stopOfferTurnTimer()
		}
	}
	
	/// When an ack was received for a peer info message.
	func receivedAckForPeerInfo() {
		if mode == .Peripheral {
			hasDiscoverdPeerInfo = true
			acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Reset]
			startOfferTurnTimer()
		}
	}
}
