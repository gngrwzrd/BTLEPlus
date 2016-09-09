//
//  TestRequests.swift
//  BLEPlusTestClientIOS
//
//  Created by Aaron Smith on 9/5/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

#if os(iOS)
import BTLEPlusIOS
#elseif os(OSX)
import BTLEPlus
#endif

public let HelloWorldRequest:BLEPlusSerialServiceMessageType_Type = 21
public let HelloWorldResponse:BLEPlusSerialServiceMessageType_Type = 22
