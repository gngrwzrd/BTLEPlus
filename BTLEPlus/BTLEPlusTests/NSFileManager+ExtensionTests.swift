//
//  NSFileManager+ExtensionTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/14/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class NSFileManagerExtensionTests : XCTestCase {
	
	func testTempFile() {
		isTestingFD = true
		var url = NSFileManager.defaultManager().getTempFileForWriting()
		assert(url == nil)
		isTestingFD = false
		url = NSFileManager.defaultManager().getTempFileForWriting()
		assert(url != nil)
	}
}