//
//  BLEAdvertisedData.swift
//  IntelDeviceKitMacSandbox
//
//  Created by Aaron Smith on 8/20/16.
//  Copyright © 2016 Aaron Smith. All rights reserved.
//

import Foundation
import CoreBluetooth

/// The BLEAdvertisementData class manages advertised data from
/// Core Bluetooth. It can convert advertised data between it's
/// original discovered format, a plist supported format, and a
/// serializable format with NSCoding. It provides some easier
/// accessors to get and set advertisement data.
@objc public class BLEAdvertisementData : NSObject, NSCoding {
	
	//MARK: - Advertisement Data
	
	/// Advertisement data in it's discovered format which includes CBUUIDs.
	public var discoveredData:[String:AnyObject] = [:]
	
	//MARK: - CBAdvertisement Shortcuts
	
	/// Get or set CBAdvertisementDataIsConnectable.
	public var isConnectable:NSNumber? {
		get {
			return discoveredData[CBAdvertisementDataIsConnectable] as? NSNumber
		} set(new) {
			discoveredData[CBAdvertisementDataIsConnectable] = new
		}
	}
	
	/// Get or set CBAdvertisementDataLocalNameKey.
	public var localName:String? {
		get {
			if let ln = discoveredData[CBAdvertisementDataLocalNameKey] as? String {
				return ln
			}
			return nil
		} set(new) {
			discoveredData[CBAdvertisementDataLocalNameKey] = new
		}
	}
	
	/// Get or set the CBAdvertisementDataManufacturerDataKey.
	public var manufacturerData:NSData? {
		get {
			return discoveredData[CBAdvertisementDataManufacturerDataKey] as? NSData
		} set(new) {
			discoveredData[CBAdvertisementDataManufacturerDataKey] = new
		}
	}
	
	/// Get or set the CBAdvertisementDataOverflowServiceUUIDsKey.
	public var overflowServiceUUIDs:[CBUUID]? {
		get {
			return discoveredData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
		} set(new) {
			discoveredData[CBAdvertisementDataOverflowServiceUUIDsKey] = new
		}
	}
	
	/// Get or set the CBAdvertisementDataServiceDataKey.
	public var serviceSpecificData:[CBUUID:NSData]? {
		get {
			return discoveredData[CBAdvertisementDataServiceDataKey] as? [CBUUID:NSData]
		} set(new) {
			discoveredData[CBAdvertisementDataServiceDataKey] = new
		}
	}
	
	/// Get or set CBAdvertisementDataServiceUUIDsKey.
	public var serviceUUIDS:[CBUUID]? {
		get {
			return discoveredData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
		} set(new) {
			discoveredData[CBAdvertisementDataServiceUUIDsKey] = new
		}
	}
	
	/// Get or set CBAdvertisementDataSolicitedServiceUUIDsKey.
	public var solicitedServices:[CBUUID]? {
		get {
			return discoveredData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
		} set(new) {
			discoveredData[CBAdvertisementDataSolicitedServiceUUIDsKey] = new
		}
	}
	
	/// Get or set the CBAdvertisementDataTxPowerLevelKey.
	public var txPowerLevel:NSNumber? {
		get {
			return discoveredData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
		} set(new) {
			discoveredData[CBAdvertisementDataTxPowerLevelKey] = new
		}
	}
	
	//MARK: - Initializers
	
	/**
	Initialize an empty BLEAdvertisementData object.
	
	- returns: BLEAdvertisementData
	*/
	override public init() {
		
	}
	
	/**
	Initialize a BLEAdvertisementData with the discovered advertisement data.
	
	- parameter data: Discovered advertisement data.
	
	- returns: BLEAdvertisementData
	*/
	public init(discoveredData:[String:AnyObject]) {
		super.init()
		self.discoveredData = discoveredData
	}
	
	/**
	Create a BLEAdvertisementData instance from NSData that was serialized with
	an NSKeyedArchiver.
	
	- parameter rawData: NSData Serialized form of BLEAdvertisementData
	
	- returns: BLEAdvertisementData?
	*/
	public class func createWithData(rawData:NSData?) -> BLEAdvertisementData? {
		if let rawData = rawData {
			return NSKeyedUnarchiver.unarchiveObjectWithData(rawData) as? BLEAdvertisementData
		}
		return nil
	}
	
	//MARK: - NSCoding
	
	/**
	Encode advertisement data.
	
	- parameter aCoder: NSCoder
	*/
	public func encodeWithCoder(aCoder: NSCoder) {
		let plistFormat = self.toPlistFormat()
		aCoder.encodeObject(plistFormat, forKey: "data")
	}
	
	/**
	Decode from a serialized format.
	
	- parameter aDecoder:	NSCoder
	
	- returns: BLEAdvertisementData
	*/
	required public init?(coder aDecoder: NSCoder) {
		self.discoveredData = [:]
		super.init()
		if let d = aDecoder.decodeObjectForKey("data") as? [String:AnyObject] {
			let discoveredFormat = BLEAdvertisementData.convertAdvertisementDataToDiscoveredFormat(d)
			self.discoveredData = discoveredFormat
		}
	}
	
	//MARK: - Format Conversions
	
	/**
	Convert advertisement data to the original discovered format.
	
	- parameter data: The advertisement data.
	
	- returns: The same advertisement data as discovered by core bluetooth.
	*/
	class public func convertAdvertisementDataToDiscoveredFormat(data:[String:AnyObject]) -> [String:AnyObject] {
		var dataCopy = data
		
		//service uuids
		if let uuids = dataCopy[CBAdvertisementDataServiceUUIDsKey] as? [String] {
			var newCBUUIDS:[CBUUID] = []
			for uuid in uuids {
				newCBUUIDS.append( CBUUID(string: uuid ))
			}
			dataCopy[CBAdvertisementDataServiceUUIDsKey] = newCBUUIDS
		}
		
		//service data specific
		if let serviceData = dataCopy[CBAdvertisementDataServiceDataKey] as? [String:NSData] {
			var newServiceData:[CBUUID:NSData] = [:]
			for (uuidString, data) in serviceData {
				let cbuuid = CBUUID(string: uuidString)
				newServiceData[cbuuid] = data
			}
			dataCopy[CBAdvertisementDataServiceDataKey] = newServiceData
		}
		
		//overflow uuids
		if let overflowUUIDS = dataCopy[CBAdvertisementDataOverflowServiceUUIDsKey] as? [String] {
			var newOverflowUUIDS:[CBUUID] = []
			for uuid in overflowUUIDS {
				newOverflowUUIDS.append( CBUUID(string: uuid) )
			}
			dataCopy[CBAdvertisementDataOverflowServiceUUIDsKey] = newOverflowUUIDS
		}
		
		//solicited services
		if let solictedServiceUUIDS = dataCopy[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [String] {
			var newSolictedServiceUUIDS:[CBUUID] = []
			for uuid in solictedServiceUUIDS {
				newSolictedServiceUUIDS.append( CBUUID(string: uuid) )
			}
			dataCopy[CBAdvertisementDataSolicitedServiceUUIDsKey] = newSolictedServiceUUIDS
		}
		
		return dataCopy
	}
	
	/**
	Convert advertisement data to a format that can be saved with NSUserDefaults.
	
	- parameter data: The advertisement data.
	
	- returns: The same advertisement data but complies with NSCoding.
	*/
	public class func convertAdvertisementDataToUserDefaultsFormat(data:[String:AnyObject]) -> [String:AnyObject] {
		var dataCopy = data
		
		//convert service uuids to strings
		var stringUUIDS:[String] = []
		if let uuids = dataCopy[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
			for uuid in uuids {
				stringUUIDS.append( uuid.UUIDString )
			}
			dataCopy[CBAdvertisementDataServiceUUIDsKey] = stringUUIDS
		}
		
		//convert service specific data keys to strings
		if let serviceDatas = dataCopy[CBAdvertisementDataServiceDataKey] as? [CBUUID:NSData] {
			var newServiceDatas:[String:NSData] = [:]
			for (uuid,data) in serviceDatas {
				newServiceDatas[ uuid.UUIDString ] = data
			}
			dataCopy[CBAdvertisementDataServiceDataKey] = newServiceDatas
		}
		
		//overflow service uuids
		if let overflowServiceUUIDS = dataCopy[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] {
			var newOverflowServiceUUIDS:[String] = []
			for uuid in overflowServiceUUIDS {
				newOverflowServiceUUIDS.append( uuid.UUIDString )
			}
			dataCopy[CBAdvertisementDataOverflowServiceUUIDsKey] = newOverflowServiceUUIDS
		}
		
		//solicited service uuids
		if let solitedServiceUUIDS = dataCopy[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID] {
			var newSolicitedServiceUUIDS:[String] = []
			for uuid in solitedServiceUUIDS {
				newSolicitedServiceUUIDS.append( uuid.UUIDString )
			}
			dataCopy[CBAdvertisementDataSolicitedServiceUUIDsKey] = newSolicitedServiceUUIDS
		}
		
		return dataCopy
	}
	
	/**
	Returns the advertisement data in the original discovered format.
	
	- returns: [String:AnyObject]?
	*/
	public func toAdvertisedFormat() -> [String:AnyObject]? {
		return discoveredData
	}
	
	/**
	Returns the advertisement data in plist format.
	
	- returns: [String:AnyObject]?
	*/
	public func toPlistFormat() -> [String:AnyObject]? {
		return BLEAdvertisementData.convertAdvertisementDataToUserDefaultsFormat(discoveredData)
	}
	
	//MARK: - Appending Advertisement Data
	
	/**
	Append another BLEAdvertisementData object to this one.
	
	- parameter advertisementData: BLEAdvertisementData
	*/
	public func append(advertisementData:BLEAdvertisementData) {
		appendAdvertisementData(advertisementData.discoveredData)
	}
	
	/**
	Appends advertisement data to the collection of data.
	
	- parameter newData: New data in the discovered format from core bluetooth.
	*/
	public func appendAdvertisementData(newData:[String:AnyObject]) {
		for (key,value) in newData {
			
			//don't allow service uuids to be removed.
			if key == CBAdvertisementDataServiceUUIDsKey {
				if let existingCBUUIDS = discoveredData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
					if let value = value as? [CBUUID] {
						if value.count < existingCBUUIDS.count {
							continue
						}
					}
				}
			}
			
			discoveredData[key] = value
		}
	}
}
