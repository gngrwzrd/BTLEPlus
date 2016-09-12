//
//  BLEPlusTestMessageProvider_NSData.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/26/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BLEPlusTestMessageProvider_NSData : XCTestCase {
	
	func testProviderWithData() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let data = NSData(contentsOfURL: fileURL!)
		let provider = BTLEPlusSerialServicePacketProvider(withData: data!)
		assert(provider!.data != nil)
	}
	
	func testAllParts() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let data = NSData(contentsOfURL: fileURL!)
		let _provider = BTLEPlusSerialServicePacketProvider(withData: data!)
		_provider?.mtu = 1024
		_provider?.windowSize = 25
		guard let provider = _provider else {
			assert(false)
		}
		while(true) {
			provider.fillWindow()
			var i:UInt8 = 0
			while(i < provider.windowSize) {
				_ = provider.getPacket()
				print(provider.progress())
				i = i + 1
				if provider.isEndOfMessage {
					break
				}
			}
			if provider.isEndOfMessage {
				break
			}
			print(provider.bytesWritten)
		}
		print(provider.bytesWritten)
		print(provider.windowSize)
		print(provider.progress())
		assert(provider.bytesWritten == provider.messageSize)
	}
	
}
