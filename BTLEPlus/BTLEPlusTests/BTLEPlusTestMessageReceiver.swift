//
//  BLEPlusTestMessageReceiver.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/27/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BTLEPlusTestMessageReceiver : XCTestCase {
	
	func testWindowSizeMax() {
		let _receiver = BTLEPlusSerialServicePacketReceiver(withWindowSize: 200)
		assert(_receiver!.windowSize == BTLEPlusSerialServiceMaxWindowSize)
	}
	
	func testProgress() {
		let _receiver = BTLEPlusSerialServicePacketReceiver(withWindowSize: 128)
		_receiver?.bytesReceived = 100
		_receiver?.messageSize = 100
		assert(_receiver?.progress() == 1)
		_receiver?.bytesReceived = 50
		_receiver?.messageSize = 100
		assert(_receiver?.progress() == 0.5)
		_receiver?.messageSize = 0
		assert(_receiver?.progress() == 0)
	}
	
	func testZeroWindowSize() {
		let _receiver = BTLEPlusSerialServicePacketReceiver(withWindowSize: 0)
		assert(_receiver == nil)
	}
	
	func testBadURLs() {
		var url = NSURL()
		var receiver = BTLEPlusSerialServicePacketReceiver(withFileURLForWriting: url, windowSize: 32)
		assert(receiver == nil)
		
		url = NSURL.fileURLWithPath("/var/abc123")
		receiver = BTLEPlusSerialServicePacketReceiver(withFileURLForWriting: url, windowSize: 32)
		assert(receiver == nil)
	}
	
	func testBadSizes() {
		let fileURL = NSFileManager.defaultManager().getTempFileForWriting()
		let receiver = BTLEPlusSerialServicePacketReceiver(withFileURLForWriting: fileURL!, windowSize: 0)
		assert(receiver == nil)
		_ = try? NSFileManager.defaultManager().removeItemAtURL(fileURL!) //this is just cleanup so empty files don't alarm me.
	}
}
