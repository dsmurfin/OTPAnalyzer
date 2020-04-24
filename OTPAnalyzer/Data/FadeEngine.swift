//
//  FadeEngine.swift
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
 Fade Engine Delegate
 
 Required methods for objects implementing this delegate.

*/

protocol FadeEngineDelegate: AnyObject {
    
    /**
     Notifies the delegate that new fade values exist.
     
     - Parameters:
        - fades: The fades which have changed.

    */
    func changedFades(_ fades: [Fade])
    
}

/**
 Fade Engine
 
 Performs fades

*/

class FadeEngine {
    
    /// The queue use for fade operations.
    static let queue: DispatchQueue = DispatchQueue(label: "com.danielmurfin.OTPAnalyzer.fadeEngineQueue")
    
    /// All fades which are currently in progress.
    private var fades = [Fade]()
    
    private var running: Bool = false
    
    /// The delegate which should receive notifications.
    weak var delegate: FadeEngineDelegate?
    
    /**
     Starts the fade engine.
    */
    func start() {
        
        Self.queue.async {
            self.running = true
            self.fader()
        }

    }
    
    /**
     Stops the fade engine.
    */
    func stop() {
        
        Self.queue.sync {
            self.running = false
        }

    }
    
    /**
     Resets the fade engine.
    */
    func reset() {
        
        Self.queue.sync {
            self.running = false
            self.fades = []
        }
        
    }
    
    /**
     Moves every active fade to its next location and informs the delegate.
    */
    private func fader() {
        
        // must be on the correct queue
        dispatchPrecondition(condition: .onQueue(Self.queue))
        
        guard running else { return }
        
        // loop through each fade and move it
        for (index, _) in self.fades.enumerated() {
            self.fades[index].move()
        }

        // notify the delegate of new fades
        if !fades.isEmpty {
            delegate?.changedFades(fades)
        }
        
        // trigger again after the interval defined
        Self.queue.asyncAfter(deadline: .now() + .milliseconds(Fade.interval)) {
            self.fader()
        }
        
    }
    
    /**
     Adds a fade to the engine.
     
     - parameters:
        - fade: The fade to be added to the engine.
     
    */
    func addFade(_ fade: Fade) {
        
        Self.queue.sync {
            
            // add this fade
            self.fades.append(fade)
            
        }
        
    }
    
    /**
     Removes all fades with this address and priority.
     
     - parameters:
        - address: The address of the fades to be removed.
        - priority: The priority of the fades to be removed.

    */
    func removeFade(withAddress address: OTPAddress, priority: UInt8) {
        
        Self.queue.sync {
            
            // remove all fades matching this address and priority
            self.fades.removeAll(where: { $0.address == address && $0.priority == priority })
            
        }
        
    }
    
}
