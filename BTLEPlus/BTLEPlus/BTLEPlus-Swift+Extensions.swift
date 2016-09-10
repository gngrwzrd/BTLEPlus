//
//  BTLEPlus+EnumExtensions.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/9/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

// An extension to OptionSetType to easily turn on or off values in an enum.
// This can be used on any enum that implements OptionSetType, but is mostly
// intended to simplify using CBAttributePerimssion, and CBCharaceristicProperties
// in Core Bluetooth.
extension OptionSetType {
	
	/**
	An extension to OptionSetType to easily turn on or off values in an enum.
	This can be used on any enum that implements OptionSetType, but is mostly
	intended to simplify using CBAttributePerimissions, and CBCharaceristicProperties
	in Core Bluetooth.
	
	BTLEPlus use case example:
	
	````
	let properties = CBCharacteristicProperties()
	properties.set(.Read,true)
	properties.set(.Write,true)
	properties.set(.WriteWithoutResponse, true)
	properties.set(.NotifyEncryptionRequired,true)
	````
	
	- parameter option:	The value.
	- parameter on:		Whether or not the value is on or off.
	*/
	mutating public func set(option:Self, on:Bool) {
		if on {
			self = self.union(option)
		} else {
			self.subtractInPlace(option)
		}
	}
}
