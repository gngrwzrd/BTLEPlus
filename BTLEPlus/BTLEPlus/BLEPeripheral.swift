
import CoreBluetooth

/// The BLEPeripheral is a generic peripheral that once connected,
/// will discover services, included services, characteristics,
/// descriptors, and subscribe to required characteristic changes.
///
/// Each device goes through a setup process before it's considered ready.
///
/// Connect - This is the first step in the process.
///
/// Discovery - This is the second step in the process. It includes
/// discovering services, included services, characteristics and
/// descriptors.
///
/// Subscribe - This is the third step in the process. It includes
/// subscribing to any characteristics that support notify.
///
/// Additional Setup -  This is an optional step in which you can include
/// additional steps as part of the device setup process. You can override
/// requiresAdditionalSetup() and performAdditionalSetup() to add your
/// custom setup into the setup process. Just make sure to call deviceIsReady()
///
/// Ready - This is the last step and the device is considered ready.
///
/// Once the setup process is completed your device is considered `ready`.
///
/// Each step in the setup process has hooks you can use to override
/// and change each step.
///
/// Each step also has variables to customize retries and timeouts before a retry.
///
/// After a device is ready, it's up to you to implement behavior with the peripheral.
@objc public class BLEPeripheral : NSObject, CBPeripheralDelegate {
	
	/// The CBPeripheral this class monitors and manages.
	public var cbPeripheral:CBPeripheral?
	
	/// Device name from
	public var name:String? {
		return cbPeripheral?.name
	}
	
	/// Device RSSI
	private var _RSSI:NSNumber? = nil
	public var RSSI: NSNumber? {
		get {
			return _RSSI
		} set(new) {
			_RSSI = new
		}
	}
	
	/// Device UUID
	public var UUID:NSUUID? {
		if let peripheral = cbPeripheral {
			return peripheral.identifier
		}
		return nil
	}
	
	/// A custom tag to identify the device.
	public var tag:Int = 0
	
	/// A custom organization identifier for this device.
	public var organization:String?
	
	/// The maximum tries to connect to the peripheral.
	public var connectionMaxAttempts = 3
	
	/// The timeout length before retrying to connect to the peripheral.
	public var connectionTimeoutLength:NSTimeInterval = 5
	
	/// The maximum tries to discover services, included services, characteristics and descriptors.
	public var discoveryPhaseMaxAttempts = 3
	
	/// The discovery phase timeout length before retrying the discover phase.
	public var discoveryPhaseTimeoutLength:NSTimeInterval = 5
	
	/// The maximum tries to subscribe to a characteristic.
	public var subscribePhaseMaxAttempts = 3
	
	/// The subscribe phase timeout length before retrying the subscribe phase.
	public var subscribePhaseTimeoutLength:NSTimeInterval = 5
	
	/// The maximum attempts to call performAdditionalSetup().
	public var additionalSetupMaxAttempts = 3
	
	/// The timeout for custom additional setup.
	public var additionalSetupTimeout:NSTimeInterval = 5
	
	/// Whether to reconnect on disconnect. This is used inside of
	/// shouldReconnectOnDisconnect which you can override and customize
	/// if required.
	public var reconnectOnDisconnect:Bool = true
	
	/// Whether or not to allow this device to be removed from the
	/// manager after it's disconnected. This is used in the
	/// canBeRemovedFromManager() method.
	public var allowRemovalFromManager:Bool = false
	
	/// The BLECentralManager that currently is managing this device.
	weak var bleCentralManager:BLECentralManager?
	
	/// The CBCentralManager for this device.
	weak var btCentralManager:CBCentralManager?
	
	var _advertisementData:BLEAdvertisementData?
	/// Initial advertisement data when device was discovered. Note that this
	/// data can also come from user defaults when devices are retrieved from
	/// core bluetooth.
	public var advertisementData:BLEAdvertisementData? {
		get {
			return _advertisementData
		} set(newAdvertisementData) {
			_advertisementData = newAdvertisementData
		}
	}
	
	/// Utility variable for all retry logic that keeps track of how many more attempts are allowed.
	var attempts = 0
	
	/// Utility variable for any timeout required which would trigger another attempt.
	var timeout:NSTimer?
	
	/// Whether or not the device is going through it's setup phase before it's considered ready.
	/// This flag is needed in order to allow subclasses to override peripheral delegate methods properly.
	var isInSetupPhase = false
	
	/// Whether or not the discover phase of device setup is completed.
	var discoveryRequirementsCompleted:Bool = false
	
	/// Whether or not this device is ready. BLEPeripheral uses this as a flag
	/// in numerous places to skip parts of the discovery / subscribe
	/// phase if subclasses set it to true.
	public var deviceReady = false
	
	/// The number of services whos characteristics are being discovered.
	var discoveringCharacteristics = 0
	
	/// The number of characteristics whos descriptors are being discovered.
	var discoveringDescriptors = 0
	
	/// The number of services who's included sevices are being discovered.
	var discoveringIncludedServices = 0
	
	/// The number of characteristics who's setNotify value is being subscribed to.
	var setNotifyCount = 0
	
	/// An error object to pass to listeners when the setup process completely fails.
	var setupOutgoingError:NSError?
	
	/// The last error received from a disconnect. You can use this in your
	/// shouldReconnectOnDisconnect() to possibly make a smart decision about
	/// reconnection.
	var lastDisconnectError:NSError?
	
	/// Whether the last disconnect was the result of a call to disconnect()
	/// by the user, or an internal disconnect because of an outside condition.
	var disconnectWasInternal:Bool = false
	
	//MARK: device setup
	
	/// This is called when a new BLEPeripheral instance is created from a prototype copy.
	func wasCopiedFromDevicePrototype(prototype:BLEPeripheral) {
		attempts = prototype.connectionMaxAttempts
	}
	
	/// You must override this and implement logic that decides if your device
	/// responds to the advertisement data.
	public func respondsToAdvertisementData(advertisementData:BLEAdvertisementData) -> Bool {
		return false
	}
	
	//MARK: connectivity
	
	/// This is overrideable to provide custom logic that decides if a device should
	/// reconnect immediately after it was disconnected.
	public func shouldReconnectOnDisconnect() -> Bool {
		if disconnectWasInternal || !reconnectOnDisconnect {
			return false
		}
		return true
	}
	
	/// You can override this to be notified of when a device was discovered. It's
	/// also called when a device is `retrieved` from core bluetooth and considered discovered.
	public func wasDiscovered() {
		bleCentralManager?.delegate?.bleCentralManagerDidDiscoverDevice?(bleCentralManager!, device: self)
	}
	
	/// You can override this to be notified of when a device was `retrieved` from
	/// core bluetooth and considered discovered.
	public func wasRetrieved() {
		if cbPeripheral?.state == CBPeripheralState.Disconnected {
			connect()
		}
		if cbPeripheral?.state == CBPeripheralState.Connected {
			discoverServices()
		}
	}
	
	/// Called when a device receives more advertisement data. This can happen
	/// when device discovery is running. Core bluetooth will send multiple
	/// device discovered for the same peripheral, but with more data.
	public func receivedMoreAdvertisementData(newData:BLEAdvertisementData) {
		advertisementData?.append(newData)
		if deviceReady {
			bleCentralManager?.saveKnownDevice(self, advertisementData: advertisementData)
		}
	}
	
	/// This starts the connect process with core bluetooth.
	public func connect() {
		if let peripheral = cbPeripheral {
			if peripheral.state == CBPeripheralState.Connecting || peripheral.state == CBPeripheralState.Connected {
				return
			}
		}
		attempts = connectionMaxAttempts
		lastDisconnectError = nil
		isInSetupPhase = true
		retryConnect()
	}
	
	/// When the device is connected. The device has only been connected
	/// and not ready for use yet.
	func connected() {
		cbPeripheral?.delegate = self
		bleCentralManager?.delegate?.blePeripheralConnected?(bleCentralManager!, device: self)
		discoverServices()
	}
	
	/// This retries the connection after a connection timeout.
	func retryConnect() {
		attempts = attempts - 1
		if attempts < 1 {
			let userinfo = [NSLocalizedDescriptionKey:"Connect timed out."]
			setupOutgoingError = NSError(domain: "ble", code: 0, userInfo: userinfo)
			connectFailed()
			return
		}
		if let peripheral = self.cbPeripheral {
			discoveryRequirementsCompleted = false
			deviceReady = false
			startConnectTimeout()
			btCentralManager?.connectPeripheral(peripheral, options: nil)
		}
	}
	
	/// Starts the connection timeout
	func startConnectTimeout() {
		timeout?.invalidate()
		timeout = NSTimer.scheduledTimerWithTimeInterval(connectionTimeoutLength, target: self, selector: #selector(BLEPeripheral.connectTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// On connection timeout
	func connectTimeout(timer:NSTimer?) {
		if let peripheral = cbPeripheral {
			btCentralManager?.cancelPeripheralConnection(peripheral)
		}
		retryConnect()
	}
	
	/// When the central fails to connect and receives an error.
	func btCentralManagerReceivedConnectError(error:NSError?) {
		setupOutgoingError = error
		retryConnect()
	}
	
	/// When the central fails to connect but there was no error provided.
	func btManagerReceivedFatalConnect() {
		connectFailed()
	}
	
	/// This is called when max connection attempts have been
	/// made and it still won't connect.
	public func connectFailed() {
		bleCentralManager?.delegate?.blePeripheralFailedToConnect?(bleCentralManager!, device: self, error: setupOutgoingError)
		internal_disconnect()
		if canBeRemovedFromManager() {
			bleCentralManager?.removeDevice(self)
		}
	}
	
	/// Disconnect this device. Once disconnected the device will be removed
	/// from the BLECentralManager. You can optionally override `canBeRemovedFromManager()`
	/// to allow the device to continue living in a disconnected state.
	public func disconnect() {
		disconnectWasInternal = false
		if cbPeripheral?.state == CBPeripheralState.Disconnected {
			return
		}
		if let peripheral = cbPeripheral {
			btCentralManager?.cancelPeripheralConnection(peripheral)
		}
	}
	
	/// A private form of disconnect soley for setting the disconnectWasInternal
	/// flag.
	private func internal_disconnect() {
		disconnectWasInternal = true
		if cbPeripheral?.state == CBPeripheralState.Disconnected {
			return
		}
		if let peripheral = cbPeripheral {
			btCentralManager?.cancelPeripheralConnection(peripheral)
		}
	}
	
	/// When the device is disconnected. You can override `shouldReconnectOnDisconnect()`
	/// in order to reconnect immediately.
	public func disconnected() {
		bleCentralManager?.delegate?.blePeripheralDisconnected?(bleCentralManager!, device: self)
		
		isInSetupPhase = false
		cbPeripheral?.delegate = nil
		
		if shouldReconnectOnDisconnect() {
			connect()
		}
		
		if !shouldReconnectOnDisconnect() && canBeRemovedFromManager() {
			bleCentralManager?.removeDevice(self)
		}
	}
	
	/// When the BLECentralManager receives a disconnect for this device.
	func btCentralManagerReceivedDisconnect() {
		disconnected()
	}
	
	/// When the BLECentralManager receives a disconnect for this device and receives and error.
	func btCentralManagerReceivedDisconnectError(error:NSError?) {
		lastDisconnectError = error
		setupOutgoingError = error
		disconnected()
	}
	
	//MARK: device rediness
	
	/// Returns whether the device is considered ready. You can override this
	/// to provide your own logic that decides of the device is ready.
	public func isDeviceReady() -> Bool {
		return deviceReady
	}
	
	/// When the device is ready this is called.
	public func deviceIsReady() {
		timeout?.invalidate()
		timeout = nil
		isInSetupPhase = false
		bleCentralManager?.saveKnownDevice(self,advertisementData: advertisementData)
		bleCentralManager?.delegate?.blePeripheralIsReady?(bleCentralManager!, device: self)
	}
	
	/// Called when the discovery phase is being retried.
	func retryingDiscoveryPhase() {
		
	}
	
	/// Called when the subscribe phase is being retried.
	func retryingSubscribePhase() {
		
	}
	
	/// Called when the discover phase failed after max discover attempts has passed.
	func discoveryPhaseFailed() {
		internal_disconnect()
		bleCentralManager?.delegate?.blePeripheralSetupFailed?(bleCentralManager!, device: self, error: setupOutgoingError)
	}
	
	/// Called when descriptor discovery completed.
	func discoveryPhaseCompleted() {
		startSubscribing()
	}
	
	/// Called when the subscribe phase failed after max subscribe attempts has passed.
	func subscribePhaseFailed() {
		internal_disconnect()
		bleCentralManager?.delegate?.blePeripheralSetupFailed?(bleCentralManager!, device: self, error: setupOutgoingError)
	}
	
	/// Whether or not this device should be removed from it's BLECentralManager. This is called
	/// when a device disconnects. If canBeRemovedFromManager returns false, then the device will
	/// remain in a disconnected state with it's BLECentralManager. If it returns true it's
	/// removed from it's BLECentralManager and you'd have to scan for the device again.
	public func canBeRemovedFromManager() -> Bool {
		return allowRemovalFromManager
	}
	
	//MARK: service discovery
	
	/**
	Returns whether or not a specific service CBUUID should be discovered as part of the
	discovery phase. The passed uuid is taken directly from a peripherals advertisement data.
	
	- parameter uuid: A service CBUUID.
	- returns: Whether or not to discover the service.
	*/
	public func shouldDiscoverService(uuid:CBUUID) -> Bool {
		return true
	}
	
	/// Starts the discover services phase.
	func discoverServices() {
		var servicesToDiscover:[CBUUID] = []
		isInSetupPhase = true
		
		//if we have uuid data from advertising data allow self to choose
		//which services to discover
		if let uuids = advertisementData?.serviceUUIDS {
			for uuid in uuids {
				if shouldDiscoverService(uuid) {
					servicesToDiscover.append(uuid)
				}
			}
		
		//we don't have any uuids from advertising data, just discover all.
		//this is from a peripheral being retrieved at startup which doesn't
		//include advertising data.
		} else {
			startTimeoutForDiscoverServices()
			cbPeripheral?.discoverServices(nil)
			return
		}
		
		if servicesToDiscover.count < 1 {
			discoveryPhaseCompleted()
			return
		}
		
		startTimeoutForDiscoverServices()
		cbPeripheral?.discoverServices(servicesToDiscover)
	}
	
	/// Called after services have been discovered.
	func discoveredServices() {
		discoverIncludedServices()
	}
	
	/// Starts the timeout for service discovery.
	func startTimeoutForDiscoverServices() {
		timeout?.invalidate()
		attempts = discoveryPhaseMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(discoveryPhaseTimeoutLength, target: self, selector: #selector(BLEPeripheral.discoverServicesTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// service discovery received an error
	func discoverServicesReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoverServicesFailed()
			return
		}
		discoverServicesIsRetrying()
		discoverServices()
	}
	
	/// service discovery timed out.
	func discoverServicesTimeout(timer:NSTimer?) {
		let userInfo = [NSLocalizedDescriptionKey:"Discover Services Timed Out"]
		let error = NSError(domain: "ble", code: 0, userInfo: userInfo)
		discoverServicesReceivedError(error)
	}
	
	/// service discovery is retrying.
	func discoverServicesIsRetrying() {
		retryingDiscoveryPhase()
	}
	
	/// service discovery failed.
	func discoverServicesFailed() {
		discoveryPhaseFailed()
	}
	
	/// When services are invalidated, your device goes through the setup process
	/// again to discover services, included services, characteristics and descriptors.
	public func servicesWereInvalidated() {
		discoveryRequirementsCompleted = false
		deviceReady = false
		discoverServices()
	}
	
	//MARK: included service discovery
	
	public func shouldDiscoverIncludedServices() -> Bool {
		return false
	}
	
	/**
	Controls whether or not included services for a service should be discovered. And
	which of the services should be discovered.
	
	- parameter service: The service who's included services should be discovered.
	- returns: Returning [CBUUID,] means specific services, [] means all included services, nil means don't discover any included services
	*/
	public func discoverIncludedServicesForService(service:CBService?) -> [CBUUID]? {
		return nil
	}
	
	/// Starts the discovery of included services.
	func discoverIncludedServices() {
		isInSetupPhase = true
		
		if !shouldDiscoverIncludedServices() {
			if discoveryRequirementsCompleted {
				discoveryPhaseCompleted()
			} else {
				discoverCharacteristics()
			}
			return
		}
		
		discoveringIncludedServices = 0
		var includedServicesToDiscover:[CBService:[CBUUID]] = [:]
		if let services = cbPeripheral?.services {
			
			for service in services {
				
				if let includedServices = discoverIncludedServicesForService(service) {
					discoveringIncludedServices = discoveringIncludedServices + 1
					includedServicesToDiscover[service] = includedServices
				}
			}
			
			if includedServicesToDiscover.count > 0 {
				startTimeoutForDiscoverIncludedServices()
			}
			
			for (service,uuids) in includedServicesToDiscover {
				if uuids.count > 0 {
					cbPeripheral?.discoverIncludedServices(uuids, forService: service)
				} else {
					cbPeripheral?.discoverIncludedServices(nil, forService: service)
				}
			}
		}
		
		if discoveringIncludedServices < 1 {
			discoverCharacteristics()
		}
	}
	
	/// Starts the timeout for discoverying included services
	func startTimeoutForDiscoverIncludedServices() {
		attempts = discoveryPhaseMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(discoveryPhaseTimeoutLength, target: self, selector: #selector(BLEPeripheral.discoverIncludedServicesTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Timeout for included services discovery
	func discoverIncludedServicesTimeout(timer:NSTimer) {
		discoverIncludedServicesReceivedError(nil)
	}
	
	/// Discovering an included service received an error
	func discoverIncludedServicesReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoverIncludedServicesFailed()
			return
		}
		discoverIncludedServicesIsRetrying()
		discoverIncludedServices()
	}
	
	/// Called when discovering included services failed.
	func discoverIncludedServicesFailed() {
		discoveryPhaseFailed()
	}
	
	/// Called when discovering included services is retrying.
	func discoverIncludedServicesIsRetrying() {
		retryingDiscoveryPhase()
	}
	
	/// Called when discovered included services completed.
	func discoveredIncludedServices() {
		discoverCharacteristics()
	}
	
	//MARK: characteristics discovery
	
	/**
	Whether or not to discover characteristics. Default is true.
	
	Default return value is true.
	
	- returns: Bool
	*/
	public func shouldDiscoverCharacteristics() -> Bool {
		return true
	}
	
	/**
	Whether or not all characteristics for a specific service should be discovered.
	If shouldDiscoverCharacteristics() returns false this won't be called.
	
	Default behavior is to discover all characteristics for a service.
	
	- parameter service: The service who's characteristics will be discovered.
	- returns: [CBUUID,] means specific characteristic, [] means all characteristics, 
	nil means don't discover any characteristics for this service.
	*/
	public func discoverCharacteristicsForService(service:CBService?) -> [CBUUID]? {
		return []
	}
	
	/**
	Whether or not to discover characteristics for an included service of another service.
	
	- parameter service:         The root service.
	- parameter includedService: The included service.
	
	- returns: [CBUUID,] means specific characteristic, [] means all characteristics,
	nil means don't discover any characteristics for this service.
	*/
	public func discoverCharacteristicsForIncludedService(service:CBService?, includedService:CBService?) -> [CBUUID]? {
		return nil
	}
	
	/// Starts the discovery of characteristics.
	func discoverCharacteristics() {
		isInSetupPhase = true
		
		if !shouldDiscoverCharacteristics() {
			if discoveryRequirementsCompleted {
				discoveryPhaseCompleted()
			}
			return
		}
		
		discoveringCharacteristics = 0
		var characteristicsToDiscover:[CBService:[CBUUID]] = [:]
		
		if let services = cbPeripheral?.services {
			for service in services {
				if let charsToDiscover = discoverCharacteristicsForService(service) {
					discoveringCharacteristics = discoveringCharacteristics + 1
					characteristicsToDiscover[service] = charsToDiscover
				}
				
				if let includedServices = service.includedServices {
					for includedService in includedServices {
						if let charsToDiscover = discoverCharacteristicsForIncludedService(service, includedService: includedService) {
							discoveringCharacteristics = discoveringCharacteristics + 1
							characteristicsToDiscover[includedService] = charsToDiscover
						}
					}
				}
			}
		}
		
		if characteristicsToDiscover.count > 0 {
			startTimeoutForDiscoverCharacteristics()
		}
		
		for (service,uuids) in characteristicsToDiscover {
			if uuids.count > 0 {
				cbPeripheral?.discoverCharacteristics(uuids, forService: service)
			} else {
				cbPeripheral?.discoverCharacteristics(nil, forService: service)
			}
		}
		
		if discoveringCharacteristics < 1 {
			discoveryPhaseCompleted()
		}
	}
	
	/// Starts the timeout for characteristic discovery.
	func startTimeoutForDiscoverCharacteristics() {
		attempts = discoveryPhaseMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(discoveryPhaseTimeoutLength, target: self, selector: #selector(BLEPeripheral.discoverCharacteristicsTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Discovering characteristics timed out.
	func discoverCharacteristicsTimeout(timer:NSTimer) {
		discoverCharacteristicsReceivedError(nil)
	}
	
	/// Discover characteristics is retrying.
	func discoverCharacteristicsIsRetrying() {
		retryingDiscoveryPhase()
	}
	
	/// Discovering characteristics received an error.
	func discoverCharacteristicsReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoverCharacteristicsFailed()
			return
		}
		discoverCharacteristicsIsRetrying()
		discoverCharacteristics()
	}
	
	/// Called when characteristics discovery failed.
	public func discoverCharacteristicsFailed() {
		discoveryPhaseFailed()
	}
	
	/// Successfully discovered characteristics.
	public func discoveredCharacteristics() {
		discoverDescriptors()
	}
	
	//MARK: descriptor discovery
	
	/**
	Whether or not descriptors should be discovered.
	
	Default return value is false.
	
	- returns: Bool
	*/
	public func shouldDiscoverDescriptors() -> Bool {
		return false
	}
	
	/**
	Override this to customize which descriptors for a characteristics and service are
	going to be discovered. If shouldDiscoverDescriptors() returns false, this
	won't be called.
	
	Default behavior is to discover all descriptors.
	
	- parameter characteristic: The characteristic.
	- parameter service:        The service
	- returns: Bool
	*/
	public func shouldDiscoverDescriptorsForCharacteristic(characteristic:CBCharacteristic, service:CBService?) -> Bool {
		return true
	}
	
	/// Starts the descriptor discovery.
	func discoverDescriptors() {
		isInSetupPhase = true
		
		if !shouldDiscoverDescriptors() {
			if discoveryRequirementsCompleted {
				discoveryPhaseCompleted()
			} else {
				startSubscribing()
			}
			return
		}
		
		if let services = cbPeripheral?.services {
			
			discoveringDescriptors = 0
			
			for service in services {
				if let chars = service.characteristics {
					for char in chars {
						if shouldDiscoverDescriptorsForCharacteristic(char, service: service) {
							discoveringDescriptors = discoveringDescriptors + chars.count
						}
					}
				}
			}
			
			for service in services {
				if let chars = service.characteristics {
					for char in chars {
						if shouldDiscoverDescriptorsForCharacteristic(char, service: service) {
							startTimeoutForDiscoverDescriptors()
							cbPeripheral?.discoverDescriptorsForCharacteristic(char)
						}
					}
				}
			}
			
			if discoveringDescriptors == 0 {
				if discoveryRequirementsCompleted {
					discoveryPhaseCompleted()
				}
			}
		}
	}
	
	/// Called when descriptors were discovered.
	func discoveredDescriptors() {
		discoveryPhaseCompleted()
	}
	
	/// Starts the timeout for descriptor discovery
	func startTimeoutForDiscoverDescriptors() {
		attempts = discoveryPhaseMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(discoveryPhaseTimeoutLength, target: self, selector: #selector(BLEPeripheral.discoverDescriptorsTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Timeout of descriptor discovery
	func discoverDescriptorsTimeout(timer:NSTimer) {
		discoverDescriptorsReceivedError(nil)
	}
	
	/// Called when descriptor discovery failed
	func discoverDescriptorsFailed() {
		discoveryPhaseFailed()
	}
	
	/// Called when discovering a descriptor received an error
	func discoverDescriptorsReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoverDescriptorsFailed()
			return
		}
		descriptorDiscoveryIsRetrying()
		discoverDescriptors()
	}
	
	/// Called when descriptor discovery is retrying
	func descriptorDiscoveryIsRetrying() {
		retryingDiscoveryPhase()
	}
	
	//MARK: subscribing to characteristics
	
	/**
	Override this to decide if any characteristics should be subscribed to.
	
	Default return value is true for any characteristic that implements the notify property.
	
	- parameter character: The characteristic
	- parameter service:   The service
	- returns: Bool
	*/
	public func shouldSubscribeToCharacteristic(character:CBCharacteristic?, service:CBService?) -> Bool {
		return true
	}
	
	/// Starts the subscribe phase
	func startSubscribing() {
		setNotifyCount = 0
		isInSetupPhase = true
		
		if let services = cbPeripheral?.services {
			for service in services {
				if let chars = service.characteristics {
					for char in chars {
						if char.properties.contains(.Notify) {
							if shouldSubscribeToCharacteristic(char,service:service) {
								setNotifyCount = setNotifyCount + 1
							}
						}
					}
				}
			}
			
			if setNotifyCount < 1 {
				subscribingFinished()
				return
			}
			
			for service in services {
				if let chars = service.characteristics {
					for char in chars {
						if char.properties.contains(.Notify) {
							if shouldSubscribeToCharacteristic(char,service:service) {
								cbPeripheral?.setNotifyValue(true, forCharacteristic: char)
							}
						}
					}
				}
			}
		}
	}
	
	/// Start timeout for subscribe phase
	func startTimerForSubscribePhase() {
		timeout?.invalidate()
		attempts = subscribePhaseMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(subscribePhaseTimeoutLength, target: self, selector: #selector(BLEPeripheral.subscribingTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Timeout for subscribe phase
	func subscribingTimeout(timer:NSTimer?) {
		retrySubscribing()
	}
	
	/// Retry subscribe phase
	func retrySubscribing() {
		attempts = attempts - 1
		if attempts < 1 {
			subscribingFailed()
			return
		}
		retryingSubscribing()
		startSubscribing()
	}
	
	/// retrying for subscribe phase
	func retryingSubscribing() {
		retryingSubscribePhase()
	}
	
	/// When a setNotify received an error
	func subscribingReceivedError(error:NSError?) {
		setupOutgoingError = error
		retrySubscribing()
	}
	
	/// When the subscribe phase failed.
	public func subscribingFailed() {
		subscribePhaseFailed()
	}
	
	/// Subsribing finished successfully.
	public func subscribingFinished() {
		
		////check if additional setup is required.
		if requiresAdditionalSetup() {
			internal_performAdditionalSetup()
			return
		}
		
		if isDeviceReady() {
			deviceIsReady()
		}
	}
	
	//MARK: Additional setup
	
	/// You can override this if you require
	/// additional work as part of the device setup process.
	public func requiresAdditionalSetup() -> Bool {
		return false
	}
	
	/// internal function that kicks off performAdditionalSetup
	func internal_performAdditionalSetup() {
		attempts = additionalSetupMaxAttempts
		performAdditionalSetup()
	}
	
	/// You must override this to perform your
	/// additional setup tasks. Make sure to call super.performAdditionalSetup()
	public func performAdditionalSetup() {
		attempts = attempts - 1
		timeout?.invalidate()
		timeout = NSTimer.scheduledTimerWithTimeInterval(additionalSetupTimeout, target: self, selector: #selector(BLEPeripheral.additionalSetupTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	public func retryPerformAddionalSetup() {
		attempts = attempts - 1
		if attempts < 1 {
			additionalSetupFailed()
		}
		retryingAdditionalSetup()
		performAdditionalSetup()
	}
	
	public func retryingAdditionalSetup() {
		
	}
	
	func additionalSetupTimeout(timer:NSTimer?) {
		retryPerformAddionalSetup()
	}
	
	public func additionalSetupFailed() {
		let userinfo = [NSLocalizedDescriptionKey:"Additional setup timed out."];
		let error = NSError(domain: "ble", code: 0, userInfo: userinfo)
		bleCentralManager?.delegate?.blePeripheralSetupFailed?(bleCentralManager!, device: self, error: error)
	}
	
	//MARK: RSSI
	
	/// Called anytime the peripheral has updated it's RSSI.
	public func updatedRSSI() {
		
	}
	
	/// Called when RSSI received an error.
	public func updatedRSSIReceivedError(error:NSError?) {
		
	}
	
	//MARK: device name
	
	/// Called when the peripheral name has been updated.
	public func updatedName() {
		
	}
	
	//MARK: utils
	
	/**
	Find a service.
	
	- parameter uuid: The service uuid.
	- returns: CBService?
	*/
	public func findService(uuid:CBUUID) -> CBService? {
		if let services = cbPeripheral?.services {
			for service in services {
				if service.UUID == uuid {
					return service
				}
			}
		}
		return nil
	}
	
	/**
	Find a characteristic from a service.
	- parameter service: The service.
	- parameter uuid:    Characteristic uuid.
	- returns: CBCharacteristic?
	*/
	public func findCharacteristic(service:CBService?, uuid:CBUUID) -> CBCharacteristic? {
		guard let service = service else {
			return nil
		}
		if let chars = service.characteristics {
			for char in chars {
				if char.UUID == uuid {
					return char
				}
			}
		}
		return nil
	}
	
	// MARK: peripheral delegate
	
	// Peripheral discovered it's services.
	public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
		/// If we're not in setup phase, allow subclasses to do what they want.
		if !isInSetupPhase {
			return
		}
		
		if let error = error {
			discoverServicesReceivedError(error)
			return
		}
		
		discoveredServices()
	}
	
	//Discovered some included services for a service
	public func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
		
		/// If we're not in setup phase, allow subclasses to do what they want.
		if !isInSetupPhase {
			return
		}
		
		if let error = error {
			discoverIncludedServicesReceivedError(error)
			return
		}
		
		discoveringIncludedServices = discoveringIncludedServices - 1
		if discoveringIncludedServices == 0 {
			discoveredIncludedServices()
		}
	}
	
	// Discovered some characteristics for a service
	public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
		
		/// If we're not in setup phase, allow subclasses to do what they want.
		if !isInSetupPhase {
			return
		}
		
		if let error = error {
			discoverCharacteristicsReceivedError(error)
			return
		}
		
		discoveringCharacteristics = discoveringCharacteristics - 1
		if discoveringCharacteristics == 0 {
			discoveredCharacteristics()
		}
	}
	
	//Services were invalidated for a peripheral.
	public func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
		servicesWereInvalidated()
	}
	
	//Discovered descriptors for a characteristic.
	public func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
		
		/// If we're not in setup phase, allow subclasses to do what they want.
		if !isInSetupPhase {
			return
		}
		
		if let error = error {
			discoverDescriptorsReceivedError(error)
			return
		}
		
		discoveringDescriptors = discoveringDescriptors - 1
		if discoveringDescriptors == 0 {
			discoveredDescriptors()
		}
	}
	
	//A characteristics notification state changed.
	public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
		
		/// If we're not in setup phase, allow subclasses to do what they want.
		if !isInSetupPhase {
			return
		}
		
		if let error = error {
			subscribingReceivedError(error)
			return
		}
		
		setNotifyCount = setNotifyCount - 1
		if setNotifyCount == 0 {
			subscribingFinished()
		}
	}
	
	//A peripheral invalidated it's services
	public func peripheralDidInvalidateServices(peripheral: CBPeripheral) {
		servicesWereInvalidated()
	}
	
	//Peripheral did update name
	public func peripheralDidUpdateName(peripheral: CBPeripheral) {
		updatedName()
	}
	
	//Peripheral did update RSSI
	public func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {
		if let error = error {
			updatedRSSIReceivedError(error)
			return
		}
		updatedRSSI()
	}
}
