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
	
	/// A delegate to receive activity messages.
	public var delegate:BLEPlusSerialServiceControllerDelegate?
	
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
	
	/// The delegate callback queue.
	private var delegateQueue:dispatch_queue_t
	
	/// Whether or not we're currently connected.
	private var isPaused = false
	
	/// Whether or not packet sending is paused, this is used as a way to immediately stop
	/// packet sending if the controller is paused while in the send packets loop.
	private var pausePackets = false
	
	/// Whether or not peer info has been discovered.
	private var hasDiscoverdPeerInfo = false
	
	/// Serial dispatch queue for processing activity.
	private var dispatchQueue:dispatch_queue_t
	
	/// Queue for sending user messages
	public var sendQueue:[BLEPlusSerialServiceMessage]?
	
	/// The current message being transmitted.
	private var currentUserMessage:BLEPlusSerialServiceMessage?
	
	/// A timer to wait for responses like acks.
	private var waitTimer:NSTimer?
	
	/// Current control message that was sent.
	private var currentSendControl:BLEPlusSerialServiceProtocolMessage?
	
	/// The current message receiver that's receiving data from the client or server.
	private var currentReceiver:BLEPlusSerialServicePacketReceiver?
	
	/// The mode this controller is running as.
	private var mode:BLEPlusSerialServiceControllerMode = .Central
	
	/// The mode for whoever's turn it is.
	private var turnMode:BLEPlusSerialServiceControllerMode = .Central
	
	/// A timer that keeps track of when to offer the peer a turn.
	private var offerTurnTimer:NSTimer?
	
	/// Whether or not a turn should be offered to the peer.
	private var shouldOfferTurn = false
	
	/// default init
	public init(withMode mode:BLEPlusSerialServiceControllerMode) {
		self.mode = mode
		sendQueue = []
		dispatchQueue = dispatch_queue_create("com.bleplus.SerialServiceController", DISPATCH_QUEUE_SERIAL)
		delegateQueue = dispatch_get_main_queue()
		super.init()
	}
	
	/**
	Initialize a BLEPlusSerialServiceController with a delegate queue.
	
	- parameter queue: The queue for delegate messages to callback on.
	
	- returns: BLEPlusSerialServiceController
	*/
	public init(withMode mode:BLEPlusSerialServiceControllerMode, delegateQueue queue:dispatch_queue_t) {
		sendQueue = []
		self.mode = mode
		dispatchQueue = dispatch_queue_create("com.bleplus.SerialServiceController", DISPATCH_QUEUE_SERIAL)
		delegateQueue = queue
		super.init()
	}
	
	/// Call this when you are connected and ready to send or receive data.
	public func resume() {
		pausePackets = false
		dispatch_async(dispatchQueue) {
			print("resume: set isPaused = false")
			self.isPaused = false
		}
		if resumeBlock != nil {
			dispatch_async(dispatchQueue) {
				self.resumeBlock?()
			}
		} else {
			self.startSending()
		}
	}
	
	/// Call this when you have been disconnected. The currently active messages
	/// packet counter is reset to resend the last window once resume is called
	/// again.
	public func pause() {
		pausePackets = true
		dispatch_async(dispatchQueue) {
			print("resume: set isPaused = true")
			self.isPaused = true
			self.currentUserMessage?.provider?.resendWindow()
			self.currentReceiver?.resetWindowForReceiving()
		}
	}
	
	/// Queue a message to be sent.
	public func send(message:BLEPlusSerialServiceMessage) {
		sendQueue?.append(message)
		startSending()
	}
	
	/// Start the offer turn timer.
	func startOfferTurnTimer() {
		//don't allow restarting the timer otherwise the peer won't get to send as
		//quikly as possible.
		if self.offerTurnTimer != nil {
			return
		}
		
		//if it's not our turn return
		if self.mode != self.turnMode {
			return
		}
		
		print("startOfferTurnTimer")
		self.offerTurnTimer?.invalidate()
		let timer = NSTimer(timeInterval: 5, target: self, selector: #selector(BLEPlusSerialServiceController.offerTurnTimeout(_:)), userInfo: nil, repeats: false)
		self.offerTurnTimer = timer
		NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSDefaultRunLoopMode)
	}
	
	/// End the offer turn timer.
	func endOfferTurnTimer() {
		print("endOfferTurnTimer")
		self.offerTurnTimer?.invalidate()
		self.offerTurnTimer = nil
	}
	
	/// When offer turn timer expires.
	func offerTurnTimeout(timer:NSTimer) {
		dispatch_async(dispatchQueue) {
			print("offerTurnTimeout")
			if self.mode != self.turnMode {
				return
			}
			if self.currentSendControl != nil || self.currentReceiver != nil || self.currentUserMessage != nil {
				self.shouldOfferTurn = true
			} else {
				self.sendTakeTurnControlMessage()
			}
		}
	}
	
	/// Ends the wait timer.
	func endWaitTimer() {
		waitTimer?.invalidate()
		waitTimer = nil
	}
	
	/// Starts the wait timer.
	func startWaitTimer() {
		waitTimer?.invalidate()
		let timer = NSTimer(timeInterval: 5, target: self, selector: #selector(BLEPlusSerialServiceController.waitTimeout(_:)), userInfo: nil, repeats: false)
		waitTimer = timer
		NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSDefaultRunLoopMode)
	}
	
	/// Wait timer timeout.
	func waitTimeout(timer:NSTimer?) {
		dispatch_async(dispatchQueue) { 
			if let currentSendControl = self.currentSendControl {
				self.sendControlMessage(currentSendControl)
			}
		}
	}
	
	/// Starts sending messages. The first message sent is a peer info message to
	/// either iform the peer of our mtu and window size, or in response we have to
	/// use the peripherals mtu/window size.
	func startSending() {
		resumeBlock = {
			print("resuming in startSending()")
			self.startSending()
		}
		
		dispatch_async(dispatchQueue) {
			self.startOfferTurnTimer()
			//if we're the central, send a peer info message.
			if !self.hasDiscoverdPeerInfo && self.mode == .Central {
				self.sendPeerInfoControlRequest()
				self.startWaitTimer()
			} else {
				if self.sendQueue?.count < 1 {
					return
				}
				if self.currentUserMessage != nil {
					return
				}
				if self.turnMode == self.mode {
					self.currentUserMessage = self.sendQueue?[0]
					self.sendNewMessageControlRequest()
				}
			}
		}
	}
	
	/// Start sending packets from the current message.
	func startSendingPackets(fillNewWindow:Bool = true) {
		resumeBlock = {
			print("resuming startSendingPackets(fillNewWindow: false)")
			self.startSendingPackets(false)
		}
		dispatch_async(dispatchQueue) {
			guard let provider = self.currentUserMessage?.provider else {
				return
			}
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
	
	/// End the current message.
	func endCurrentMessage() {
		dispatch_async(dispatchQueue) {
			if let cm = self.currentUserMessage {
				dispatch_async(self.delegateQueue) {
					self.delegate?.serialServiceController?(self, sentMessage: cm)
				}
			}
			self.currentUserMessage?.provider?.finishMessage()
			self.currentUserMessage = nil
			self.sendQueue?.removeAtIndex(0)
			if self.shouldOfferTurn {
				self.sendTakeTurnControlMessage()
				return
			}
			self.startSending()
		}
	}
	
	/// Resends the current control message.
	func resendCurrentControlMessage() {
		if isPaused {
			return
		}
		dispatch_async(dispatchQueue) {
			guard let data = self.currentSendControl?.data else {
				return
			}
			print("resending control data: ", data.bleplus_base16EncodedString(uppercase:true))
			dispatch_async(self.delegateQueue) {
				self.delegate?.serialServiceController(self, wantsToSendData: data)
			}
		}
	}
	
	/// Utility to send a control message.
	func sendControlMessage(message:BLEPlusSerialServiceProtocolMessage, expectingAck:Bool = true) {
		if isPaused {
			return
		}
		dispatch_async(dispatchQueue) {
			guard let data = message.data else {
				return
			}
			self.currentSendControl = message
			print("sending control data: ", data.bleplus_base16EncodedString(uppercase:true))
			self.delegate?.serialServiceController(self, wantsToSendData: data)
			if message.protocolType != .Ack {
				self.resumeBlock = {
					print("resuming sendControlMessage (\(message))")
					self.sendControlMessage(message)
				}
			}
			if message.protocolType == .TakeTurn {
				self.shouldOfferTurn = false
			}
			if expectingAck {
				self.startWaitTimer()
			}
		}
	}
	
	/// Send an ack
	func sendAck() {
		let ack = BLEPlusSerialServiceProtocolMessage(withType: .Ack)
		sendControlMessage(ack, expectingAck: false)
	}
	
	/// Send a new message control request.
	func sendNewMessageControlRequest() {
		guard let currentUserMessage = currentUserMessage else {
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
		sendControlMessage(newMessage)
	}
	
	/// Sends a take turn control message.
	func sendTakeTurnControlMessage() {
		self.endOfferTurnTimer()
		let takeTurn = BLEPlusSerialServiceProtocolMessage(withType: .TakeTurn)
		sendControlMessage(takeTurn, expectingAck: false)
	}
	
	/// Send an end of message control request.
	func sendEndMessageControlRequest(windowSize:BLEPlusSerialServiceWindowSize_Type) {
		let endMessage = BLEPlusSerialServiceProtocolMessage(endMessageWithWindowSize: windowSize)
		sendControlMessage(endMessage)
	}
	
	/// Send an end part message control request.
	func sendEndPartControlRequest(windowSize:BLEPlusSerialServiceWindowSize_Type) {
		let endPart = BLEPlusSerialServiceProtocolMessage(endPartWithWindowSize: windowSize)
		sendControlMessage(endPart)
	}
	
	/// Sends a peer info control request.
	func sendPeerInfoControlRequest(expectingAck:Bool = true) {
		let peerinfo = BLEPlusSerialServiceProtocolMessage(peerInfoMessageWithMTU: mtu, windowSize: windowSize)
		sendControlMessage(peerinfo, expectingAck: expectingAck)
	}
	
	/// Sends a resend transfer control request.
	func sendResendControlMessage(resendFromPacket:BLEPlusSerialServicePacketCountType) {
		let resend = BLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: resendFromPacket)
		sendControlMessage(resend)
	}
	
	/// Send an abort.
	func sendAbortControlMessage() {
		let pending = BLEPlusSerialServiceProtocolMessage(withType: .Abort)
		sendControlMessage(pending)
	}
	
	/// When you receive a control packet you must call this.
	public func receivedData(packet:NSData) {
		endWaitTimer()
		startOfferTurnTimer()
		resumeBlock = nil
		let message = BLEPlusSerialServiceProtocolMessage(withData: packet)
		switch message.protocolType {
		case .Ack:
			print("received ack:",packet.bleplus_base16EncodedString(uppercase:true))
			receivedAck(message)
		case .NewMessage:
			print("received new message:",packet.bleplus_base16EncodedString(uppercase:true))
			receivedNewMessageRequest(message)
		case .NewFileMessage:
			print("received new large:",packet.bleplus_base16EncodedString(uppercase:true))
			receivedNewLargeMessageRequest(message)
		case .EndPart:
			print("received end part:",packet.bleplus_base16EncodedString(uppercase:true))
			receivedEndPartMessage(message)
		case .EndMessage:
			print("received end message:",packet.bleplus_base16EncodedString(uppercase:true))
			receivedEndMessage(message)
		case .Resend:
			print("received resend:",packet.bleplus_base16EncodedString(uppercase:true))
			receivedResendMessage(message)
		case .PeerInfo:
			print("received peer info:",packet.bleplus_base16EncodedString(uppercase:true))
			receivedPeerInfoMessage(message)
		case .Data:
			print("received data message:",packet.bleplus_base16EncodedString(uppercase:true))
			receivedDataMessage(message)
		case .TakeTurn:
			print("received take turn message:",packet.bleplus_base16EncodedString(uppercase: true))
			receivedTakeTurnMessage(message)
		case .Abort:
			print("received abort:",packet.bleplus_base16EncodedString(uppercase:true))
			receivedAbortMessage(message)
		default:
			break
		}
	}
	
	/// Received an ack.
	public func receivedAck(message:BLEPlusSerialServiceProtocolMessage) {
		dispatch_async(dispatchQueue) { 
			guard let csc = self.currentSendControl else {
				return
			}
			switch csc.protocolType {
			case .NewMessage:
				self.startSendingPackets()
			case .NewFileMessage:
				self.startSendingPackets()
			case .EndPart:
				self.startSendingPackets()
			case .EndMessage:
				self.endCurrentMessage()
			case .PeerInfo:
				self.receivedAckForPeerInfo()
			case .Abort:
				self.receivedAckForAbort()
			case .TakeTurn:
				self.receivedAckForTakeTurn()
			default:
				break
			}
			self.currentSendControl = nil
		}
	}
	
	/// When received an ack for take turn message
	func receivedAckForTakeTurn() {
		dispatch_async(dispatchQueue) {
			//if we're the central and we received an ack for take turn it means the peripheral has messages.
			if self.mode == .Central {
				self.endOfferTurnTimer()
				self.turnMode = .Peripheral
			}
		}
	}
	
	/// When received a take turn message.
	func receivedTakeTurnMessage(message:BLEPlusSerialServiceProtocolMessage) {
		dispatch_async(dispatchQueue) {
			
			//if received a take turn message and we're the central we take control back.
			if self.mode == .Central {
				if self.currentSendControl?.protocolType == .TakeTurn {
					self.currentSendControl = nil
				}
				self.turnMode = .Central
				self.startSending()
			}
			
			//if received a take turn and we're the peripheral make sure there are messages
			//to send otherwise give control back to the central.
			if self.mode == .Peripheral {
				if self.sendQueue?.count < 1 {
					self.turnMode = .Central
					self.sendTakeTurnControlMessage()
				} else {
					self.endOfferTurnTimer()
					self.turnMode = .Peripheral
					self.sendAck()
					self.startSending()
				}
			}
		}
	}
	
	/// On ack for abort message.
	func receivedAckForAbort() {
		if mode == .Central {
			startSending()
		}
	}
	
	/// When an ack was received for a peer info message.
	func receivedAckForPeerInfo() {
		dispatch_async(dispatchQueue) {
			self.hasDiscoverdPeerInfo = true
			self.startSending()
		}
	}
	
	/// When a data message was received
	func receivedDataMessage(message:BLEPlusSerialServiceProtocolMessage) {
		dispatch_async(dispatchQueue) {
			if let payload = message.packetPayload {
				self.currentReceiver?.receivedData(payload)
			}
		}
	}
	
	/// Received a new message request
	func receivedNewMessageRequest(message:BLEPlusSerialServiceProtocolMessage) {
		dispatch_async(dispatchQueue) {
			if self.currentReceiver != nil {
				self.sendAbortControlMessage()
				return
			}
			
			//setup new receiver
			let windowSize = self.windowSize
			let messageSize = message.messageSize
			let receiver = BLEPlusSerialServicePacketReceiver(withWindowSize: windowSize, messageSize: messageSize)
			self.currentReceiver = receiver
			self.currentReceiver?.messageType = message.messageType
			self.currentReceiver?.messageId = message.messageId
			self.sendAck()
		}
	}
	
	/// Receieved a new large message request.
	func receivedNewLargeMessageRequest(message:BLEPlusSerialServiceProtocolMessage) {
		if currentReceiver != nil {
			self.sendAbortControlMessage()
			return
		}
		
		let tmpFileURL = BLEPlusSerialServicePacketReceiver.getTempFileForWriting()
		guard let tmpFile = tmpFileURL else {
			return
		}
		
		dispatch_async(dispatchQueue) {
			//setup a new receiver
			let windowSize = self.windowSize
			let messageSize = message.messageSize
			let receiver = BLEPlusSerialServicePacketReceiver(withFileURLForWriting: tmpFile, windowSize: windowSize, messageSize: messageSize)
			self.currentReceiver = receiver
			self.currentReceiver?.messageType = message.messageType
			self.currentReceiver?.beginMessage()
			self.currentReceiver?.beginWindow()
			self.sendAck()
		}
	}
	
	/// Received an end part control
	func receivedEndPartMessage(message:BLEPlusSerialServiceProtocolMessage) {
		guard let currentReceiver = currentReceiver else {
			return
		}
		dispatch_async(dispatchQueue) {
			currentReceiver.windowSize = message.windowSize
			currentReceiver.commitPacketData()
			if currentReceiver.needsPacketsResent {
				let packet = currentReceiver.resendFromPacket()
				let resend = BLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: packet)
				self.sendControlMessage(resend)
			} else {
				currentReceiver.beginWindow()
				self.sendAck()
			}
		}
	}
	
	/// Received an end message control
	func receivedEndMessage(message:BLEPlusSerialServiceProtocolMessage) {
		guard let currentReceiver = currentReceiver else {
			return
		}
		dispatch_async(dispatchQueue) {
			currentReceiver.windowSize = message.windowSize
			currentReceiver.commitPacketData()
			if currentReceiver.needsPacketsResent {
				let packet = currentReceiver.resendFromPacket()
				let resend = BLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: packet)
				self.sendControlMessage(resend)
			} else {
				dispatch_async(self.delegateQueue, {
					if let data = currentReceiver.data {
						if let _message = BLEPlusSerialServiceMessage(withType: currentReceiver.messageType, messageId: currentReceiver.messageId,data: data) {
							self.delegate?.serialServiceController?(self, receivedMessage: _message)
						}
					}
					if let fileURL = currentReceiver.fileURL {
						if let _message = BLEPlusSerialServiceMessage(withType: currentReceiver.messageType, messageId: currentReceiver.messageId, fileURL: fileURL) {
							self.delegate?.serialServiceController?(self, receivedMessage: _message)
						}
					}
					dispatch_async(self.dispatchQueue) {
						self.currentReceiver?.finishMessage()
						self.currentReceiver = nil
						self.sendAck()
					}
				})
			}
		}
	}
	
	/// Received an abort.
	func receivedAbortMessage(message:BLEPlusSerialServiceProtocolMessage) {
		print("received abort",message)
		dispatch_async(dispatchQueue) { 
			if self.mode == .Central {
				self.endWaitTimer()
				self.endOfferTurnTimer()
				self.resumeBlock = nil
				self.currentUserMessage?.provider?.reset()
				self.sendAck()
			}
			if self.mode == .Peripheral {
				self.endOfferTurnTimer()
				self.currentReceiver?.reset()
				self.currentReceiver = nil
				self.sendAck()
			}
		}
	}
	
	/// Received a resend control
	func receivedResendMessage(message:BLEPlusSerialServiceProtocolMessage) {
		dispatch_async(dispatchQueue) {
			guard let provider = self.currentUserMessage?.provider else {
				return
			}
			//TODO: fix resend from packet.
			//provider.resendFromPacket(message.resendFromPacket)
			provider.resendWindow()
			self.startSendingPackets(false)
		}
	}
	
	/// Received a peer info control
	func receivedPeerInfoMessage(message:BLEPlusSerialServiceProtocolMessage) {
		dispatch_async(dispatchQueue) {
			print("peer info message details: ",message.mtu,message.windowSize)
			
			//If we're the central and received a peer info, in response to a peer info,
			//it means the centrals' mtu/windowsize was too large, so use the providedi
			//info instead.
			if self.mode == .Central {
				if let currentSendControl = self.currentSendControl {
					if currentSendControl.protocolType == .PeerInfo {
						self.currentSendControl = nil
						self.hasDiscoverdPeerInfo = true
						self.mtu = message.mtu
						self.windowSize = message.windowSize
						self.startSendingPackets()
						return
					}
				}
			}
			
			//if we receive a peer info with too big of sizes return a response with what we can handle.
			if self.mode == .Peripheral {
				if message.mtu > self.mtu || message.windowSize > self.windowSize {
					self.sendPeerInfoControlRequest(false)
					return
				}
			}
			
			//save info and ack.
			self.hasDiscoverdPeerInfo = true
			self.mtu = message.mtu
			self.windowSize = message.windowSize
			self.sendAck()
		}
	}
}