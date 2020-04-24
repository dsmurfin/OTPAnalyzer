//
//  Fade.swift
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
 Fade
 
 Stores the type, value and point details of a fade.

*/

struct Fade {
    
    /// The initial step size 0.1 m/s.
    static let positionStep: Int32 = Int32(100000 * Self.intervalSeconds)
    
    /// The initial rotation step 5°.
    static let rotationStep: UInt32 = UInt32(5000000 * Self.intervalSeconds)

    /// The fade interval (milliseconds).
    static let interval: Int = 50
    
    /// The fade interval (seconds).
    static let intervalSeconds: Double = Double(Self.interval) / 1000
    
    /**
     Enumerates all possible fade patterns.
    */
    enum Pattern: String, CaseIterable {
        
        /// Position values bounce between minimum and maximum.
        case positionBounce = "Position Bounce"
        
        /// Position values increase from minimum to maximum and then repeat.
        case positionForward = "Position Forward"
        
        /// Position values decrease from maximum to minimum and then repeat.
        case positionReverse = "Position Reverse"
        
        /// Rotates in a postive direction continuously.
        case rotateForward = "Rotate Forward"
        
        /// Rotates in a negative direction continuously.
        case rotateReverse = "Rotate Reverse"
        
        /// An array of titles for all cases.
        public static var titles: [String] {
            Self.allCases.map (\.rawValue)
        }
        
        /// The title for this case.
        public var title: String {
            self.rawValue
        }
        
    }
    
    /// The address of the point being faded.
    var address: OTPAddress
    
    /// The priority of the point being faded.
    var priority: UInt8
    
    /// The pattern to be used by this fade.
    var pattern: Pattern
    
    /// Whether values should increment
    var increment: Bool
    
    /// The current location fade value.
    var location: Int32
    
    /// The previous velocity of this fade.
    var runningVelocity: Double
    
    /// The running acceleration of this fade.
    var runningAcceleration: Int32
    
    /// The step size to use.
    var step: Int32
    
    /**
     Creates a new fade with the pattern specified.
     
     - Parameters:
        - address: The address of the point.
        - priority: The priority of the point.
        - pattern: The pattern to be used for this fade.
     
     */
    init(address: OTPAddress, priority: UInt8, pattern: Pattern) {
        
        self.address = address
        self.priority = priority
        self.pattern = pattern
        self.runningVelocity = 0
        self.runningAcceleration = 0
        
        // increment starts in the appropriate direction
        switch pattern {
        case .positionBounce, .positionForward:
            self.location = Int32.min
            self.increment = true
            self.step = Self.positionStep
        case .positionReverse:
            self.location = Int32.max
            self.increment = false
            self.step = Self.positionStep
        case .rotateForward:
            self.location = Int32(OTPModuleRotation.minPermitted)
            self.increment = true
            self.step = Int32(Self.rotationStep)
        case .rotateReverse:
            self.location = Int32(OTPModuleRotation.maxPermitted + 1)
            self.increment = false
            self.step = Int32(Self.rotationStep)
        }
        
    }
    
    /**
     Moves this fade to the next position.
     */
    
    mutating func move() {

        switch pattern {
            
        case .positionBounce:
             
            // decide whether to switch direction
            if (increment && location >= Int32.max - step) || (!increment && location <= Int32.min + step) {
                                
                increment.toggle()
                
                // reset values
                runningVelocity = 0
                step = Self.positionStep
                
                // velocity in μm/s
                let velocity = increment ? Double(step) / Self.intervalSeconds : Double(-step) / Self.intervalSeconds

                // acceleration in μm/s²
                let acceleration = (velocity - runningVelocity) / Self.intervalSeconds
                
                location += increment ? step : -step
                step += Self.positionStep

                runningVelocity = velocity
                runningAcceleration = Int32(acceleration)
                
            } else {

                // velocity in μm/s
                let velocity = increment ? Double(step) / Self.intervalSeconds : Double(-step) / Self.intervalSeconds

                // acceleration in μm/s²
                let acceleration = (velocity - runningVelocity) / Self.intervalSeconds
                
                location += increment ? step : -step
                step += Self.positionStep

                runningVelocity = velocity
                runningAcceleration = Int32(acceleration)
                
            }
             
        case .positionForward, .positionReverse:

            // decide whether to start again
            if (increment && location >= Int32.max - step) || (!increment && location <= Int32.min + step) {

                // reset values
                runningVelocity = 0
                step = Self.positionStep
                location = pattern == .positionForward ? Int32.min : Int32.max
                
                // velocity in μm/s
                let velocity = increment ? Double(step) / Self.intervalSeconds : Double(-step) / Self.intervalSeconds

                // acceleration in μm/s²
                let acceleration = (velocity - runningVelocity) / Self.intervalSeconds
                
                location += increment ? step : -step
                step += Self.positionStep

                runningVelocity = velocity
                runningAcceleration = Int32(acceleration)
                
            } else {

                // velocity in μm/s
                let velocity = increment ? Double(step) / Self.intervalSeconds : Double(-step) / Self.intervalSeconds

                // acceleration in μm/s²
                let acceleration = (velocity - runningVelocity) / Self.intervalSeconds
                
                location += increment ? step : -step
                step += Self.positionStep

                runningVelocity = velocity
                runningAcceleration = Int32(acceleration)
                                
            }
            
        case .rotateForward, .rotateReverse:

            // velocity in μm/s
            let velocity = increment ?  Double(step) / Self.intervalSeconds : Double(-step) / Self.intervalSeconds

            // acceleration in μm/s²
            let acceleration = (velocity - runningVelocity) / Self.intervalSeconds

            if increment {
                
                location = (location + step) % Int32(OTPModuleRotation.maxPermitted + 1)
                
            } else {
                
                let proposedLocation = location - step
                
                if proposedLocation < 0 {
                    location = Int32(OTPModuleRotation.maxPermitted + 1) + proposedLocation
                } else {
                    location = proposedLocation
                }

            }

            runningVelocity = velocity
            runningAcceleration = Int32(acceleration)
            
        }
        
    }
    
}
