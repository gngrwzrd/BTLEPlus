//
//  ResetMessageTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/25/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

import XCTest
@testable import BTLEPlus

class ResetTestDropAll : BTLEPlusSerialServiceControllerBaseTests {
	
	override func setUp() {
		super.setUp()
		testingExpectedMessages = true
		//peers              p         c    p         c    c           p    c    c.EndMessage  c      p
		expectedMessages = [.PeerInfo,.Ack,.TakeTurn,.Ack,.NewMessage,.Ack,.Data,             .Reset,.Ack]
	}
	
	override func serialServiceController(controller: BTLEPlusSerialServiceController, wantsToSendData data: NSData) {
		
		let message = BTLEPlusSerialServiceProtocolMessage(withData: data)
		if message?.protocolType == .EndMessage {
			centralController?.reset(true)
			return
		}
		
		super.serialServiceController(controller, wantsToSendData: data)
	}
	
	func serialServiceController(controller: BTLEPlusSerialServiceController, droppedMessageFromReset message: BTLEPlusSerialServiceMessage) {
		
	}
	
	func serialServiceController(controller: BTLEPlusSerialServiceController, droppedMessageFromPeerReset message: BTLEPlusSerialServiceMessage) {
		
	}
	
	func testResetDropAll() {
		let s = "148E4241-8524-4813-B55F-6BBA94C4EB70"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BTLEPlusSerialServiceMessage(withMessageType: 0, messageId: 0, data: d!)
		centralController?.send(message!)
		centralController?.send(message!)
		periphController?.mtu = 155
		centralController?.resume()
		periphController?.resume()
		while(!done){}
		assert(centralController?.messageQueue?.count == 0)
	}
}
