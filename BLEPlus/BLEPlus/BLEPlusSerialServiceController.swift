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
public enum BLEPlusSerialServiceControllerMode :UInt8 {
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

/// BLEPlusSerialServiceController is controller that has logic to send
/// and receive data over the BLEPlusSerialService protocol.
///
/// It's up to you to send the data. You need to implement the
/// BLEPlusSerialServiceControllerDelegate and send the data yourself when
/// serialServiceController(_:wantesToSendData:) is called.
///
/// When you receive data, it's up to you to call receivedData.
///
/// In order to send something custom, you use BLEPlusSerialServiceMessage and
/// call send.
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
	
	/// Whether or not some activity is currently underway. This is used to not
	/// allow any messages or controls to be send while active.
	private var isActive = false
	
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
	
	/// Whether or not a turn should be offered to the peer.
	private var shouldOfferTurn = false
	
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
//		if self.offerTurnTimer != nil {
//			print("offer turn timer already running.")
//			return
//		}
//		print("startOfferTurnTimer")
//		let timer = NSTimer(timeInterval: 3, target: self, selector: #selector(BLEPlusSerialServiceController.offerTurnTimeout(_:)), userInfo: nil, repeats: true)
//		self.offerTurnTimer = timer
//		NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSDefaultRunLoopMode)
	}
	
	// Stops the offer turn timer
	func stopOfferTurnTimer() {
//		self.offerTurnTimer?.invalidate()
//		self.offerTurnTimer = nil
	}
	
	/// When offer turn timer expires.
	func offerTurnTimeout(timer:NSTimer) {
		dispatch_async(serialQueue) {
//			if self.turnMode == self.mode {
//				if self.mode == .Central && self.currentUserMessage == nil && self.currentSendControl == nil {
//					self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Abort])
//				}
//				if self.mode == .Peripheral && self.currentReceiver == nil && self.currentSendControl == nil {
//					self.sendTakeTurnControlMessage(true, acceptFilter: [.TakeTurn,.Ack,.Abort])
//				}
//			}
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
		pausePackets = false
		dispatch_async(serialQueue) {
			print("resume: set isPaused = false")
			self.isPaused = false
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
		//this is specifically left out of the serial queue so that the loop
		//in startSendingPackets will exit early if this is ever called while
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
		
		// Set resume block in case we get paused.
		self.resumeBlock = {
			print("resuming startSendingPackets(fillNewWindow: false)")
			self.startSendingPackets(false)
		}
		
		dispatch_async(serialQueue) {
			guard let provider = self.currentUserMessage?.provider else {
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
			
			if message.protocolType == .TakeTurn {
				self.shouldOfferTurn = false
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
	
	/// Aborts current activity, sends abort message, and resets internal vars.
	func abort() {
		
		//when aborting the central always assumes control
		self.turnMode = .Central
		
		//reset provider, receiver and other vars
		self.currentUserMessage?.provider?.resendWindow()
		self.currentReceiver?.resetWindowForReceiving()
		self.stopOfferTurnTimer()
		self.stopResendControlMessageTimer()
		self.currentSendControl = nil
		self.hasDiscoverdPeerInfo = false
		self.resumeBlock = nil
		
		//create message
		let abort = BLEPlusSerialServiceProtocolMessage(withType: .Abort)
		
		//if we're the peripheral send message and update acceptFilter
		if self.mode == .Peripheral {
			self.sendControlMessage(abort, acceptFilter:[.PeerInfo,.Abort], expectingAck: false)
		}
		
		//if we're the central send message and update acceptFilter, start sending more
		if self.mode == .Central {
			self.sendControlMessage(abort, acceptFilter:[.PeerInfo,.Ack,.Abort], expectingAck: false)
			self.startSending()
		}
	}
	
	//MARK: - Receiving
	
	/// When you receive data you must call this.
	public func receivedData(packet:NSData) {
		dispatch_async(serialQueue) {
			//create a message
			let message = BLEPlusSerialServiceProtocolMessage(withData: packet)
			
			//check if incoming message protocol type is allowed.
//			if !self.acceptFilter.contains(message.protocolType) {
//
//				if self.mode == .Peripheral && message.protocolType == .NewMessage || message.protocolType == .NewFileMessage && self.currentReceiver == nil {
//					print("allow it!")
//				} else if self.mode == .Central && message.protocolType == .TakeTurn && self.currentUserMessage == nil {
//					print("allow it!")
//				} else {
//				print("filtered control type, now allowing:",message.data?.bleplus_base16EncodedString())
//				return
//				}
//			}
			
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
			case .Busy:
				print("received busy message:",packet.bleplus_base16EncodedString(uppercase: true))
				self.receivedBusyMessage(message)
			case .Abort:
				print("received abort:",packet.bleplus_base16EncodedString(uppercase:true))
				self.receivedAbortMessage(message)
			default:
				break
			}
		}
	}
	
	func receivedBusyMessage(message:BLEPlusSerialServiceProtocolMessage) {
		//self.pause()
		let t = NSTimer(timeInterval: 1, target: self, selector: #selector(BLEPlusSerialServiceController.tryAgain(_:)), userInfo: nil, repeats: false)
		NSRunLoop.mainRunLoop().addTimer(t, forMode: NSDefaultRunLoopMode)
	}
	
	func tryAgain(timer:NSTimer) {
		//self.resume()
		let expectAck = self.currentSendControl!.protocolType == .Ack
		self.sendControlMessage(self.currentSendControl!, acceptFilter: self.acceptFilter, expectingAck: !expectAck)
	}
	
	/// When received a take turn message.
	func receivedTakeTurnMessage(message:BLEPlusSerialServiceProtocolMessage) {
			
		//if the central received a take turn message, we assume control
		if self.mode == .Central {
			self.currentSendControl = nil
			self.turnMode = .Central
			self.acceptFilter = [.TakeTurn,.Resend,.Ack,.Abort]
			self.startSending()
			self.startOfferTurnTimer()
		}
		
		//if the peripheral receives a take turn message, it must have messages
		//to assume control. If it doesn't have messages it gives control back
		//to the central.
		if self.mode == .Peripheral {
			if self.messageQueue?.count < 1 {
				self.turnMode = .Central
				self.stopOfferTurnTimer()
				self.sendTakeTurnControlMessage(false, acceptFilter: [.TakeTurn,.NewMessage,.NewFileMessage,.Abort])
			} else {
				self.turnMode = .Peripheral
				self.sendAck([.Resend,.Abort])
				self.startSending()
				self.startOfferTurnTimer()
			}
		}
	}
	
	/// When a data message was received
	func receivedDataMessage(message:BLEPlusSerialServiceProtocolMessage) {
		if let payload = message.packetPayload {
			self.currentReceiver?.receivedData(payload)
		}
	}
	
	/// Received a new message request
	func receivedNewMessageRequest(message:BLEPlusSerialServiceProtocolMessage) {
		if self.currentReceiver != nil || self.currentUserMessage != nil {
			let busy = BLEPlusSerialServiceProtocolMessage(withType: .Busy)
			self.sendControlMessage(busy, acceptFilter: self.acceptFilter)
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
	
	/// Receieved a new large message request.
	func receivedNewLargeMessageRequest(message:BLEPlusSerialServiceProtocolMessage) {
		if currentReceiver != nil {
			self.abort()
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
	
	/// Received an end part control
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
			self.sendAck([.Data,.EndMessage,.Abort])
		}
	}
	
	/// Received an end message control
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
	
	/// Received an abort.
	func receivedAbortMessage(message:BLEPlusSerialServiceProtocolMessage) {
		print("received abort",message)
		
		if self.mode == .Central {
			self.stopResendControlMessageTimer()
			self.resumeBlock = nil
			self.currentUserMessage?.provider?.reset()
			self.hasDiscoverdPeerInfo = false
			self.acceptFilter = [.TakeTurn,.PeerInfo]
		}
		
		if self.mode == .Peripheral {
			self.currentReceiver?.reset()
			self.currentReceiver = nil
			self.sendAck([.PeerInfo])
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
	
	/// Received a peer info control
	func receivedPeerInfoMessage(message:BLEPlusSerialServiceProtocolMessage) {
		print("peer info message details: ",message.mtu,message.windowSize)
		
		//If we're the central and received a peer info, in response to a peer info,
		//it means the centrals' mtu/windowsize was too large, so use the provided
		//info instead and start sending.
		if self.mode == .Central {
			if let currentSendControl = self.currentSendControl {
				if currentSendControl.protocolType == .PeerInfo {
					self.currentSendControl = nil
					self.hasDiscoverdPeerInfo = true
					self.mtu = message.mtu
					self.windowSize = message.windowSize
					self.acceptFilter = [.TakeTurn,.Resend,.Abort]
					self.startSending()
				} else {
					self.hasDiscoverdPeerInfo = true
					self.mtu = message.mtu
					self.windowSize = message.windowSize
				}
			}
		}
		
		//if we receive a peer info with too big of sizes return a response with what we can handle.
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
	
	/// Received an ack.
	public func receivedAck(message:BLEPlusSerialServiceProtocolMessage) {
		guard let csc = self.currentSendControl else {
			return
		}
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
		self.currentSendControl = nil
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
		dispatch_async(self.delegateQueue) {
			if let cm = self.currentUserMessage {
				self.delegate?.serialServiceController?(self, sentMessage: cm)
			}
		}
		self.currentUserMessage?.provider?.finishMessage()
		self.currentUserMessage = nil
		self.messageQueue?.removeAtIndex(0)
		self.acceptFilter = [.Resend,.Ack,.Abort]
		self.startSending()
	}
	
	/// When received an ack for take turn message
	func receivedAckForTakeTurn() {
		//only the central receives an ack from peripheral to indicate it has messages
		if self.mode == .Central {
			self.turnMode = .Peripheral
			self.acceptFilter = [.TakeTurn,.NewMessage,.NewFileMessage,.Abort]
			self.stopOfferTurnTimer()
		}
	}
	
	/// When an ack was received for a peer info message.
	func receivedAckForPeerInfo() {
		self.hasDiscoverdPeerInfo = true
		self.acceptFilter = []
		self.startSending()
	}
}
