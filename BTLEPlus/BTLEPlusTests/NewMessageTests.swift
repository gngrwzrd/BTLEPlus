//
//  WaitTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/14/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

import XCTest
@testable import BTLEPlus

class NewMessageTests : BTLEPlusSerialServiceControllerBaseTests {
	
	override func setUp() {
		super.setUp()
		testingExpectedMessages = true
		//peers              p         c    p         c    c           p    c     c           p
		expectedMessages = [.PeerInfo,.Ack,.TakeTurn,.Ack,.NewMessage,.Ack,.Data,.EndMessage,.Ack]
	}
	
	override func serialServiceController(controller: BTLEPlusSerialServiceController, wantsToSendData data: NSData) {
		print("central progress: ",centralController?.progress)
		print("peripheral progress:",periphController?.progress)
		super.serialServiceController(controller, wantsToSendData: data)
	}
	
	func testNewMessage() {
		let s = "148E4241-8524-4813-B55F-6BBA94C4EB70"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BTLEPlusSerialServiceMessage(withMessageType: 0, messageId: 0, data: d!)
		centralController?.send(message!)
		periphController?.mtu = 155
		centralController?.resume()
		periphController?.resume()
		while(!done){}
	}
	
}
