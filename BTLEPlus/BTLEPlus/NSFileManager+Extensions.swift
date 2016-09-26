//
//  NSFileManager+Extensions.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/14/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

var isTestingFD = false

extension NSFileManager {
	
	/**
	Returns an NSURL for a temporary file.
	
	- returns: NSURL
	*/
	func getTempFileForWriting() -> NSURL? {
		let templateString = "BTLEPlusSerialService.XXXXXX"
		let template = NSURL(fileURLWithPath:NSTemporaryDirectory()).URLByAppendingPathComponent(templateString)
		var buffer = [Int8](count: Int(PATH_MAX), repeatedValue: 0)
		template.getFileSystemRepresentation(&buffer, maxLength: buffer.count)
		var fd = mkstemp(&buffer)
		if isTestingFD {
			if fd != -1 {
				let url = NSURL(fileURLWithFileSystemRepresentation: buffer, isDirectory: false, relativeToURL: nil)
				_ = try? NSFileManager.defaultManager().removeItemAtURL(url)
				close(fd)
			}
			fd = -1
		}
		if fd != -1 {
			close(fd)
			return NSURL(fileURLWithFileSystemRepresentation: buffer, isDirectory: false, relativeToURL: nil)
		}
		return nil
	}
	
}
