//
//  BLEAdvertisedData.swift
//  IntelDeviceKitMacSandbox
//
//  Created by Aaron Smith on 8/20/16.
//  Copyright © 2016 Aaron Smith. All rights reserved.
//

import Foundation
import CoreBluetooth

/// The BLEAdvertisementData class wraps up advertised data from
/// core bluetooth. It can convert advertised data between it's
/// original discovered format and a serializable format.
///
/// It provides some easier accessors to get and set advertisement
/// data in the data dictionary.
@objc public class BLEAdvertisementData : NSObject, NSCoding {
	
	/// Advertisement data. This is the original discovered
	/// format version of the data which includes CBUUIDs.
	public var data:[String:AnyObject] = [:]
	
	/// Get or set CBAdvertisementDataLocalNameKey.
	public var localName:String? {
		get {
			if let ln = data[CBAdvertisementDataLocalNameKey] as? String {
				return ln
			}
			return nil
		} set(new) {
			data[CBAdvertisementDataLocalNameKey] = new
		}
	}
	
	/// Get or set CBAdvertisementDataServiceUUIDsKey.
	public var serviceUUIDS:[CBUUID]? {
		get {
			return data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
		} set(new) {
			data[CBAdvertisementDataServiceUUIDsKey] = new
		}
	}
	
	/// Get or set the CBAdvertisementDataManufacturerDataKey.
	public var manufacturerData:NSData? {
		get {
			return data[CBAdvertisementDataManufacturerDataKey] as? NSData
		} set(new) {
			data[CBAdvertisementDataManufacturerDataKey] = new
		}
	}
	
	/// Get or set the CBAdvertisementDataServiceDataKey.
	public var serviceSpecificData:[CBUUID:NSData]? {
		get {
			return data[CBAdvertisementDataServiceDataKey] as? [CBUUID:NSData]
		} set(new) {
			data[CBAdvertisementDataServiceDataKey] = new
		}
	}
	
	/// Get or set the CBAdvertisementDataOverflowServiceUUIDsKey.
	public var overflowServiceUUIDs:[CBUUID]? {
		get {
			return data[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
		} set(new) {
			data[CBAdvertisementDataOverflowServiceUUIDsKey] = new
		}
	}
	
	/// Get or set the CBAdvertisementDataTxPowerLevelKey.
	public var txPowerLevel:NSNumber? {
		get {
			return data[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
		} set(new) {
			data[CBAdvertisementDataTxPowerLevelKey] = new
		}
	}
	
	/// Get or set CBAdvertisementDataIsConnectable.
	public var isConnectable:NSNumber? {
		get {
			return data[CBAdvertisementDataIsConnectable] as? NSNumber
		} set(new) {
			data[CBAdvertisementDataIsConnectable] = new
		}
	}
	
	/// Get or set CBAdvertisementDataSolicitedServiceUUIDsKey.
	public var solicitedServices:[CBUUID]? {
		get {
			return data[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
		} set(new) {
			data[CBAdvertisementDataSolicitedServiceUUIDsKey] = new
		}
	}
	
	/**
	Returns an empty BLEAdvertisementData object
	
	- returns: BLEAdvertisementData
	*/
	override public init() {
		
	}
	
	/**
	Create an instance with the discovered advertisement data.
	
	- parameter data: Discovered advertisement data.
	
	- returns: BLEAdvertisementData
	*/
	public init(data:[String:AnyObject]) {
		super.init()
		self.data = data
	}
	
	/// Supports NSCoding
	public func encodeWithCoder(aCoder: NSCoder) {
		let plistFormat = self.toPlistFormat()
		aCoder.encodeObject(plistFormat, forKey: "data")
	}
	
	/// Supports NSCoding
	required public init?(coder aDecoder: NSCoder) {
		self.data = [:]
		super.init()
		if let d = aDecoder.decodeObjectForKey("data") as? [String:AnyObject] {
			let discoveredFormat = BLEAdvertisementData.convertAdvertisementDataToDiscoveredFormat(d)
			self.data = discoveredFormat
		}
	}
	
	/**
	Class helper method to create a BLEAdvertisementData instance
	with it's counterpart serialized NSData.
	
	- parameter rawData: NSData Serialized form of BLEAdvertisementData
	
	- returns: BLEAdvertisementData?
	*/
	public class func createWithData(rawData:NSData?) -> BLEAdvertisementData? {
		if let rawData = rawData {
			return NSKeyedUnarchiver.unarchiveObjectWithData(rawData) as? BLEAdvertisementData
		}
		return nil
	}
	
	/**
	Convert advertisement data to a plist or serializeable format.
	
	- parameter data: The advertisement data.
	
	- returns: The same advertisement data but complies with NSCoding.
	*/
	public class func convertAdvertisementDataToDefaultsFormat(data:[String:AnyObject]) -> [String:AnyObject] {
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
	Returns the advertisement data in the original discovered format.
	
	- returns: [String:AnyObject]?
	*/
	public func toAdvertisedFormat() -> [String:AnyObject]? {
		return data
	}
	
	/**
	Returns the advertisement data in plist format.
	
	- returns: [String:AnyObject]?
	*/
	public func toPlistFormat() -> [String:AnyObject]? {
		return BLEAdvertisementData.convertAdvertisementDataToDefaultsFormat(data)
	}
	
	/**
	Append another BLEAdvertisementData object to this one.
	
	- parameter advertisementData: BLEAdvertisementData
	*/
	public func append(advertisementData:BLEAdvertisementData) {
		appendAdvertisementData(advertisementData.data)
	}
	
	/**
	Appends advertisement data to the collection of data.
	
	- parameter newData: New data in the original discovered format.
	*/
	public func appendAdvertisementData(newData:[String:AnyObject]) {
		for (key,value) in newData {
			
			//don't allow service uuids to be removed.
			if key == CBAdvertisementDataServiceUUIDsKey {
				if let existingCBUUIDS = data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
					if let value = value as? [CBUUID] {
						if value.count < existingCBUUIDS.count {
							continue
						}
					}
				}
			}
			
			data[key] = value
		}
	}
}
