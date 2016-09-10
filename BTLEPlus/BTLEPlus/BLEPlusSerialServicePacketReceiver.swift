//
//  BLEPlusSerialServiceMessage.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/22/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// BLEPlusSerialServicePacketReceiver handles incoming data from a paar
/// and manages a packet counter. The receiver also figures out when
/// packets need to be resent from missing packets.
@objc class BLEPlusSerialServicePacketReceiver : NSObject {
	
	/// Data for smaller messages.
	var data:NSMutableData?
	
	/// File handle for larger messages.
	var fileHandle:NSFileHandle?
	
	/// The file url.
	var fileURL:NSURL?
	
	/// The user identifieable message type.
	var messageType:BLEPlusSerialServiceMessageType_Type = 0
	
	/// Message id.
	var messageId:BLEPLusSerialServiceMessageId_Type = 0
	
	/// Window Size. This is clamped between 0 and BLEPlusSerialServiceMaxWindowSize.
	var windowSize:BLEPlusSerialServiceWindowSize_Type {
		get {
			return _windowSize
		} set(new) {
			if new > BLEPlusSerialServiceMaxWindowSize || new < 0 {
				_windowSize = BLEPlusSerialServiceMaxWindowSize
			} else {
				_windowSize = new
			}
		}
	}
	private var _windowSize:BLEPlusSerialServiceWindowSize_Type = BLEPlusSerialServiceDefaultWindowSize
	
	/// Whether or not this receiver needs packets resent from the client.
	var needsPacketsResent:Bool = false
	
	/// The total bytes received.
	var bytesReceived:UInt64 = 0
	
	/// Total bytes in this message.
	private var messageSize:UInt64 = 0
	
	/// The expected next packet. If the next packet isn't equal to this
	/// resend flags are set.
	private var expectedPacket:BLEPlusSerialServicePacketCountType = 0
	
	/// The packet count when a new window was started.
	private var beginWindowPacketCount:BLEPlusSerialServicePacketCountType = 0
	
	/// Packets received. The size of this array is always windowSize.
	private var packets:[BLEPlusSerialServicePacketCountType:NSData]
	
	/**
	Default init.
	
	- returns: BLEPlusSerialServicePacketReceiver
	*/
	override init() {
		packets = [:]
		super.init()
	}
	
	/**
	Helper method to create a BLEPlusSerialServicePacketReceiver using a tmp file.
	
	- parameter windowSize:		Window size.
	- parameter messageSize:	The expected message size.
	*/
	class func createWithTmpFileForWriting(windowSize:UInt8, messageSize:UInt64 = 0) -> BLEPlusSerialServicePacketReceiver? {
		if let tmpFileURL = getTempFileForWriting() {
			print(tmpFileURL)
			return  BLEPlusSerialServicePacketReceiver(withFileURLForWriting: tmpFileURL, windowSize: windowSize, messageSize: messageSize)
		}
		return nil
	}
	
	/**
	Initialize a BLEPlusSerialServiceMessageRecever with maximum transmission unit
	and windowSize
	
	- parameter windowSize:		The number of open positions to received data.
	- parameter messageSize:	(Optional) The total message size in bytes.
	
	- returns: BLEPlusSerialServicePacketReceiver
	*/
	init?(withWindowSize:BLEPlusSerialServiceWindowSize_Type, messageSize:UInt64 = 0) {
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
	Initialize a BLEPlusSerialServicePacketReceiver with a file handle for writing,
	maximum transmission unit and windowSize. Use this for starting a large message
	that requires writing to a file as data is received.
	
	- parameter withFileHandleForWriting:	NSFileHandle opened for writing.
	- parameter windowSize:						Window size.
	- parameter messageSize:					(Optional) The total message size in bytes.
	
	- returns: BLEPlusSerialServicePacketReceiver
	*/
	init?(withFileURLForWriting:NSURL, windowSize:BLEPlusSerialServiceWindowSize_Type, messageSize:UInt64 = 0) {
		guard let path = withFileURLForWriting.path else {
			return nil
		}
		guard NSFileManager.defaultManager().fileExistsAtPath(path) else {
			return nil
		}
		packets = [:]
		super.init()
		self.fileURL = withFileURLForWriting
		self.fileHandle = NSFileHandle(forWritingAtPath: path)
		self.windowSize = windowSize
	}
	
	/**
	Reveive some more data to be appended to the message.
	
	- parameter data:	NSData
	
	- returns: BLEPlusSerialServiceReceivedDataStatus
	*/
	func receivedData(data:NSData) {
		var packet:BLEPlusSerialServicePacketCountType = 0
		data.getBytes(&packet, range: NSRange.init(location: 0, length: sizeof(packet.dynamicType)))
		if packet != expectedPacket {
			needsPacketsResent = true
		}
		let payload = data.subdataWithRange(NSRange.init(location: sizeof(packet.dynamicType), length: data.length-sizeof(packet.dynamicType)))
		packets[packet] = payload
		bytesReceived = bytesReceived + UInt64(payload.length)
		expectedPacket = packet + 1
		if expectedPacket == BLEPlusSerialServiceMaxPacketCounter {
			expectedPacket = 0
		}
	}
	
	/// Commit packet data by appending the current packet window to the message.
	func commitPacketData() {
		needsPacketsResent = false
		let part = NSMutableData()
		var loopPacketCounter = beginWindowPacketCount
		var writtenPackets:BLEPlusSerialServicePacketCountType = 0
		while(writtenPackets < windowSize) {
			if loopPacketCounter == BLEPlusSerialServiceMaxPacketCounter {
				loopPacketCounter = 0
			}
			if let packetData = packets[loopPacketCounter] {
				part.appendData(packetData)
			} else {
				needsPacketsResent = true
				return
			}
			writtenPackets = writtenPackets + 1
			loopPacketCounter = loopPacketCounter + 1
		}
		if let fileHandle = fileHandle {
			fileHandle.writeData(part)
		}
		else if let data = data {
			data.appendData(part)
		}
	}
	
	/// Returns the first missing packet from the current windowSize and packetCounter.
	func resendFromPacket() ->BLEPlusSerialServicePacketCountType {
		var loopPacketCounter = beginWindowPacketCount
		var totalChecked:BLEPlusSerialServicePacketCountType = 0
		while(totalChecked < windowSize) {
			if loopPacketCounter == BLEPlusSerialServiceMaxPacketCounter {
				loopPacketCounter = 0
			}
			let data = packets[loopPacketCounter]
			if data == nil {
				return loopPacketCounter
			}
			loopPacketCounter = loopPacketCounter + 1
			totalChecked = totalChecked + 1
		}
		return BLEPlusSerialServicePacketCountType.max
	}
	
	/**
	Utility for getting a tmp file as an NSFileHandle for writing.
	
	- returns: NSFileHandle?
	*/
	class func getTempFileForWriting() -> NSURL? {
		let templateString = "BLEPlusSerialService.XXXXXX"
		let template = NSURL(fileURLWithPath:NSTemporaryDirectory()).URLByAppendingPathComponent(templateString)
		var buffer = [Int8](count: Int(PATH_MAX), repeatedValue: 0)
		template.getFileSystemRepresentation(&buffer, maxLength: buffer.count)
		let fd = mkstemp(&buffer)
		if fd != -1 {
			close(fd)
			return NSURL(fileURLWithFileSystemRepresentation: buffer, isDirectory: false, relativeToURL: nil)
		}
		return nil
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
	
	// Sets the expected packet counter back to the expected packet
	// count when the active window was started
	func resetWindowForReceiving() {
		expectedPacket = beginWindowPacketCount
	}
	
	/// Starts a new receive window.
	func beginWindow() {
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
			return Float(bytesReceived) / Float(messageSize)
		}
		return -1
	}
}