//
//  ResendTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/25/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

import Foundation

import XCTest
@testable import BTLEPlus

class ResendTests : BTLEPlusSerialServiceControllerBaseTests {
	
	override func setUp() {
		super.setUp()
		testingExpectedMessages = true
		expectedMessages = [
		//   p         c    p         c    c           p    c     c
			.PeerInfo,.Ack,.TakeTurn,.Ack,.NewMessage,.Ack,.Data,.EndMessage,
		//   p
			.Resend,
		//   c      c
			.Data,.EndMessage,
		//   p
			.Ack,
		]
	}
	
	var resendCount = 1
	func serialServiceControllerShouldRespondWithResend(controller: BTLEPlusSerialServiceController) -> Bool {
		if resendCount > 0 {
			resendCount -= 1
			return true
		}
		return false
	}
	
	func testResend() {
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
