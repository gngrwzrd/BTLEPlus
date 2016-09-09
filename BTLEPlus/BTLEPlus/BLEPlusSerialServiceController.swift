//
//  BLEPlusSerialServiceController.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/27/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
BLEPlusSerialServiceControllerMode denotes which side of the
connection the controller is operating as.

- Central:		Central is the client in BTLE.
- Peripheral:	Peripheral is the server in BTLE.
*/
@objc public enum BLEPlusSerialServiceControllerMode :UInt8 {
	case Central = 1
	case Peripheral = 2
}

/// BLEPlusSerialServiceControllerDelegate is the protocol you can implement to receive callbacks.
@objc public protocol BLEPlusSerialServiceControllerDelegate {
	
	/**
	When the serial service controller needs to send data it asks the delegate to send it on it's bahalf.
	
	- parameter controller:			BLEPlusSerialServiceController.
	- parameter wantsToSendData:	NSData.
	*/
	func serialServiceController(controller:BLEPlusSerialServiceController, wantsToSendData data:NSData)
	
	/**
	When a message was entirely sent and received by the peer.
	
	- parameter controller:	BLEPlusSerialServiceController.
	- parameter message:		The user message that was sent.
	*/
	optional func serialServiceController(controller:BLEPlusSerialServiceController, sentMessage message:BLEPlusSerialServiceMessage)
	
	/**
	When a message has been completely received.
	
	- parameter controller:	BLEPlusSerialServiceController.
	- parameter message:		BLEPlusSerialServiceUserMessasge.
	*/
	optional func serialServiceController(controller:BLEPlusSerialServiceController, receivedMessage message:BLEPlusSerialServiceMessage)
}

/**
BLEPlusSerialServiceController is controller that implements logic to send
and receive data using the binary BLEPlus Serial Service protocol.

It's implementation is independent of how the data is sent or received,
leaving that up to the user.
*/
@objc public class BLEPlusSerialServiceController : NSObject {
	
	//MARK: - Variables
	
	/// A delegate to receive activity messages.
	public var delegate:BLEPlusSerialServiceControllerDelegate?
	
	/// The delegate callback queue.
	private var delegateQueue:dispatch_queue_t
	
	/// Maximum transmission unit.
	public var mtu:BLEPlusSerialServiceMTUType = BLEPlusSerialServiceDefaultMTU
	
	/// Window size. This is clamped between 0 and BLEPlusSerialServiceMaxWindowSize.
	public var windowSize:BLEPlusSerialServiceWindowSize_Type {
		get {
			return _windowSize
		} set(new) {
			if new > BLEPlusSerialServiceMaxWindowSize {
				_windowSize = BLEPlusSerialServiceMaxWindowSize
			} else {
				_windowSize = new
			}
		}
	}
	private var _windowSize:BLEPlusSerialServiceWindowSize_Type = BLEPlusSerialServiceDefaultWindowSize
	
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
	private var acceptFilter:[BLEPlusSerialServiceProtocolMessageType]! = [.PeerInfo,.Ack]
	
	/// Serial dispatch queue for processing activity.
	private var serialQueue:dispatch_queue_t
	
	/// Queue for sending user messages
	public var messageQueue:[BLEPlusSerialServiceMessage]?
	
	/// The current message being transmitted.
	private var currentUserMessage:BLEPlusSerialServiceMessage?
	
	/// Current control message that was sent.
	private var currentSendControl:BLEPlusSerialServiceProtocolMessage?
	
	/// The current message receiver that's receiving data from the client or server.
	private var currentReceiver:BLEPlusSerialServicePacketReceiver?
	
	/// A timer to wait for responses like acks.
	private var resendCurrentControlTimer:NSTimer?
	
	/// The mode this controller is running as.
	private var mode:BLEPlusSerialServiceControllerMode = .Central
	
	/// The mode for whoever's turn it is.
	private var turnMode:BLEPlusSerialServiceControllerMode = .Central
	
	/// A timer that keeps track of when to offer the peer a turn.
	private var offerTurnTimer:NSTimer?
	
	//MARK: - inits
	
	/// default init
	public init(withMode mode:BLEPlusSerialServiceControllerMode) {
		self.mode = mode
		messageQueue = []
		serialQueue = dispatch_queue_create("com.bleplus.SerialServiceController", DISPATCH_QUEUE_SERIAL)
		delegateQueue = dispatch_get_main_queue()
		super.init()
	}
	
	/**
	Initialize a BLEPlusSerialServiceController with a delegate queue.
	
	- parameter queue: The queue for delegate messages to callback on.
	
	- returns: BLEPlusSerialServiceController
	*/
	public init(withMode mode:BLEPlusSerialServiceControllerMode, delegateQueue queue:dispatch_queue_t) {
		messageQueue = []
		self.mode = mode
		serialQueue = dispatch_queue_create("com.bleplus.SerialServiceController", DISPATCH_QUEUE_SERIAL)
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
		let timer = NSTimer(timeInterval: 3, target: self, selector: #selector(BLEPlusSerialServiceController.offerTurnTimeout(_:)), userInfo: nil, repeats: true)
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
				if self.mode == .Central && self.currentUserMessage == nil && self.currentSendControl == nil {
					self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Abort])
				}
				if self.mode == .Peripheral && self.currentReceiver == nil && self.currentSendControl == nil {
					self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Abort])
				}
			}
		}
	}
	
	/// Starts the wait timer.
	func startResendControlMessageTimer() {
		resendCurrentControlTimer?.invalidate()
		let timer = NSTimer(timeInterval: 5, target: self, selector: #selector(BLEPlusSerialServiceController.resendControlMessageTimerTimeout(_:)), userInfo: nil, repeats: false)
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
	
	//MARK: - Control
	
	/// Call this when you are connected and ready to send or receive data.
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
	
	/// Call this when you have been disconnected. The currently active messages
	/// packet counter is reset to resend the last window once resume is called
	/// again.
	public func pause() {
		//pausePackets is specifically left out of the serial queue so that the loop
		//in startSendingPackets will exit early if resume ever called while
		//that loop is running.
		pausePackets = true
		dispatch_async(serialQueue) {
			print("resume: set isPaused = true")
			self.isPaused = true
			self.currentUserMessage?.provider?.resendWindow()
			self.currentReceiver?.resetWindowForReceiving()
		}
	}
	
	/**
	Queue a message to be sent.
	
	- parameter message:	BLEPlusSerialServiceMesssage
	*/
	public func send(message:BLEPlusSerialServiceMessage) {
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
		
		if !self.hasDiscoverdPeerInfo && self.mode == .Central {
			
			//if we're the central and don't know the peers transfer info
			//send a peer info message.
			
			self.startOfferTurnTimer()
			self.sendPeerInfoControlRequest(true, acceptFilter: [.PeerInfo,.Ack,.Abort])
			
		} else {
			
			if self.turnMode != self.mode {
				print("not our turn to send")
				return
			}
			
			if self.messageQueue?.count < 1 {
				return
			}
			
			if self.currentUserMessage != nil {
				return
			}
			
			print("my turn to send")
			self.currentUserMessage = self.messageQueue?[0]
			self.sendNewMessageControlRequest()
		}
	}
	
	/// Start sending packets from the current message.
	func startSendingPackets(fillNewWindow:Bool = true) {
		
		dispatch_async(serialQueue) {
			
			guard let provider = self.currentUserMessage?.provider else {
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
			
			self.acceptFilter = [.Resend,.Abort]
			var packet:NSData
			var message:BLEPlusSerialServiceProtocolMessage
			
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
				message = BLEPlusSerialServiceProtocolMessage(dataMessageWithData: packet)
				if let _data = message.data {
					print("sending packet data: ", _data.bleplus_base16EncodedString(uppercase:true))
					self.delegate?.serialServiceController(self, wantsToSendData: _data)
				}
			}
			
			if self.pausePackets {
				return
			}
			
			print(self.currentUserMessage?.provider?.progress())
			
			if provider.isEndOfMessage {
				self.sendEndMessageControlRequest(provider.endOfMessageWindowSize)
			} else {
				self.sendEndPartControlRequest(provider.windowSize)
			}
		}
	}
	
	/// Utility to send a control message. The filter and expectingAck parameters are important
	/// here as it's used in the resume block if we were to get paused.
	func sendControlMessage(message:BLEPlusSerialServiceProtocolMessage, acceptFilter:[BLEPlusSerialServiceProtocolMessageType], expectingAck:Bool = true) {
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
				self.stopResendControlMessageTimer()
			}
		}
	}
	
	//MARK: - Sending
	
	/// Send an ack
	func sendAck(acceptFilter:[BLEPlusSerialServiceProtocolMessageType]) {
		let ack = BLEPlusSerialServiceProtocolMessage(withType: .Ack)
		self.sendControlMessage(ack, acceptFilter: acceptFilter, expectingAck: false)
	}
	
	/// Sends a peer info control request.
	func sendPeerInfoControlRequest(expectingAck:Bool, acceptFilter:[BLEPlusSerialServiceProtocolMessageType]) {
		let peerinfo = BLEPlusSerialServiceProtocolMessage(peerInfoMessageWithMTU: self.mtu, windowSize: self.windowSize)
		self.sendControlMessage(peerinfo, acceptFilter: acceptFilter, expectingAck: expectingAck)
	}
	
	/// Sends a take turn control message.
	func sendTakeTurnControlMessage(expectingAck:Bool, acceptFilter:[BLEPlusSerialServiceProtocolMessageType]) {
		let takeTurn = BLEPlusSerialServiceProtocolMessage(withType: .TakeTurn)
		
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
		guard let currentUserMessage = self.currentUserMessage else {
			return
		}
		guard let provider = currentUserMessage.provider else {
			return
		}
		var newMessage:BLEPlusSerialServiceProtocolMessage
		if provider.fileHandle != nil {
			newMessage = BLEPlusSerialServiceProtocolMessage(newFileMessageWithExpectedSize: provider.messageSize, messageType: currentUserMessage.messageType, messageId: currentUserMessage.messageId)
		} else {
			newMessage = BLEPlusSerialServiceProtocolMessage(newMessageWithExpectedSize: provider.messageSize, messageType: currentUserMessage.messageType, messageId: currentUserMessage.messageId)
		}
		self.sendControlMessage(newMessage, acceptFilter:[.Ack,.Abort], expectingAck: true)
	}
	
	/// Send an end of message control request.
	func sendEndMessageControlRequest(windowSize:BLEPlusSerialServiceWindowSize_Type) {
		let endMessage = BLEPlusSerialServiceProtocolMessage(endMessageWithWindowSize: windowSize)
		self.sendControlMessage(endMessage, acceptFilter: [.Ack,.Resend,.Abort], expectingAck: true)
	}
	
	/// Send an end part message control request.
	func sendEndPartControlRequest(windowSize:BLEPlusSerialServiceWindowSize_Type) {
		let endPart = BLEPlusSerialServiceProtocolMessage(endPartWithWindowSize: windowSize)
		self.sendControlMessage(endPart, acceptFilter: [.Ack,.Resend,.Abort], expectingAck: true)
	}
	
	/// Sends a resend transfer control request.
	func sendResendControlMessage(resendFromPacket:BLEPlusSerialServicePacketCountType) {
		let resend = BLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: resendFromPacket)
		self.sendControlMessage(resend, acceptFilter: [.Data,.EndMessage,.EndPart,.Abort])
	}
	
	//MARK: - Receiving
	
	/// When you receive data you must call this.
	public func receivedData(packet:NSData) {
		dispatch_async(serialQueue) {
			//create a message
			let message = BLEPlusSerialServiceProtocolMessage(withData: packet)
			
			//check if incoming message protocol type is allowed.
			if !self.acceptFilter.contains(message.protocolType) {
				print("filtered control type, now allowing:",message.data?.bleplus_base16EncodedString())
				return
			}
			
			//we got something allowed so stop wait timer.
			self.stopResendControlMessageTimer()
			self.resumeBlock = nil
			
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
			default:
				break
			}
		}
	}
	
	/// Received a peer info message.
	func receivedPeerInfoMessage(message:BLEPlusSerialServiceProtocolMessage) {
		print("peer info message details: ",message.mtu,message.windowSize)
		
		//If we're the central and received a peer info, in response to a peer info,
		//it means the centrals' mtu/windowsize was too large, so use the provided
		//info from the peripheral instead.
		if self.mode == .Central {
			if self.currentSendControl?.protocolType == .PeerInfo {
				self.currentSendControl = nil
				self.hasDiscoverdPeerInfo = true
				self.mtu = message.mtu
				self.windowSize = message.windowSize
				self.acceptFilter = [.TakeTurn,.Ack,.Abort]
				self.startSending()
			} else {
				//TODO:
				print("WILL THIS EVER GET CALLED?")
				self.hasDiscoverdPeerInfo = true
				self.mtu = message.mtu
				self.windowSize = message.windowSize
			}
		}
		
		//if we're the peripheral and we receive a peer info which has too large of mtu
		//or window size, send back a peerinfo with our mtu window size, otherwise accept
		//it and ack.
		if self.mode == .Peripheral {
			if message.mtu > self.mtu || message.windowSize > self.windowSize {
				self.sendPeerInfoControlRequest(false, acceptFilter:[.TakeTurn,.NewMessage,.NewFileMessage,.Abort])
			} else {
				self.mtu = message.mtu
				self.windowSize = message.windowSize
				self.sendAck([.TakeTurn,.NewMessage,.NewFileMessage,.Abort])
			}
		}
	}
	
	/// Received a take turn message.
	func receivedTakeTurnMessage(message:BLEPlusSerialServiceProtocolMessage) {
		
		//if the central received a take turn message, the central by default
		//assumes control. The central is in charge of offering turns to the
		//peripheral to send it's messages.
		if self.mode == .Central {
			self.currentSendControl = nil
			self.turnMode = .Central
			self.sendAck([.Ack,.Abort])
			self.startSending()
			self.startOfferTurnTimer()
		}
		
		//if the peripheral receives a take turn message, it must have messages
		//to assume control. If it doesn't have messages it gives control back
		//to the central.
		if self.mode == .Peripheral {
			
			if self.messageQueue?.count < 1 {
				
				//no messages, give control back to central.
				self.turnMode = .Central
				self.stopOfferTurnTimer()
				self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Abort])
				
			} else {
				
				//peripheral has messages, ack to take control.
				self.turnMode = .Peripheral
				self.sendAck([.Ack,.Abort])
				self.startSending()
				self.startOfferTurnTimer()
			}
		}
	}
	
	/// When a data message was received. Data messages are packet payloads
	/// that get appended to the current packet receiver.
	func receivedDataMessage(message:BLEPlusSerialServiceProtocolMessage) {
		if let payload = message.packetPayload {
			self.currentReceiver?.receivedData(payload)
		}
	}
	
	/// Received a new message request.
	func receivedNewMessageRequest(message:BLEPlusSerialServiceProtocolMessage) {
		if self.currentReceiver != nil || self.currentUserMessage != nil {
			print("SHOULD ABORT")
			return
		}
		
		//setup new receiver
		let windowSize = self.windowSize
		let messageSize = message.messageSize
		let receiver = BLEPlusSerialServicePacketReceiver(withWindowSize: windowSize, messageSize: messageSize)
		self.currentReceiver = receiver
		self.currentReceiver?.messageType = message.messageType
		self.currentReceiver?.messageId = message.messageId
		self.sendAck([.Data,.Resend,.EndMessage,.EndPart,.Abort])
	}
	
	/// Receieved a new large message.
	func receivedNewLargeMessageRequest(message:BLEPlusSerialServiceProtocolMessage) {
		if currentReceiver != nil {
			print("SHOULD ABORT")
			return
		}
		
		let tmpFileURL = BLEPlusSerialServicePacketReceiver.getTempFileForWriting()
		guard let tmpFile = tmpFileURL else {
			return
		}
		
		//setup a new receiver
		let windowSize = self.windowSize
		let messageSize = message.messageSize
		let receiver = BLEPlusSerialServicePacketReceiver(withFileURLForWriting: tmpFile, windowSize: windowSize, messageSize: messageSize)
		self.currentReceiver = receiver
		self.currentReceiver?.messageType = message.messageType
		self.currentReceiver?.beginMessage()
		self.currentReceiver?.beginWindow()
		self.sendAck([.Data,.Resend,.EndMessage,.EndPart,.Abort])
	}
	
	/// Received an end part.
	func receivedEndPartMessage(message:BLEPlusSerialServiceProtocolMessage) {
		guard let currentReceiver = self.currentReceiver else {
			return
		}
		currentReceiver.windowSize = message.windowSize
		currentReceiver.commitPacketData()
		if currentReceiver.needsPacketsResent {
			let packet = currentReceiver.resendFromPacket()
			let resend = BLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: packet)
			self.sendControlMessage(resend, acceptFilter: [.Data,.EndMessage,.EndPart,.Abort], expectingAck: false)
		} else {
			currentReceiver.beginWindow()
			self.sendAck([.Data,.EndMessage,.EndPart,.Abort])
		}
	}
	
	/// Received an end message.
	func receivedEndMessage(message:BLEPlusSerialServiceProtocolMessage) {
		guard let currentReceiver = self.currentReceiver else {
			return
		}
		
		currentReceiver.windowSize = message.windowSize
		currentReceiver.commitPacketData()
		
		if currentReceiver.needsPacketsResent {
			
			let packet = currentReceiver.resendFromPacket()
			let resend = BLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: packet)
			self.sendControlMessage(resend, acceptFilter: [.Data,.EndMessage,.EndPart,.Abort])
			
		} else {
			
			let data = currentReceiver.data
			let fileURL = currentReceiver.fileURL
			let messageId = currentReceiver.messageId
			let messageType = currentReceiver.messageType
			self.currentReceiver?.finishMessage()
			self.currentReceiver = nil
			self.sendAck([.TakeTurn,.NewMessage,.NewFileMessage,.Abort])
			
			dispatch_async(self.delegateQueue, {
				
				if let data = data {
					if let _message = BLEPlusSerialServiceMessage(withMessageType: messageType, messageId: messageId, data: data) {
						self.delegate?.serialServiceController?(self, receivedMessage: _message)
					}
				}
				
				if let fileURL = fileURL {
					if let _message = BLEPlusSerialServiceMessage(withMessageType: messageType, messageId: messageId, fileURL: fileURL) {
						self.delegate?.serialServiceController?(self, receivedMessage: _message)
					}
				}
				
			})
		}
	}
	
	/// Received a resend control
	func receivedResendMessage(message:BLEPlusSerialServiceProtocolMessage) {
		guard let provider = self.currentUserMessage?.provider else {
			return
		}
		//TODO: fix resend from packet.
		//provider.resendFromPacket(message.resendFromPacket)
		provider.resendWindow()
		self.startSendingPackets(false)
	}
	
	/// Received an ack.
	public func receivedAck(message:BLEPlusSerialServiceProtocolMessage) {
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
		default:
			break
		}
	}
	
	/// Ack a new message.
	func receivedAckForNewMessage(message:BLEPlusSerialServiceProtocolMessage) {
		self.startSendingPackets()
	}
	
	/// Ack a new file message.
	func receivedAckForNewFileMessage(message:BLEPlusSerialServiceProtocolMessage) {
		self.startSendingPackets()
	}
	
	/// Ack end part
	func receivedAckForEndPart(message:BLEPlusSerialServiceProtocolMessage) {
		self.startSendingPackets()
	}
	
	/// Ack end message
	func receivedAckForEndMessage() {
		let cm = self.currentUserMessage
		dispatch_async(self.delegateQueue) {
			if let cm = cm {
				self.delegate?.serialServiceController?(self, sentMessage: cm)
			}
		}
		
		self.currentUserMessage?.provider?.finishMessage()
		self.currentUserMessage = nil
		self.messageQueue?.removeAtIndex(0)
		
		if self.turnMode == self.mode && self.messageQueue?.count < 1 {
			self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Abort])
			return
		}
		
		self.acceptFilter = [.TakeTurn,.Ack,.Abort]
		self.startSending()
	}
	
	/// When received an ack for take turn message
	func receivedAckForTakeTurn() {
		if self.mode == .Central {
			self.turnMode = .Peripheral
			self.acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Abort]
			self.stopOfferTurnTimer()
		}
		if self.mode == .Peripheral {
			self.turnMode = .Central
			self.acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Abort]
			self.stopOfferTurnTimer()
		}
	}
	
	/// When an ack was received for a peer info message.
	func receivedAckForPeerInfo() {
		self.hasDiscoverdPeerInfo = true
		self.acceptFilter = [.TakeTurn,.Ack,.Abort]
		self.startSending()
	}
}
