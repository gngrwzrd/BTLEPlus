//
//  BTLEPlusSerialServiceMessageSender.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 8/24/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// BTLEPlusSerialServicePacketProvider provides packets to send
/// based on maximum transmission unit and send window size.
/// You can request the provider resends packets from a specific
/// packet number, or resend the entire send window.
@objc class BTLEPlusSerialServicePacketProvider : NSObject {
	
	/// The header size for a packet from this provider.
	/// Default value is currently 1 byte for the packet counter.
	static var headerSize:UInt8 = 1
	
	/// Maximum transmission unit.
	var mtu:BTLEPlusSerialServiceMTU_Type = BTLEPlusSerialServiceDefaultMTU
	
	/// Window size 
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
	private var _windowSize:BTLEPlusSerialServiceWindowSize_Type = BTLEPlusSerialServiceMaxWindowSize
	
	/// The provider source when small messages are sending an NSData.
	var data:NSData?
	
	/// The file url to send.
	var fileURL:NSURL?
	
	/// The provider source when sending a large message using NSFileHandle.
	var fileHandle:NSFileHandle?
	
	/// The total message size.
	var messageSize:UInt64 = 0
	
	/// Total bytes written to the send window. This doesn't necessarily mean
	/// the bytes were received by the server.
	var bytesWritten:UInt64 = 0
	
	/// The total bytes written when fillWindow was called. This is used to
	/// revert the total bytes written when a resend happens.
	var bytesWrittenAtFill:UInt64 = 0
	
	/// Send window. Size of the array is always windowSize.
	var packets:[BTLEPlusSerialServicePacketCounter_Type:NSData]
	
	/// Packet counter.
	var packetCounter:BTLEPlusSerialServicePacketCounter_Type = 0
	
	/// The number of packets returned from getPacket(). This is reset with fillWindow().
	var gotPacketCount:BTLEPlusSerialServicePacketCounter_Type = 0
	
	/// Whether or not the current data in the send window is the last part of data.
	var isEndOfMessage:Bool = false
	
	/// The window size for the end of message. When a message reaches the
	/// end the window size will generally not be full. This will return the smaller
	/// window size that should be used.
	var endOfMessageWindowSize:BTLEPlusSerialServiceWindowSize_Type = 0
	
	/// The last packet counter value when fillWindow was called. This is set so that
	/// resendWindow will reset the packet counter to this value.
	var lastPacketCounterStart:UInt8 = 0
	
	/// The last file offset position when the window was filled. This is set so that
	/// resendWindow will reset the file position at the right offset.
	var lastFileOffsetAtStart:UInt64 = 0
	
	/**
	Init with data to send.
	
	- parameter withData:	NSData to send.
	
	- returns: BTLEPlusSerialServicePacketProvider
	*/
	init?(withData:NSData) {
		guard withData.length > 0 else {
			return nil
		}
		self.data = withData
		messageSize = UInt64(withData.length)
		packets = [:]
	}
	
	/**
	Init with file url for reading to send.
	
	- parameter withFileHandleForReading:	NSFileHandle for reading.
	- parameter fileSize:						The size of the file.
	
	- returns: BTLEPlusSerialServicePacketProvider
	*/
	init?(withFileURLForReading:NSURL) {
		guard let path = withFileURLForReading.path else {
			return nil
		}
		guard NSFileManager.defaultManager().fileExistsAtPath(path) else {
			return nil
		}
		fileURL = withFileURLForReading
		fileHandle = NSFileHandle(forReadingAtPath: path)
		packets = [:]
		let attributes = try? NSFileManager.defaultManager().attributesOfItemAtPath(fileURL!.path!)
		if let attributes = attributes {
			let size = attributes[NSFileSize] as? NSNumber
			messageSize = size!.unsignedLongLongValue
		}
	}
	
	/// Fills the send window with packets. This must be called before using getPacket().
	/// This automically resets the send window, don't call this before knowing all
	/// packets have been received.
	func fillWindow() {
		packets = [:]
		lastPacketCounterStart = packetCounter
		bytesWrittenAtFill = bytesWritten
		if let fileHandle = fileHandle {
			lastFileOffsetAtStart = fileHandle.offsetInFile
		}
		gotPacketCount = 0
		
		var packet:NSData? = nil
		var windowUsedCount:BTLEPlusSerialServiceWindowSize_Type = 0
		var wrappedPacket:NSMutableData? = nil
		let mtuInt = Int(mtu) - Int(BTLEPlusSerialServicePacketProvider.headerSize + BTLEPlusSerialServiceProtocolMessage.headerSize)
		var loopPacketCounter = packetCounter
		
		while(true) {
			
			if loopPacketCounter == BTLEPlusSerialServiceMaxPacketCounter {
				loopPacketCounter = 0
			}
			
			if fileHandle != nil {
				packet = fileHandle?.readDataOfLength(mtuInt)
			}
			
			if data != nil {
				let dataLen = data!.length
				if (dataLen - Int(bytesWritten)) < mtuInt {
					packet = data!.subdataWithRange(NSRange.init(location: Int(bytesWritten), length:  dataLen-Int(bytesWritten)))
				} else {
					packet = data!.subdataWithRange(NSRange.init(location: Int(bytesWritten), length: mtuInt))
				}
			}
			
			if packet?.length < mtuInt {
				isEndOfMessage = true
			}
			
//			if packet!.length < 1 {
//				isEndOfMessage = true
//				break
//			}
			
			wrappedPacket = NSMutableData(capacity: sizeof(BTLEPlusSerialServicePacketCounter_Type.self) + packet!.length)
			wrappedPacket?.appendBytes(&loopPacketCounter, length: sizeof(loopPacketCounter.self.dynamicType))
			wrappedPacket?.appendData(packet!)
			packets[loopPacketCounter] = wrappedPacket
			bytesWritten = bytesWritten + UInt64(packet!.length)
			windowUsedCount = windowUsedCount + 1
			loopPacketCounter = loopPacketCounter + 1
			
			if isEndOfMessage {
				break
			}
			
			if windowUsedCount == windowSize {
				break
			}
		}
		
		if isEndOfMessage {
			endOfMessageWindowSize = UInt8(packets.count)
		}
	}
	
	/// Whether or not this provider has packets left to send.
	func hasPackets() -> Bool {
		return gotPacketCount < UInt8(packets.count)
	}
	
	/// Returns a packet.
	func getPacket() -> NSData {
		let packet = packets[packetCounter]
		packetCounter = packetCounter + 1
		if packetCounter == BTLEPlusSerialServiceMaxPacketCounter {
			packetCounter = 0
		}
		gotPacketCount = gotPacketCount + 1
		return packet!
	}
	
	/// Reset the packet counter to resend from a specific packet.
	func resendFromPacket(packetCount:BTLEPlusSerialServicePacketCounter_Type) {
		packetCounter = packetCount
		gotPacketCount = 0
		//isEndOfMessage = false
		
		//loop and add how many packets were sent.
		var packet = lastPacketCounterStart
		while gotPacketCount < windowSize  {
			if packet ==  BTLEPlusSerialServiceMaxPacketCounter {
				packet = 0
			}
			if packet == packetCount {
				break
			}
			packet += 1
			gotPacketCount += 1
		}
		
		//subtract from bytes written for packets that had to be resent.
		let diff:UInt64 = UInt64( ( UInt16(windowSize) - UInt16(gotPacketCount) ) * mtu)
		if bytesWritten > diff {
			bytesWritten -= diff
		} else {
			bytesWritten = 0
		}
	}
	
	/// Send progress. This is the progress of how many total bytes have been written
	/// to the send window, not necessarily how many bytes were transmitted and received.
	func progress() -> Float {
		return Float(bytesWritten) / Float(messageSize)
	}
	
	/// End the entire message.
	func finishMessage() {
		reset()
		fileHandle?.closeFile()
	}
	
	/// Reset internal vars
	func reset() {
		packets = [:]
		packetCounter = 0
		bytesWritten = 0
		if let fileHandle = fileHandle {
			fileHandle.seekToFileOffset(0)
		}
	}
}