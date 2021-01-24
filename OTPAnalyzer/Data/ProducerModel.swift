//
//  ProducerModel.swift
//
//  Copyright (c) 2020 Daniel Murfin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import OTPKit

/**
 Producer Model Delegate
 
 Required methods for objects implementing this delegate.

*/

protocol ProducerModelDelegate: AnyObject {
    
    /**
     Notifies the delegate that new or changed consumers were discovered.
     
     - Parameters:
        - index: The index of this consumer in the array of consumers, where it has already been added to the table view.

    */
    func changedConsumer(atIndex index: Int?)
    
    /**
     Notifies the delegate that a point has been changed.
     
     - Parameters:
        - index: An optional index of the point.

    */
    func changedPoint(atIndex index: Int?)
    
}

/**
 Producer Model
 
 Data model for a producer.

*/

class ProducerModel {
    
    /// The queue used for read/write operations.
    static let queue: DispatchQueue = DispatchQueue(label: "com.danielmurfin.OTPAnalyzer.producerModelQueue", attributes: .concurrent)
    
    /// The queue on which delegate notifications occur.
    static let delegateQueue: DispatchQueue = DispatchQueue(label: "com.danielmurfin.OTPKit.producerModelDelegateQueue")
    
    /// The priorities available for producers.
    static let priorities = (0...200).map { UInt8($0) }
    
    /// The transform intervals available for producers.
    static let transformIntervals = (1...50).map { Int($0) }
    
    /// The log for this producer.
    let log = Log()
    
    /// The fade engine for this producer.
    let fadeEngine = FadeEngine()
    
    /// Whether debug socket messages should be logged.
    private var logDebugSocket = false
    
    /// A unique identifier for this producer.
    private (set) var identifierCid = UUID()
    
    /// An optional producer for this model.
    private var producer: OTPProducer?
    
    /// The points added to this producer.
    var points: [OTPPoint] {
        get { Self.queue.sync { _points } }
    }
    
    /// The points added to this producer (internal).
    private var _points = [OTPPoint]()
    
    /// The points which are currently fading.
    var fadingPoints: [(address: OTPAddress, priority: UInt8, pattern: Fade.Pattern)] {
        get { Self.queue.sync { _fadingPoints } }
    }
    
    /// The points which are currently fading (internal)
    private var _fadingPoints = [(address: OTPAddress, priority: UInt8, pattern: Fade.Pattern)]()
    
    /// The consumers discovered by this producer.
    var consumers: [OTPConsumerStatus] {
        get { Self.queue.sync { _consumers } }
    }
    
    /// The consumers discovered by this producer (internal).
    private var _consumers: [OTPConsumerStatus] = []
    
    /// Whether this producer has been started.
    var started: Bool {
        get { Self.queue.sync { _started } }
    }
    
    /// Whether this producer has been started (internal).
    private var _started = false {
        didSet { _started ? controllerDelegate?.startedProducer() : controllerDelegate?.stoppedProducer() }
    }

    /// The selected interface name.
    var interfaceName: String? {
        get { Self.queue.sync { _interfaceName } }
        set (newValue) { return Self.queue.sync(flags: .barrier) { _interfaceName = newValue } }
    }
    
    /// The selected interface name (internal).
    private var _interfaceName: String?
    
    /// The producer controller delegate which wishes to receive delegate calls.
    weak var controllerDelegate: ProducerControllerDelegate?
    
    /// The producer model delegate which wishes to receive delegate calls.
    weak var modelDelegate: ProducerModelDelegate?

    /**
     Starts the producer.
     
     - Parameters:
        - name: A name for this producer.
        - ipMode: The IP mode for this producer (IPv4/IPv6/Both).
        - priority: The priority for this producer (values permitted 0-200).
        - interval: The interval for sending transform messages from this producer (values permitted 1-50ms).
        - logErrors: Whether protocol errors should be logged.
        - logDebug: Whether debug messages should be logged.
        - logSocket: Whether socket messages should be logged.

    */
    func startProducer(name: String, ipMode: OTPIPMode, priority: UInt8, interval: Int, logErrors: Bool, logDebug: Bool, logSocket: Bool) {
        
        Self.queue.sync(flags: .barrier) {
            
            // only reinitialize when required
            if producer == nil {

                // there must be an interface selected
                guard let interface = self._interfaceName else { log.add(message: "No interface selected", ofType: .unknown); return }

                // initialize the producer
                self.producer = OTPProducer(name: name, cid: self.identifierCid, ipMode: ipMode, interface: interface, priority: priority, interval: interval, delegateQueue: Self.delegateQueue)
                
                self.log.add(message: "Initialized producer \(self.identifierCid)", ofType: .debug)
                
                // if checked, set this controller to be the delegate
                self.logDebugSocket = logSocket
                self.producer?.setProtocolErrorDelegate(logErrors ? self : nil)
                self.producer?.setDebugDelegate(logDebug ? self : nil)
                self.producer?.setProducerDelegate(self)
                
            }
            
            do {
                
                // attempt to start the producer
                try self.producer?.start()
                
                // the producer is started
                self._started = true
                
                self.log.add(message: "Producer started", ofType: .info)
                
            } catch let error as ComponentSocketError {
                self.log.add(message: error.logDescription, ofType: .socket)
            } catch let error {
                self.log.add(message: error.localizedDescription, ofType: .unknown)
            }
            
            // start receiving fade notifications
            fadeEngine.delegate = self
            fadeEngine.start()
            
        }
        
    }
    
    /**
     Stops this producer.
    */
    func stopProducer() {
        
        Self.queue.sync(flags: .barrier) {
            
            // the producer must be started
            guard self._started else { return }
        
            // stop the producer
            self.producer?.stop()
            
            // the producer is stopped
            self._started = false
            
            self.log.add(message: "Producer stopped", ofType: .info)
            
            // stop the fade engine
            fadeEngine.stop()
            
        }
        
    }
    
    /**
     Resets the producer.
    */
    func resetProducer() {
        
        // there must be a producer to reset
        guard let _ = (Self.queue.sync { self.producer }) else { return }
        
        self.stopProducer()
        
        Self.queue.sync(flags: .barrier) {
            
            // create a new identifier
            self.identifierCid = UUID()
            
            // reset the producer
            self.producer = nil
            
            // remove all points
            self._points = []
            self._fadingPoints = []
            
            // resets all fades
            self.fadeEngine.reset()
            
            // remove all discovered consumers
            self._consumers = []

            // clear the logs
            log.reset()
            
        }
        
    }
    
    /**
     Resets the logs.
     */
    func resetLogs() {
        Self.queue.sync(flags: .barrier) {
            log.reset()
        }
    }
    
    /**
     Updates the name of the producer.
     
     - Parameters:
        - name: The name to be assigned to the producer.
     
    */
    func updateProducerName(_ name: String) {
        
        Self.queue.sync {
            self.producer?.update(name: name)
        }
        
    }
    
    /**
     Renames any existing points with this address.

     - Parameters:
        - address: The address of the points to be renamed.
        - name: The name to be assigned to the points.
     
     - Returns: Whether the rename was successful.

    */
    func renamePoints(with address: OTPAddress, name: String) {

        Self.queue.sync(flags: .barrier) {
        
            // there must be a producer
            guard let producer = producer else { return }
            
            do {

                try producer.renamePoints(with: address, name: name)
                
                // rename the local points with this address
                for (index, point) in self._points.enumerated() where point.address == address {
                    self._points[index].name = name
                }

                // add a debug message
                self.log.add(message: "Renamed points with address \(address.description) to \(name)", ofType: .debug)
                
            } catch let error as OTPPointValidationError {
                
                // add a debug message
                self.log.add(message: error.logDescription, ofType: .debug)
                
            } catch  {
                
                // add a debug message
                self.log.add(message: "Unknown error renaming points", ofType: .debug)
                
            }
            
        }
        
    }
    
    /**
     Adds a new point to this producer.

     - Parameters:
        - point: The point to be added.
     
     - Returns: Whether the add was successful.

    */
    func addPoint(_ point: OTPPoint) -> Bool {
        
        Self.queue.sync(flags: .barrier) {
        
            // there must be a producer
            guard let producer = producer else {
                
                // add a debug message
                self.log.add(message: "The producer must be initialized to add points", ofType: .debug)
                
                return false
                
            }

            do {

                try producer.addPoint(with: point.address, priority: point.priority, name: point.name)
                
                // rename the local points with this address
                for (index, otherPoint) in self._points.enumerated() where otherPoint.address == point.address {
                    self._points[index].name = point.name
                }
                
                // add this point to the local store
                self._points.append(point)

                // add a debug message
                self.log.add(message: "Added point \(point.address.description) priority \(point.priority)", ofType: .debug)
                
                return true
                
            } catch let error as OTPPointValidationError {
                
                // add a debug message
                self.log.add(message: error.logDescription, ofType: .debug)
                
            } catch  {
                
                // add a debug message
                self.log.add(message: "Unknown error adding point", ofType: .debug)
                
            }
            
            return false
            
        }
        
    }
    
    /**
     Removes an existing point from this producer.

     - Parameters:
        - point: The point to be removed.

    */
    func removePoint(_ point: OTPPoint) {
        
        Self.queue.sync(flags: .barrier) {
        
            // there must be a producer
            guard let producer = producer else {
                
                // add a debug message
                self.log.add(message: "The producer must be initialized to remove points", ofType: .debug)
             
                return
                
            }

            do {
                
                // remove this point if it is fading
                self._fadingPoints.removeAll(where: { $0.address == point.address && $0.priority == point.priority })
                
                // remove the fade if it exists
                fadeEngine.removeFade(withAddress: point.address, priority: point.priority)
                
                try producer.removePoints(with: point.address, priority: point.priority)
                
                // remove this point from the local stores
                self._points.removeAll(where: { $0.address == point.address && $0.priority == point.priority })
                self._fadingPoints.removeAll(where: { $0.address == point.address && $0.priority == point.priority })

                // remove the fade if it exists
                fadeEngine.removeFade(withAddress: point.address, priority: point.priority)

                // add a debug message
                self.log.add(message: "Removed point \(point.address.description) priority \(point.priority)", ofType: .debug)
                
            } catch let error as OTPPointValidationError {
                
                // add a debug message
                self.log.add(message: error.logDescription, ofType: .debug)
                
            } catch  {
                
                // add a debug message
                self.log.add(message: "Unknown error removing point", ofType: .debug)
                
            }
            
        }
        
        
    }
    
    /**
     Adds a new module to a point of this producer.

     - Parameters:
        - moduleType: The module type to be added.
        - point: The point this module should be added to.

    */
    func addModule(_ moduleType: OTPModule.Type, toPoint point: OTPPoint) {
        
        Self.queue.sync(flags: .barrier) {
        
            // the point must already exist
            guard let index = self._points.firstIndex(where: { $0.address == point.address && $0.priority == point.priority }) else {
                
                // add a debug message
                log.add(message: "The point must already exist to add modules", ofType: .debug)
                
                return
                
            }

            do {
                
                let module = moduleType.init()
                
                try self.producer?.addModule(module, toPoint: point.address, priority: point.priority)
                
                // add this module to the local store
                self._points[index].modules.append(module)

                // add a debug message
                self.log.add(message: "Added module \(module.logDescription) to point \(point.address.description) priority \(point.priority)", ofType: .debug)

            } catch let error as OTPPointValidationError {
                
                // add a debug message
                self.log.add(message: error.logDescription, ofType: .debug)
                
            } catch  {
                
                // add a debug message
                self.log.add(message: "Unknown error adding module", ofType: .debug)
                
            }
            
        }
        
    }
    
    /**
     Removes an existing module from a point of this producer.

     - Parameters:
        - moduleType: The module type to be removed.
        - point: The point this module should be removed from.

    */
    func removeModule(_ moduleType: OTPModule.Type, fromPoint point: OTPPoint) {
        
        Self.queue.sync(flags: .barrier) {
        
            // the point must already exist
            guard let index = self._points.firstIndex(where: { $0.address == point.address && $0.priority == point.priority }) else {
                
                // add a debug message
                self.log.add(message: "The point must already exist to remove modules", ofType: .debug)
                
                return
                
            }

            do {

                try self.producer?.removeModule(with: moduleType.identifier, fromPoint: point.address, priority: point.priority)
                
                // remove this module from the local store
                self._points[index].modules.removeAll(where: { $0.moduleIdentifier == moduleType.identifier })

                // add a debug message
                self.log.add(message: "Removed module with identifier \(moduleType.identifier.logDescription) from point with address \(point.address.description) and priority \(point.priority)", ofType: .debug)

            } catch let error as OTPPointValidationError {
                
                // add a debug message
                self.log.add(message: error.logDescription, ofType: .debug)
                
            } catch  {
                
                // add a debug message
                self.log.add(message: "Unknown error removing module.", ofType: .debug)
                
            }
            
        }
        
    }
    
    /**
     Updates an existing module for a point of this producer.

     - Parameters:
        - module: The module to be updated.
        - point: The point this module should be removed from.
        - fade: Optional: Whether this is the result of a fade.
     
    */
    func updateModule(_ module: OTPModule, forPoint point: OTPPoint, fade: Bool = false) {

        Self.queue.sync(flags: .barrier) {
        
            // the point must already exist
            guard let index = self._points.firstIndex(where: { $0.address == point.address && $0.priority == point.priority }) else {
                
                // add a debug message
                self.log.add(message: "The point must already exist to update modules", ofType: .debug)
                
                return
                
            }

            do {

                try producer?.updateModule(module, forPoint: point.address, priority: point.priority)

                // if not a fade, update this module in the local store
                if !fade, let moduleIndex = self._points[index].modules.firstIndex(where: { $0.moduleIdentifier == module.moduleIdentifier }) {
                    self._points[index].modules[moduleIndex] = module
                }

                // add a debug message
                if !fade {
                    self.log.add(message: "Updated module \(module.logDescription) from point with address \(point.address.description) and priority \(point.priority)", ofType: .debug)
                }

            } catch let error as OTPPointValidationError {
                
                // add a debug message (if not fading)
                if !fade {
                    self.log.add(message: error.logDescription, ofType: .debug)
                }
                
            } catch  {
                
                // add a debug message (if not fading)
                if !fade {
                    self.log.add(message: "Unknown error updating module.", ofType: .debug)
                }
                
            }
            
        }
        
    }
    
    /**
     Starts or stops a fade for a point of this producer.

     - Parameters:
        - pattern: The pattern to run.
        - point: The point this fade should be run on.
     
    */
    func startStopFade(withPattern pattern: Fade.Pattern, forPoint point: OTPPoint) {

        Self.queue.sync(flags: .barrier) {
            
            if self._fadingPoints.contains(where: { $0.address == point.address && $0.priority == point.priority }) {
                
                // a fade for this point currently exists
            
                // remove all instances of this point
                self._fadingPoints.removeAll(where: { $0.address == point.address && $0.priority == point.priority })
                
                // remove the fade
                fadeEngine.removeFade(withAddress: point.address, priority: point.priority)
                
                // the index of this point
                let index = self._points.firstIndex(where: { $0.address == point.address && $0.priority == point.priority })
                
                DispatchQueue.main.async {
                    
                    // restore output for previously entered values
                    for module in point.modules {
                        self.updateModule(module, forPoint: point)
                    }
                    
                    // notify the delegate to reload
                    Self.queue.sync { self.modelDelegate?.changedPoint(atIndex: index) }
                    
                }
            
            } else {
                
                // create a new fade instance
                let fade = Fade(address: point.address, priority: point.priority, pattern: pattern)
                
                // add the fade
                fadeEngine.addFade(fade)
                
                // this point is now fading
                self._fadingPoints.append((address: point.address, priority: point.priority, pattern: pattern))
                
            }

        }
        
    }
    
    /**
     Changes whether errors should be logged by this producer model.
     
     - Parameters:
        - log: Whether errors should be logged.
     
    */
    func logErrors(_ log: Bool) {
        Self.queue.sync {
            producer?.setProtocolErrorDelegate(log ? self : nil)
        }
    }
    
    /**
     Changes whether debug messages should be logged by this producer model.
     
     - Parameters:
        - log: Whether debug messages should be logged.
     
    */
    func logDebug(_ log: Bool) {
        Self.queue.sync {
            producer?.setDebugDelegate(log ? self : nil)
        }
    }
    
    /**
     Changes whether debug socket messages should be logged by this producer model.
     
     - Parameters:
        - log: Whether debug messages should be logged.
     
    */
    func logDebugSocket(_ log: Bool) {
        Self.queue.sync(flags: .barrier) {
            logDebugSocket = log
        }
    }
    
}

// MARK: -
// MARK: -

/**
 Fade Engine Delegate
 
 Required methods for objects implementing this delegate.

*/

extension ProducerModel: FadeEngineDelegate {
    
    /**
     Called to notify the delegate that new fade values exist.
     
     - Parameters:
        - fades: The fades which have changed.

    */
    func changedFades(_ fades: [Fade]) {
        
        let points = Self.queue.sync { self._points }

        for fade in fades {

            guard let point = points.first(where: { $0.address == fade.address && $0.priority == fade.priority }) else { continue }
            
            switch fade.pattern {
            case .positionForward, .positionReverse, .positionBounce:
                
                let loc = fade.location
                let vel = Int32(fade.runningVelocity)
                let accel = fade.runningAcceleration
                
                let position = OTPModulePosition(x: loc, y: loc, z: loc, scaling: .μm)
                let positionVelAccel = OTPModulePositionVelAccel(vX: vel, vY: vel, vZ: vel, aX: accel, aY: accel, aZ: accel)

                // attempt to update these modules and fail silently if they don't exist
                updateModule(position, forPoint: point, fade: true)
                updateModule(positionVelAccel, forPoint: point, fade: true)
                
            case .rotateForward, .rotateReverse:
                
                let loc = UInt32(fade.location)
                let vel = Int32(fade.runningVelocity)
                let accel = fade.runningAcceleration
                  
                let rotation = OTPModuleRotation(x: loc, y: loc, z: loc)
                let rotationVelAccel = OTPModuleRotationVelAccel(vX: vel, vY: vel, vZ: vel, aX: accel, aY: accel, aZ: accel)

                // attempt to update these modules and fail silently if they don't exist
                updateModule(rotation, forPoint: point, fade: true)
                updateModule(rotationVelAccel, forPoint: point, fade: true)
                
            }
            
        }

    }
    
}

// MARK: -
// MARK: -

/**
 OTP Producer Delegate
 
 Required methods for objects implementing this delegate.

*/

extension ProducerModel: OTPProducerDelegate {
    
    /**
     Called to notify the delegate that a consumer's status has changed.
     
     - Parameters:
        - consumer: The consumer which has changed.

    */
    func consumerStatusChanged(_ consumer: OTPConsumerStatus) {

        Self.queue.sync(flags: .barrier) {

            // check if this consumer already exists
            if let index = self._consumers.firstIndex(where: { $0.cid == consumer.cid }) {

                // replace it
                self._consumers[index] = consumer

                // notify the delegate
                modelDelegate?.changedConsumer(atIndex: index)

            } else {

                self._consumers.append(consumer)

                // notify the delegate
                modelDelegate?.changedConsumer(atIndex: nil)

            }

        }
        
    }
    
}

// MARK: -
// MARK: -

/**
 OTP Component Protocol Error Delegate
 
 Required methods for objects implementing this delegate.

*/

extension ProducerModel: OTPComponentProtocolErrorDelegate {
    
    /**
     Called whenever layer parsing errors occur.
     
     - Parameters:
        - errorDescription: A human-readable description of the error.
     
    */
    func layerError(_ errorDescription: String) {
        log.add(message: errorDescription, ofType: .protocolLayer)
    }
    
    /**
     Called whenever sequence errors occur.
     
     - Parameters:
        - errorDescription: A human-readable description of the error.
     
    */
    func sequenceError(_ errorDescription: String) {
        log.add(message: errorDescription, ofType: .protocolSequence)
    }
    
    /**
     Called whenever unknown errors occur
     
     - Parameters:
        - errorDescription: A human-readable description of the error.
     
    */
    func unknownError(_ errorDescription: String) {
        log.add(message: errorDescription, ofType: .protocolUnknown)
    }
    
}

// MARK: -
// MARK: -

/**
 OTP Component Debug Delegate
 
 Required methods for objects implementing this delegate.

*/

extension ProducerModel: OTPComponentDebugDelegate {
    
    /**
     Called whenever a debug message is logged.
     
     - Parameters:
        - logMessage: A human-readable log message.
     
    */
    func debugLog(_ logMessage: String) {
        log.add(message: logMessage, ofType: .debug)
    }
    
    /**
     Called whenever a debug socket message is logged.
     
     - Parameters:
        - logMessage: A human-readable log message.
     
    */
    func debugSocketLog(_ logMessage: String) {
        
        let logDebugSocket = Self.queue.sync { self.logDebugSocket }
        
        // only log if set
        guard logDebugSocket else { return }
        
        log.add(message: logMessage, ofType: .socket)
        
    }
    
}
