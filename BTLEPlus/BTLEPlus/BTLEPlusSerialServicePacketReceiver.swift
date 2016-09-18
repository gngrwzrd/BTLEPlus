//
//  BTLEPlusSerialServiceMessage.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 8/22/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// BTLEPlusSerialServicePacketReceiver handles incoming data from a peer
/// and manages a packet counter. The receiver also figures out when packets
/// need to be resent from missing packets.
@objc class BTLEPlusSerialServicePacketReceiver : NSObject {
	
	/// Data for smaller messages.
	var data:NSMutableData?
	
	/// The file url.
	var fileURL:NSURL?
	
	/// File handle for larger messages.
	var fileHandle:NSFileHandle?
	
	/// Window Size. This is clamped between 0 and BTLEPlusSerialServiceMaxWindowSize.
	var windowSize:BTLEPlusSerialServiceWindowSize_Type {
		get {
			return _windowSize
		} set(new) {
			if new > BTLEPlusSerialServiceMaxWindowSize || new < 0 {
				_windowSize = BTLEPlusSerialServiceMaxWindowSize
			} else {
				_windowSize = new
			}
		}
	}
	var _windowSize:BTLEPlusSerialServiceWindowSize_Type = BTLEPlusSerialServiceDefaultWindowSize
	
	/// Whether or not this receiver needs packets resent from the client.
	var needsPacketsResent:Bool = false
	
	/// The packet to resend from.
	var resendFromPacket:BTLEPlusSerialServicePacketCounter_Type = 0
	
	/// The total bytes received.
	var bytesReceived:UInt64 = 0
	
	/// The total bytes received before committing packet data.
	var bytesReceivedBeforeCommit:UInt64 = 0
	
	/// Total bytes in this message.
	var messageSize:UInt64 = 0
	
	/// The expected next packet. If the next packet isn't equal to this
	/// resend flags are set.
	var expectedPacket:BTLEPlusSerialServicePacketCounter_Type = 0
	
	/// The packet count when a new window was started.
	var beginWindowPacketCount:BTLEPlusSerialServicePacketCounter_Type = 0
	
	/// Packets received. The size of this array is always windowSize.
	var packets:[BTLEPlusSerialServicePacketCounter_Type:NSData]
	
	/**
	Initialize a BTLEPlusSerialServiceMessageRecever with maximum transmission unit
	and windowSize
	
	- parameter windowSize:		The number of open positions to received data.
	- parameter messageSize:	(Optional) The total message size in bytes.
	
	- returns: BTLEPlusSerialServicePacketReceiver
	*/
	init?(withWindowSize:BTLEPlusSerialServiceWindowSize_Type, messageSize:UInt64 = 0) {
		guard withWindowSize > 0 else {
			return nil
		}
		packets = [:]
		super.init()
		self.windowSize = withWindowSize
		self.messageSize = messageSize
		self.data = NSMutableData()
	}
	
	/**
	Initialize a BTLEPlusSerialServicePacketReceiver with a file handle for writing,
	maximum transmission unit and windowSize. Use this for starting a large message
	that requires writing to a file as data is received.
	
	- parameter withFileHandleForWriting:	NSFileHandle opened for writing.
	- parameter windowSize:						Window size.
	- parameter messageSize:					(Optional) The total message size in bytes.
	
	- returns: BTLEPlusSerialServicePacketReceiver
	*/
	init?(withFileURLForWriting:NSURL, windowSize:BTLEPlusSerialServiceWindowSize_Type, messageSize:UInt64 = 0) {
		guard let path = withFileURLForWriting.path else {
			return nil
		}
		guard NSFileManager.defaultManager().fileExistsAtPath(path) else {
			return nil
		}
		guard windowSize > 0 else {
			return nil
		}
		packets = [:]
		super.init()
		self.fileURL = withFileURLForWriting
		self.fileHandle = NSFileHandle(forWritingAtPath: path)
		self.windowSize = windowSize
	}
	
	/**
	Receive some more data to be appended to the message.
	
	- parameter data:	NSData
	
	- returns: BTLEPlusSerialServiceReceivedDataStatus
	*/
	func receivedData(data:NSData) {
		var packet:BTLEPlusSerialServicePacketCounter_Type = 0
		data.getBytes(&packet, range: NSRange.init(location: 0, length: sizeof(packet.dynamicType)))
		if packet != expectedPacket {
			needsPacketsResent = true
		}
		let payload = data.subdataWithRange(NSRange.init(location: sizeof(packet.dynamicType), length: data.length-sizeof(packet.dynamicType)))
		packets[packet] = payload
		bytesReceivedBeforeCommit += UInt64(payload.length)
		expectedPacket = packet + 1
		if expectedPacket == BTLEPlusSerialServiceMaxPacketCounter {
			expectedPacket = 0
		}
	}
	
	/// Commit packet data by appending the current packet window to the message.
	func commitPacketData() {
		needsPacketsResent = false
		let part = NSMutableData()
		var loopPacketCounter = beginWindowPacketCount
		var writtenPackets:BTLEPlusSerialServicePacketCounter_Type = 0
		while(writtenPackets < windowSize) {
			if loopPacketCounter == BTLEPlusSerialServiceMaxPacketCounter {
				loopPacketCounter = 0
			}
			if let packetData = packets[loopPacketCounter] {
				part.appendData(packetData)
			} else {
				resendFromPacket = loopPacketCounter
				needsPacketsResent = true
				return
			}
			writtenPackets = writtenPackets + 1
			loopPacketCounter = loopPacketCounter + 1
		}
		bytesReceived += bytesReceivedBeforeCommit
		bytesReceivedBeforeCommit = 0
		if let fileHandle = fileHandle {
			fileHandle.writeData(part)
		}
		else if let data = data {
			data.appendData(part)
		}
	}
	
	/// Resets internal vars and empties out the receive window.
	func reset() {
		needsPacketsResent = false
		packets = [:]
	}
	
	/// Begins a new message using either an NSData for small messages or a fileHandle for writing.
	func beginMessage() {
		if fileHandle == nil {
			data = NSMutableData()
		}
		reset()
	}
	
	/// Starts a new receive window.
	func beginWindow() {
		bytesReceivedBeforeCommit = 0
		beginWindowPacketCount = expectedPacket
		packets = [:]
	}
	
	/**
	Ends the current message and commits the current receive window to the final
	message data.
	
	If there are missing packets in the final receive window this will return false.
	
	- returns: Bool
	*/
	func finishMessage() {
		reset()
		data = nil
		fileHandle?.closeFile()
	}
	
	/// Receive progress. This is the progress of how many total bytes have been received
	/// to the receive window, but not necessarily how many bytes have been written to disk
	/// if it's a large message.
	func progress() -> Float {
		if messageSize > 0 {
			return (Float(bytesReceived) + Float(bytesReceivedBeforeCommit)) / Float(messageSize)
		}
		return 0
	}
}