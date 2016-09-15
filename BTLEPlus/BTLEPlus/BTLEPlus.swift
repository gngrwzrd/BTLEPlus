//
//  BTLEPlus.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/14/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// A type alias for BTLEPlus log handler. Call setBTLEPlusLogHandler
/// with a custom callback to customize what's logged.
public typealias BTLEPlusLogHandler = ((UInt8,[Any])->Void)

public enum BTLEPlusLogHandlerLevel : UInt8 {
	case PacketDataOnly = 1
	case All = 2
}

/**
The BTLEPlusLogger is a very simple wrapper where all log messages
from BTLEPlus are filtered through.

If you set a log handler all messages are passed to your handler.

If no handler is set everything gets dumped with print.
*/
public class BTLEPlusLogger : NSObject {
	
	static var level:UInt8 = 0
	static var handler:BTLEPlusLogHandler?
	
	public class func setLogHandler( handler:BTLEPlusLogHandler ) {
		BTLEPlusLogger.handler = handler
	}
	
	public class func log(level:UInt8, _ args:Any...) {
		if let handler = BTLEPlusLogger.handler {
			handler(level, args)
		} else {
			var s = ""
			for arg in args {
				s = s + "\(arg) "
			}
			print(s)
		}
	}
}

func BTLEPlusLog(level:UInt8, args:Any...) {
	BTLEPlusLogger.log(level, args)
}
