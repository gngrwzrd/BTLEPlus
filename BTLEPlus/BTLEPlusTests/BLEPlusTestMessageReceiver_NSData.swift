//
//  BLEPlusTestMessageReceiver_NSData.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/27/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BLEPlusTestMessageReceiver_NSData : XCTestCase {

	func testTransferFileFromProviderToReceiverWithData() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let data = NSData(contentsOfURL: fileURL!)
		let _provider = BLEPlusSerialServicePacketProvider(withData: data!)
		_provider?.mtu = 1024
		_provider?.windowSize = 25
		let _receiver = BLEPlusSerialServicePacketReceiver(withWindowSize: 25)
		var packet:NSData? = nil
		guard let provider = _provider else {
			assert(false)
		}
		guard let receiver = _receiver else {
			assert(false)
		}
		receiver.beginMessage()
		while(true) {
			if provider.isEndOfMessage {
				break
			}
			provider.fillWindow()
			receiver.beginWindow()
			receiver.windowSize = provider.windowSize
			if provider.isEndOfMessage {
				receiver.windowSize = provider.endOfMessageWindowSize
			}
			while provider.hasPackets() {
				packet = provider.getPacket()
				receiver.receivedData(packet!)
			}
			assert(receiver.needsPacketsResent == false)
			receiver.commitPacketData()
		}
		if provider.isEndOfMessage {
			receiver.windowSize = provider.windowSize
			receiver.commitPacketData()
			//assert(provider.bytesWritten == receiver.bytesReceived)
			provider.finishMessage()
			receiver.commitPacketData()
			receiver.finishMessage()
		}
	}

}